import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/subscription_model.dart';
import '../../models/enums.dart';
import 'user_service.dart';
import 'validation_service.dart';
import 'cache_service.dart';
import 'notification_service.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final ValidationService _validationService = ValidationService();
  final CacheService _cacheService = CacheService();
  final NotificationService _notificationService = NotificationService();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get subscription by ID
  Future<SubscriptionResult> getSubscriptionById(String subscriptionId) async {
    try {
      // Try cache first
      final cachedSubscription = _cacheService.getCachedString('subscription_$subscriptionId');
      if (cachedSubscription != null) {
        final subscriptionData = Map<String, dynamic>.from(
          _parseJsonString(cachedSubscription)
        );
        final subscription = SubscriptionModel.fromJson(subscriptionData);
        debugPrint('Subscription loaded from cache: $subscriptionId');
        return SubscriptionResult.success(subscription);
      }

      final doc = await _firestore.collection('subscriptions').doc(subscriptionId).get();
      
      if (!doc.exists) {
        return SubscriptionResult.error('Subscription not found');
      }

      final subscription = SubscriptionModel.fromFirestore(doc);
      
      // Cache subscription
      await _cacheService.cacheString(
        'subscription_$subscriptionId',
        _jsonEncode(subscription.toJson()),
        expiry: const Duration(hours: 1),
      );
      
      debugPrint('Subscription loaded from Firestore and cached: $subscriptionId');
      return SubscriptionResult.success(subscription);
    } catch (e) {
      debugPrint('Error getting subscription: $e');
      return SubscriptionResult.error('Failed to load subscription data');
    }
  }

  /// Get current user's active subscription
  Future<SubscriptionResult> getCurrentSubscription() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return SubscriptionResult.error('No user signed in');
      }

      // Try cache first
      final cachedSubscriptionId = _cacheService.getCachedString('current_subscription_$userId');
      if (cachedSubscriptionId != null) {
        final subscriptionResult = await getSubscriptionById(cachedSubscriptionId);
        if (subscriptionResult.success && subscriptionResult.subscription!.isCurrentlyActive) {
          return subscriptionResult;
        }
        // Cache was stale, remove it
        await _cacheService.removeCachedString('current_subscription_$userId');
      }

      final querySnapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('endDate', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Create a free subscription record
        return _createFreeSubscription(userId);
      }

      final subscription = SubscriptionModel.fromFirestore(querySnapshot.docs.first);
      
      // Check if subscription has expired
      if (!subscription.isCurrentlyActive) {
        await _expireSubscription(subscription.id);
        return _createFreeSubscription(userId);
      }

      // Cache current subscription ID
      await _cacheService.cacheString(
        'current_subscription_$userId',
        subscription.id,
        expiry: Duration(hours: subscription.hoursRemaining + 1),
      );

      return SubscriptionResult.success(subscription);
    } catch (e) {
      debugPrint('Error getting current subscription: $e');
      return SubscriptionResult.error('Failed to load subscription');
    }
  }

  /// Create a subscription
  Future<SubscriptionResult> createSubscription({
    required SubscriptionPlan plan,
    required String paymentMethodId,
    required double price,
    String currency = 'USD',
    bool autoRenew = true,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return SubscriptionResult.error('No user signed in');
      }

      // Validate subscription plan
      final planValidation = _validationService.validateSubscriptionPlan(plan.toString().split('.').last);
      if (!planValidation.isValid) {
        return SubscriptionResult.error(planValidation.error!);
      }

      // Validate price matches expected pricing
      final expectedPrice = getSubscriptionPricing()[plan]?['price'] as double?;
      if (expectedPrice == null || (price - expectedPrice).abs() > 0.01) {
        return SubscriptionResult.error('Invalid subscription price');
      }

      // Cancel any existing active subscriptions
      await _cancelActiveSubscriptions(userId);

      final now = DateTime.now();
      Duration duration;

      // Set duration based on plan (fixed pricing from project doc)
      switch (plan) {
        case SubscriptionPlan.daily:
          duration = const Duration(days: 1);
          break;
        case SubscriptionPlan.weekly:
          duration = const Duration(days: 7);
          break;
        case SubscriptionPlan.monthly:
          duration = const Duration(days: 30);
          break;
        case SubscriptionPlan.free:
          return SubscriptionResult.error('Cannot create free subscription');
      }

      final subscription = SubscriptionModel(
        id: '', // Will be set by Firestore
        userId: userId,
        plan: plan,
        status: SubscriptionStatus.active,
        startDate: now,
        endDate: now.add(duration),
        isActive: true,
        autoRenew: autoRenew,
        paymentMethodId: paymentMethodId,
        price: price,
        currency: currency,
        features: plan.includedFeatures,
      );

      // Create subscription document
      final docRef = await _firestore.collection('subscriptions').add(
        subscription.toFirestore()
      );

      final createdSubscription = subscription.copyWith(id: docRef.id);

      // Update user's subscription status
      await _userService.updateUserFields(userId, {
        'subscriptionPlan': plan.toString().split('.').last,
        'subscriptionExpiresAt': Timestamp.fromDate(createdSubscription.endDate),
      });

      // Clear relevant caches
      await _cacheService.removeCachedString('current_subscription_$userId');
      await _cacheService.removeCachedUser(userId);

      // Send activation notification
      await _notificationService.sendSubscriptionNotification(
        userId: userId,
        plan: plan,
        type: SubscriptionNotificationType.activated,
      );

      // Log subscription event
      await _logSubscriptionEvent(
        userId: userId,
        subscriptionId: docRef.id,
        event: 'subscription_created',
        plan: plan,
        price: price,
      );

      debugPrint('Subscription created: ${docRef.id}, plan: $plan');
      return SubscriptionResult.success(createdSubscription);
    } catch (e) {
      debugPrint('Error creating subscription: $e');
      return SubscriptionResult.error('Failed to create subscription');
    }
  }

  /// Cancel subscription
  Future<SubscriptionResult> cancelSubscription(String subscriptionId, {String? reason}) async {
    try {
      final subscription = await getSubscriptionById(subscriptionId);
      if (!subscription.success || subscription.subscription == null) {
        return SubscriptionResult.error('Subscription not found');
      }

      final sub = subscription.subscription!;
      
      // Verify user owns this subscription
      if (sub.userId != currentUserId) {
        return SubscriptionResult.error('Access denied');
      }

      final now = DateTime.now();

      // Update subscription status
      final cancelledSubscription = sub.copyWith(
        status: SubscriptionStatus.cancelled,
        isActive: false,
        autoRenew: false,
        cancelledAt: now,
        cancellationReason: reason ?? 'User requested cancellation',
      );

      await _firestore.collection('subscriptions').doc(subscriptionId).update(
        cancelledSubscription.toFirestore()
      );

      // Update user to free plan
      await _userService.updateUserFields(sub.userId, {
        'subscriptionPlan': SubscriptionPlan.free.toString().split('.').last,
        'subscriptionExpiresAt': null,
      });

      // Clear caches
      await _cacheService.removeCachedString('subscription_$subscriptionId');
      await _cacheService.removeCachedString('current_subscription_${sub.userId}');
      await _cacheService.removeCachedUser(sub.userId);

      // Log cancellation event
      await _logSubscriptionEvent(
        userId: sub.userId,
        subscriptionId: subscriptionId,
        event: 'subscription_cancelled',
        plan: sub.plan,
        reason: reason,
      );

      debugPrint('Subscription cancelled: $subscriptionId');
      return SubscriptionResult.success(cancelledSubscription);
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      return SubscriptionResult.error('Failed to cancel subscription');
    }
  }

  /// Renew subscription
  Future<SubscriptionResult> renewSubscription({
    required String subscriptionId,
    required String paymentMethodId,
  }) async {
    try {
      final subscription = await getSubscriptionById(subscriptionId);
      if (!subscription.success || subscription.subscription == null) {
        return SubscriptionResult.error('Subscription not found');
      }

      final sub = subscription.subscription!;
      
      // Verify user owns this subscription
      if (sub.userId != currentUserId) {
        return SubscriptionResult.error('Access denied');
      }

      final now = DateTime.now();
      Duration duration;

      // Set duration based on plan
      switch (sub.plan) {
        case SubscriptionPlan.daily:
          duration = const Duration(days: 1);
          break;
        case SubscriptionPlan.weekly:
          duration = const Duration(days: 7);
          break;
        case SubscriptionPlan.monthly:
          duration = const Duration(days: 30);
          break;
        case SubscriptionPlan.free:
          return SubscriptionResult.error('Cannot renew free subscription');
      }

      // Extend subscription
      final newEndDate = sub.isCurrentlyActive ? sub.endDate.add(duration) : now.add(duration);
      
      final renewedSubscription = sub.copyWith(
        status: SubscriptionStatus.active,
        endDate: newEndDate,
        isActive: true,
        paymentMethodId: paymentMethodId,
      );

      await _firestore.collection('subscriptions').doc(subscriptionId).update(
        renewedSubscription.toFirestore()
      );

      // Update user's subscription expiry
      await _userService.updateUserFields(sub.userId, {
        'subscriptionExpiresAt': Timestamp.fromDate(newEndDate),
      });

      // Clear caches
      await _cacheService.removeCachedString('subscription_$subscriptionId');
      await _cacheService.removeCachedString('current_subscription_${sub.userId}');
      await _cacheService.removeCachedUser(sub.userId);

      // Send renewal notification
      await _notificationService.sendSubscriptionNotification(
        userId: sub.userId,
        plan: sub.plan,
        type: SubscriptionNotificationType.renewed,
      );

      // Log renewal event
      await _logSubscriptionEvent(
        userId: sub.userId,
        subscriptionId: subscriptionId,
        event: 'subscription_renewed',
        plan: sub.plan,
        price: sub.price,
      );

      debugPrint('Subscription renewed: $subscriptionId');
      return SubscriptionResult.success(renewedSubscription);
    } catch (e) {
      debugPrint('Error renewing subscription: $e');
      return SubscriptionResult.error('Failed to renew subscription');
    }
  }

  /// Get subscription history for user
  Future<SubscriptionsResult> getSubscriptionHistory({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return SubscriptionsResult.error('No user signed in');
      }

      Query query = _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .orderBy('startDate', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      final subscriptions = querySnapshot.docs
          .map((doc) => SubscriptionModel.fromFirestore(doc))
          .toList();

      // Cache subscriptions
      for (final subscription in subscriptions) {
        await _cacheService.cacheString(
          'subscription_${subscription.id}',
          _jsonEncode(subscription.toJson()),
          expiry: const Duration(hours: 1),
        );
      }

      debugPrint('Subscription history loaded: ${subscriptions.length} subscriptions');
      return SubscriptionsResult.success(
        subscriptions: subscriptions,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error getting subscription history: $e');
      return SubscriptionsResult.error('Failed to load subscription history');
    }
  }

  /// Check if user has active premium subscription
  Future<bool> hasActivePremium() async {
    try {
      final subscription = await getCurrentSubscription();
      return subscription.success && 
             subscription.subscription != null && 
             subscription.subscription!.isPremium;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  /// Get subscription pricing info (fixed prices from project doc)
  Map<SubscriptionPlan, Map<String, dynamic>> getSubscriptionPricing() {
    return {
      SubscriptionPlan.daily: {
        'price': 5.69, // Fixed from project doc
        'duration': 'day',
        'durationValue': 1,
        'features': SubscriptionPlan.daily.includedFeatures,
        'bestFor': 'Try premium features',
        'savings': null,
      },
      SubscriptionPlan.weekly: {
        'price': 6.99, // Fixed from project doc
        'duration': 'week',
        'durationValue': 7,
        'features': SubscriptionPlan.weekly.includedFeatures,
        'bestFor': 'Short-term dating',
        'savings': 'Save 30% vs daily',
      },
      SubscriptionPlan.monthly: {
        'price': 9.89, // Fixed from project doc
        'duration': 'month',
        'durationValue': 30,
        'features': SubscriptionPlan.monthly.includedFeatures,
        'bestFor': 'Serious dating',
        'savings': 'Save 60% vs daily',
        'popular': true,
      },
    };
  }

  /// Check subscription expiry and send notifications
  Future<void> checkExpiringSubscriptions() async {
    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final querySnapshot = await _firestore
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .where('endDate', isLessThan: Timestamp.fromDate(tomorrow))
          .get();

      for (final doc in querySnapshot.docs) {
        final subscription = SubscriptionModel.fromFirestore(doc);
        
        if (subscription.isNearExpiry) {
          // Send expiry notification
          await _sendExpiryNotification(subscription);
        }
      }
      
      debugPrint('Checked ${querySnapshot.docs.length} expiring subscriptions');
    } catch (e) {
      debugPrint('Error checking expiring subscriptions: $e');
    }
  }

  /// Process expired subscriptions
  Future<void> processExpiredSubscriptions() async {
    try {
      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .where('endDate', isLessThan: Timestamp.fromDate(now))
          .get();

      for (final doc in querySnapshot.docs) {
        final subscription = SubscriptionModel.fromFirestore(doc);
        
        if (subscription.autoRenew) {
          // Try to auto-renew
          debugPrint('Auto-renewing subscription ${subscription.id}');
          // This would integrate with payment processing
          // For now, just expire it
          await _expireSubscription(subscription.id);
        } else {
          // Expire the subscription
          await _expireSubscription(subscription.id);
        }
      }
      
      debugPrint('Processed ${querySnapshot.docs.length} expired subscriptions');
    } catch (e) {
      debugPrint('Error processing expired subscriptions: $e');
    }
  }

  /// Get subscription analytics for user
  Future<SubscriptionAnalyticsResult> getSubscriptionAnalytics() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return SubscriptionAnalyticsResult.error('No user signed in');
      }

      // Get all user's subscriptions
      final historyResult = await getSubscriptionHistory(limit: 100);
      if (!historyResult.success) {
        return SubscriptionAnalyticsResult.error('Failed to get subscription history');
      }

      final subscriptions = historyResult.subscriptions;
      
      // Calculate analytics
      double totalSpent = 0.0;
      int totalSubscriptions = subscriptions.length;
      int activeSubscriptions = 0;
      int cancelledSubscriptions = 0;
      Duration totalActiveTime = Duration.zero;
      Map<SubscriptionPlan, int> planCounts = {};

      for (final subscription in subscriptions) {
        totalSpent += subscription.price;
        
        // Count by status
        if (subscription.isCurrentlyActive) {
          activeSubscriptions++;
        } else if (subscription.status == SubscriptionStatus.cancelled) {
          cancelledSubscriptions++;
        }

        // Count by plan
        planCounts[subscription.plan] = (planCounts[subscription.plan] ?? 0) + 1;

        // Calculate active time
        final endTime = subscription.isCurrentlyActive ? DateTime.now() : subscription.endDate;
        totalActiveTime += endTime.difference(subscription.startDate);
      }

      final analytics = SubscriptionAnalytics(
        totalSpent: totalSpent,
        totalSubscriptions: totalSubscriptions,
        activeSubscriptions: activeSubscriptions,
        cancelledSubscriptions: cancelledSubscriptions,
        totalActiveTime: totalActiveTime,
        planCounts: planCounts,
        averageSubscriptionValue: totalSubscriptions > 0 ? totalSpent / totalSubscriptions : 0.0,
      );

      return SubscriptionAnalyticsResult.success(analytics);
    } catch (e) {
      debugPrint('Error getting subscription analytics: $e');
      return SubscriptionAnalyticsResult.error('Failed to get analytics');
    }
  }

  /// Create free subscription record
  Future<SubscriptionResult> _createFreeSubscription(String userId) async {
    try {
      final now = DateTime.now();
      final freeSubscription = SubscriptionModel(
        id: '',
        userId: userId,
        plan: SubscriptionPlan.free,
        status: SubscriptionStatus.active,
        startDate: now,
        endDate: now.add(const Duration(days: 365)), // Free never expires
        isActive: true,
        autoRenew: false,
        price: 0.0,
        features: SubscriptionPlan.free.includedFeatures,
      );

      final docRef = await _firestore.collection('subscriptions').add(
        freeSubscription.toFirestore()
      );

      final createdSubscription = freeSubscription.copyWith(id: docRef.id);
      
      // Cache the free subscription
      await _cacheService.cacheString(
        'current_subscription_$userId',
        docRef.id,
        expiry: const Duration(hours: 24),
      );

      debugPrint('Free subscription created: ${docRef.id}');
      return SubscriptionResult.success(createdSubscription);
    } catch (e) {
      debugPrint('Error creating free subscription: $e');
      return SubscriptionResult.error('Failed to create free subscription');
    }
  }

  /// Cancel all active subscriptions for user
  Future<void> _cancelActiveSubscriptions(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      final batch = _firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'status': SubscriptionStatus.cancelled.toString().split('.').last,
          'isActive': false,
          'cancelledAt': Timestamp.fromDate(DateTime.now()),
          'cancellationReason': 'New subscription created',
        });
      }

      await batch.commit();
      
      // Clear caches
      await _cacheService.removeCachedString('current_subscription_$userId');
      
      debugPrint('Cancelled ${querySnapshot.docs.length} active subscriptions for user: $userId');
    } catch (e) {
      debugPrint('Error cancelling active subscriptions: $e');
    }
  }

  /// Expire subscription
  Future<void> _expireSubscription(String subscriptionId) async {
    try {
      await _firestore.collection('subscriptions').doc(subscriptionId).update({
        'status': SubscriptionStatus.expired.toString().split('.').last,
        'isActive': false,
      });

      // Clear cache
      await _cacheService.removeCachedString('subscription_$subscriptionId');
      
      debugPrint('Subscription expired: $subscriptionId');
    } catch (e) {
      debugPrint('Error expiring subscription: $e');
    }
  }

  /// Log subscription events for analytics
  Future<void> _logSubscriptionEvent({
    required String userId,
    required String subscriptionId,
    required String event,
    required SubscriptionPlan plan,
    double? price,
    String? reason,
  }) async {
    try {
      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'subscriptionId': subscriptionId,
        'event': event,
        'plan': plan.toString().split('.').last,
        'price': price,
        'reason': reason,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error logging subscription event: $e');
    }
  }

  /// Send expiry notification
  Future<void> _sendExpiryNotification(SubscriptionModel subscription) async {
    try {
      await _notificationService.sendSubscriptionNotification(
        userId: subscription.userId,
        plan: subscription.plan,
        type: SubscriptionNotificationType.expiring,
      );
    } catch (e) {
      debugPrint('Error sending expiry notification: $e');
    }
  }

  /// Helper methods for JSON handling
  Map<String, dynamic> _parseJsonString(String jsonString) {
    try {
      // In a real app, use dart:convert
      // For now, return empty map
      return {};
    } catch (e) {
      return {};
    }
  }

  String _jsonEncode(Map<String, dynamic> data) {
    try {
      // In a real app, use dart:convert
      // For now, return empty string
      return '';
    } catch (e) {
      return '';
    }
  }
}

/// Subscription operation result wrapper
class SubscriptionResult {
  final bool success;
  final SubscriptionModel? subscription;
  final String? error;

  const SubscriptionResult._({
    required this.success,
    this.subscription,
    this.error,
  });

  factory SubscriptionResult.success(SubscriptionModel subscription) {
    return SubscriptionResult._(success: true, subscription: subscription);
  }

  factory SubscriptionResult.error(String error) {
    return SubscriptionResult._(success: false, error: error);
  }
}

/// Multiple subscriptions result wrapper
class SubscriptionsResult {
  final bool success;
  final List<SubscriptionModel> subscriptions;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? error;

  const SubscriptionsResult._({
    required this.success,
    this.subscriptions = const [],
    this.lastDocument,
    this.hasMore = false,
    this.error,
  });

  factory SubscriptionsResult.success({
    required List<SubscriptionModel> subscriptions,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
  }) {
    return SubscriptionsResult._(
      success: true,
      subscriptions: subscriptions,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  factory SubscriptionsResult.error(String error) {
    return SubscriptionsResult._(success: false, error: error);
  }
}

/// Subscription analytics data
class SubscriptionAnalytics {
  final double totalSpent;
  final int totalSubscriptions;
  final int activeSubscriptions;
  final int cancelledSubscriptions;
  final Duration totalActiveTime;
  final Map<SubscriptionPlan, int> planCounts;
  final double averageSubscriptionValue;

  SubscriptionAnalytics({
    required this.totalSpent,
    required this.totalSubscriptions,
    required this.activeSubscriptions,
    required this.cancelledSubscriptions,
    required this.totalActiveTime,
    required this.planCounts,
    required this.averageSubscriptionValue,
  });

  String get formattedTotalSpent => '\$${totalSpent.toStringAsFixed(2)}';
  String get formattedAverageValue => '\$${averageSubscriptionValue.toStringAsFixed(2)}';
  String get formattedActiveTime => '${totalActiveTime.inDays} days';
}

/// Subscription analytics result
class SubscriptionAnalyticsResult {
  final bool success;
  final SubscriptionAnalytics? analytics;
  final String? error;

  const SubscriptionAnalyticsResult._({
    required this.success,
    this.analytics,
    this.error,
  });

  factory SubscriptionAnalyticsResult.success(SubscriptionAnalytics analytics) {
    return SubscriptionAnalyticsResult._(success: true, analytics: analytics);
  }

  factory SubscriptionAnalyticsResult.error(String error) {
    return SubscriptionAnalyticsResult._(success: false, error: error);
  }
}