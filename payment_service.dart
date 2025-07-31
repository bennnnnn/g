
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../models/enums.dart';
import 'validation_service.dart';
import 'cache_service.dart';
import 'user_service.dart';
import 'notification_service.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final ValidationService _validationService = ValidationService();
  final CacheService _cacheService = CacheService();
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();

  // Product IDs for your app (configure in Play Store/App Store)
  static const Map<SubscriptionPlan, String> _subscriptionProductIds = {
    SubscriptionPlan.daily: 'daily_premium_5_69',
    SubscriptionPlan.weekly: 'weekly_premium_6_99',
    SubscriptionPlan.monthly: 'monthly_premium_9_89',
  };

  // Gift product IDs
  static const Map<String, String> _giftProductIds = {
    'red_rose': 'gift_red_rose_2_99',
    'bouquet': 'gift_bouquet_4_99',
    'sunflower': 'gift_sunflower_1_99',
    'tropical_flower': 'gift_tropical_3_49',
    'chocolate_box': 'gift_chocolate_3_99',
    'birthday_cake': 'gift_cake_5_99',
    'coffee_date': 'gift_coffee_2_49',
    'champagne': 'gift_champagne_7_99',
    'diamond_ring': 'gift_diamond_ring_19_99',
    'golden_star': 'gift_golden_star_11_99',
    'movie_night': 'gift_movie_4_49',
    'crown': 'gift_crown_9_99',
  };

  // Payment completion callbacks
  Function(String productId, PurchaseDetails details)? _onPaymentSuccess;
  Function(String productId, String error)? _onPaymentError;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Initialize payment system for mobile
  Future<bool> initializePayments() async {
    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        debugPrint('In-app purchases not available on this device');
        return false;
      }

      // Listen to purchase updates from App Store/Play Store
      _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (error) {
          debugPrint('Payment stream error: $error');
        },
      );

      debugPrint('Mobile payment service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing mobile payments: $e');
      return false;
    }
  }

  /// Set payment callbacks
  void setPaymentCallbacks({
    Function(String productId, PurchaseDetails details)? onSuccess,
    Function(String productId, String error)? onError,
  }) {
    _onPaymentSuccess = onSuccess;
    _onPaymentError = onError;
  }

  /// Get available subscription products from stores
  Future<SubscriptionProductsResult> getSubscriptionProducts() async {
    try {
      final productIds = _subscriptionProductIds.values.toSet();
      
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);
      
      if (response.error != null) {
        return SubscriptionProductsResult.error('Failed to load subscription options: ${response.error!.message}');
      }

      if (response.productDetails.isEmpty) {
        return SubscriptionProductsResult.error('No subscription products found. Please check your app store configuration.');
      }

      // Map products to subscription plans
      final subscriptionProducts = <SubscriptionPlan, ProductDetails>{};
      
      for (final product in response.productDetails) {
        for (final entry in _subscriptionProductIds.entries) {
          if (entry.value == product.id) {
            subscriptionProducts[entry.key] = product;
            break;
          }
        }
      }

      debugPrint('Loaded ${subscriptionProducts.length} subscription products');
      return SubscriptionProductsResult.success(subscriptionProducts);
    } catch (e) {
      debugPrint('Error getting subscription products: $e');
      return SubscriptionProductsResult.error('Failed to load subscription options');
    }
  }

  /// Get available gift products from stores
  Future<GiftProductsResult> getGiftProducts() async {
    try {
      final productIds = _giftProductIds.values.toSet();
      
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);
      
      if (response.error != null) {
        return GiftProductsResult.error('Failed to load gift options: ${response.error!.message}');
      }

      if (response.productDetails.isEmpty) {
        return GiftProductsResult.error('No gift products found. Please check your app store configuration.');
      }

      // Map products to gift IDs
      final giftProducts = <String, ProductDetails>{};
      
      for (final product in response.productDetails) {
        for (final entry in _giftProductIds.entries) {
          if (entry.value == product.id) {
            giftProducts[entry.key] = product;
            break;
          }
        }
      }

      debugPrint('Loaded ${giftProducts.length} gift products');
      return GiftProductsResult.success(giftProducts);
    } catch (e) {
      debugPrint('Error getting gift products: $e');
      return GiftProductsResult.error('Failed to load gift options');
    }
  }

  /// Purchase subscription through App Store/Play Store
  Future<PaymentResult> purchaseSubscription({
    required SubscriptionPlan plan,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return PaymentResult.error('No user signed in');
      }

      // Validate subscription plan
      final planValidation = _validationService.validateSubscriptionPlan(plan.toString().split('.').last);
      if (!planValidation.isValid) {
        return PaymentResult.error(planValidation.error!);
      }

      // Get product details
      final productsResult = await getSubscriptionProducts();
      if (!productsResult.success) {
        return PaymentResult.error(productsResult.error!);
      }

      final product = productsResult.products[plan];
      if (product == null) {
        return PaymentResult.error('Subscription plan not available');
      }

      // Validate with enhanced validation
      final paymentValidation = _validationService.validateMobilePayment(
        productId: product.id,
        amount: double.tryParse(product.price),
      );

      if (!paymentValidation.isValid) {
        return PaymentResult.error(paymentValidation.error!);
      }

      // Store pending purchase info
      await _cacheService.cacheString(
        'pending_subscription_$userId',
        '${plan.toString().split('.').last}_${product.price}',
        expiry: const Duration(minutes: 10),
      );

      // Create purchase param for subscription
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

      // Start purchase through App Store/Play Store
      final bool result = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      
      if (!result) {
        await _cacheService.removeCachedString('pending_subscription_$userId');
        return PaymentResult.error('Failed to start payment process');
      }

      debugPrint('Subscription purchase initiated: ${product.id}');
      return PaymentResult.success();
    } catch (e) {
      debugPrint('Error purchasing subscription: $e');
      return PaymentResult.error('Payment failed. Please try again.');
    }
  }

  /// Purchase gift through App Store/Play Store
  Future<PaymentResult> purchaseGift({
    required String giftId,
    required String recipientUserId,
    String? personalMessage,
    String? conversationId,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return PaymentResult.error('No user signed in');
      }

      if (userId == recipientUserId) {
        return PaymentResult.error('Cannot send gift to yourself');
      }

      // Check if recipient exists and can receive gifts
      final recipientResult = await _userService.getUserById(recipientUserId);
      if (!recipientResult.success || recipientResult.user == null) {
        return PaymentResult.error('Recipient not found');
      }

      if (!recipientResult.user!.canReceiveMessages) {
        return PaymentResult.error('Recipient cannot receive gifts');
      }

      // Get gift product details
      final productsResult = await getGiftProducts();
      if (!productsResult.success) {
        return PaymentResult.error(productsResult.error!);
      }

      final product = productsResult.products[giftId];
      if (product == null) {
        return PaymentResult.error('Gift not available');
      }

      // Validate gift purchase
      final giftValidation = _validationService.validateGiftPurchase(
        giftId: giftId,
        recipientId: recipientUserId,
        amount: double.tryParse(product.price),
      );

      if (!giftValidation.isValid) {
        return PaymentResult.error(giftValidation.error!);
      }

      // Store pending gift info
      await _cacheService.cacheString(
        'pending_gift_$userId',
        '$giftId|$recipientUserId|${personalMessage ?? ""}|${conversationId ?? ""}',
        expiry: const Duration(minutes: 10),
      );

      // Create purchase param for gift (consumable)
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

      // Start purchase through App Store/Play Store
      final bool result = await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      
      if (!result) {
        await _cacheService.removeCachedString('pending_gift_$userId');
        return PaymentResult.error('Failed to start payment process');
      }

      debugPrint('Gift purchase initiated: ${product.id} for $recipientUserId');
      return PaymentResult.success();
    } catch (e) {
      debugPrint('Error purchasing gift: $e');
      return PaymentResult.error('Payment failed. Please try again.');
    }
  }

  /// Handle purchase updates from App Store/Play Store
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('Purchase update: ${purchaseDetails.productID}, status: ${purchaseDetails.status}');
      
      switch (purchaseDetails.status) {
        case PurchaseStatus.purchased:
          _handleSuccessfulPurchase(purchaseDetails);
          break;
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${purchaseDetails.error}');
          _onPaymentError?.call(
            purchaseDetails.productID,
            purchaseDetails.error?.message ?? 'Payment failed',
          );
          break;
        case PurchaseStatus.pending:
          debugPrint('Purchase pending: ${purchaseDetails.productID}');
          // Handle pending state if needed
          break;
        case PurchaseStatus.canceled:
          debugPrint('Purchase canceled: ${purchaseDetails.productID}');
          _onPaymentError?.call(purchaseDetails.productID, 'Payment canceled');
          break;
        case PurchaseStatus.restored:
          _handleRestoredPurchase(purchaseDetails);
          break;
      }

      // Complete the purchase (important for App Store/Play Store)
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// Handle successful purchase completion
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('No user signed in during purchase completion');
        return;
      }

      // Mobile verification: App Store/Play Store already verified the purchase
      if (!_verifyMobilePurchase(purchaseDetails)) {
        debugPrint('Mobile purchase verification failed');
        _onPaymentError?.call(purchaseDetails.productID, 'Payment verification failed');
        return;
      }

      // Record purchase in Firestore
      await _recordPurchaseInFirestore(purchaseDetails);

      // Check if this was a subscription
      final pendingSubscription = _cacheService.getCachedString('pending_subscription_$userId');
      if (pendingSubscription != null) {
        await _handleSubscriptionPurchaseCompletion(purchaseDetails, pendingSubscription);
        await _cacheService.removeCachedString('pending_subscription_$userId');
      }

      // Check if this was a gift
      final pendingGift = _cacheService.getCachedString('pending_gift_$userId');
      if (pendingGift != null) {
        await _handleGiftPurchaseCompletion(purchaseDetails, pendingGift);
        await _cacheService.removeCachedString('pending_gift_$userId');
      }

      // Notify success callback
      _onPaymentSuccess?.call(purchaseDetails.productID, purchaseDetails);

      debugPrint('Mobile payment completed successfully: ${purchaseDetails.productID}');
    } catch (e) {
      debugPrint('Error handling successful purchase: $e');
      _onPaymentError?.call(purchaseDetails.productID, 'Payment processing failed');
    }
  }

  /// Verify mobile purchase (App Store/Play Store handles verification)
  bool _verifyMobilePurchase(PurchaseDetails purchaseDetails) {
    try {
      // Basic validation - stores handle the heavy verification
      if (purchaseDetails.purchaseID == null || purchaseDetails.purchaseID!.isEmpty) {
        return false;
      }

      if (purchaseDetails.productID.isEmpty) {
        return false;
      }

      if (purchaseDetails.status != PurchaseStatus.purchased) {
        return false;
      }

      // Check if purchase is recent (within 24 hours)
      if (purchaseDetails.transactionDate != null) {
        try {
          final transactionTime = DateTime.fromMillisecondsSinceEpoch(
            int.parse(purchaseDetails.transactionDate!)
          );
          final timeDiff = DateTime.now().difference(transactionTime);
          if (timeDiff.inHours > 24) {
            debugPrint('Transaction too old: ${timeDiff.inHours} hours');
            return false;
          }
        } catch (e) {
          debugPrint('Could not parse transaction date, continuing: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Mobile purchase verification error: $e');
      return false;
    }
  }

  /// Record purchase in Firestore for auditing
  Future<void> _recordPurchaseInFirestore(PurchaseDetails purchaseDetails) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      await _firestore.collection('mobile_purchases').add({
        'userId': userId,
        'productId': purchaseDetails.productID,
        'purchaseId': purchaseDetails.purchaseID,
        'transactionDate': purchaseDetails.transactionDate,
        'platform': purchaseDetails.verificationData.source, // 'app_store' or 'google_play'
        'status': 'completed',
        'verificationSource': 'app_store_play_store', // Mobile verification
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'metadata': {
          'pendingComplete': purchaseDetails.pendingCompletePurchase,
          'hasLocalVerificationData': purchaseDetails.verificationData.localVerificationData.isNotEmpty,
        },
      });
      
      debugPrint('Mobile purchase recorded in Firestore');
    } catch (e) {
      debugPrint('Error recording mobile purchase: $e');
    }
  }

  /// Handle subscription purchase completion
  Future<void> _handleSubscriptionPurchaseCompletion(
    PurchaseDetails purchaseDetails,
    String pendingInfo,
  ) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      // Parse pending subscription info
      final parts = pendingInfo.split('_');
      if (parts.length >= 2) {
        final planString = parts[0];
        
        final plan = SubscriptionPlan.values.firstWhere(
          (p) => p.toString().split('.').last == planString,
          orElse: () => SubscriptionPlan.free,
        );

        if (plan != SubscriptionPlan.free) {
          // Calculate subscription duration
          final duration = _getSubscriptionDuration(plan);
          final expiresAt = DateTime.now().add(duration);
          
          // Update user's subscription through UserService
          await _userService.updateSubscription(
            plan: plan,
            expiresAt: expiresAt,
          );

          // Send activation notification
          await _notificationService.sendSubscriptionNotification(
            userId: userId,
            plan: plan,
            type: SubscriptionNotificationType.activated,
          );

          debugPrint('Mobile subscription activated: $plan, expires: $expiresAt');
        }
      }
    } catch (e) {
      debugPrint('Error handling subscription purchase completion: $e');
    }
  }

  /// Handle gift purchase completion
  Future<void> _handleGiftPurchaseCompletion(
    PurchaseDetails purchaseDetails,
    String pendingInfo,
  ) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      // Parse pending gift info: giftId|recipientId|message|conversationId
      final parts = pendingInfo.split('|');
      if (parts.length >= 2) {
        final giftId = parts[0];
        final recipientUserId = parts[1];
        final personalMessage = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
        final conversationId = parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null;

        // Get gift details for notification
        final giftName = _getGiftNameById(giftId);
        final giftEmoji = _getGiftEmojiById(giftId);

        // Update gift statistics
        final amount = double.tryParse(purchaseDetails.productID.split('_').last.replaceAll('_', '.')) ?? 0.0;
        
        await _userService.updateGiftStats(
          userId: userId,
          isSending: true,
          giftValue: amount,
        );

        await _userService.updateGiftStats(
          userId: recipientUserId,
          isSending: false,
          giftValue: amount,
        );

        // Send gift notification
        await _notificationService.sendGiftNotification(
          senderId: userId,
          receiverId: recipientUserId,
          giftName: giftName,
          giftImageUrl: giftEmoji,
          personalMessage: personalMessage,
          conversationId: conversationId,
        );

        debugPrint('Mobile gift completed: $giftId to $recipientUserId');
      }
    } catch (e) {
      debugPrint('Error handling gift purchase completion: $e');
    }
  }

  /// Handle restored purchases (mainly for subscriptions)
  Future<void> _handleRestoredPurchase(PurchaseDetails purchaseDetails) async {
    // For subscriptions, restore the active subscription
    await _handleSuccessfulPurchase(purchaseDetails);
  }

  /// Get subscription duration for mobile plans
  Duration _getSubscriptionDuration(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.daily:
        return const Duration(days: 1);
      case SubscriptionPlan.weekly:
        return const Duration(days: 7);
      case SubscriptionPlan.monthly:
        return const Duration(days: 30);
      case SubscriptionPlan.free:
        return const Duration(days: 365); // Never expires
    }
  }

  /// Get gift name by ID for notifications
  String _getGiftNameById(String giftId) {
    const giftNames = {
      'red_rose': 'Red Rose',
      'bouquet': 'Bouquet',
      'sunflower': 'Sunflower',
      'tropical_flower': 'Tropical Flower',
      'chocolate_box': 'Chocolate Box',
      'birthday_cake': 'Birthday Cake',
      'coffee_date': 'Coffee Date',
      'champagne': 'Champagne',
      'diamond_ring': 'Diamond Ring',
      'golden_star': 'Golden Star',
      'movie_night': 'Movie Night',
      'crown': 'Crown',
    };
    
    return giftNames[giftId] ?? 'Gift';
  }

  /// Get gift emoji by ID for notifications
  String _getGiftEmojiById(String giftId) {
    const giftEmojis = {
      'red_rose': '🌹',
      'bouquet': '💐',
      'sunflower': '🌻',
      'tropical_flower': '🌺',
      'chocolate_box': '🍫',
      'birthday_cake': '🍰',
      'coffee_date': '☕',
      'champagne': '🍾',
      'diamond_ring': '💍',
      'golden_star': '⭐',
      'movie_night': '🎬',
      'crown': '👑',
    };
    
    return giftEmojis[giftId] ?? '🎁';
  }

  /// Restore purchases (for subscriptions)
  Future<PaymentResult> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      debugPrint('Mobile purchases restored successfully');
      return PaymentResult.success();
    } catch (e) {
      debugPrint('Error restoring mobile purchases: $e');
      return PaymentResult.error('Failed to restore purchases');
    }
  }

  /// Check if in-app purchases are available
  Future<bool> isPaymentAvailable() async {
    return await _inAppPurchase.isAvailable();
  }

  /// Get user's mobile purchase history
  Future<MobilePurchaseHistoryResult> getPurchaseHistory({
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return MobilePurchaseHistoryResult.error('No user signed in');
      }

      Query query = _firestore
          .collection('mobile_purchases')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      final purchases = querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();

      debugPrint('Mobile purchase history loaded: ${purchases.length} purchases');
      return MobilePurchaseHistoryResult.success(
        purchases: purchases,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error getting mobile purchase history: $e');
      return MobilePurchaseHistoryResult.error('Failed to get purchase history');
    }
  }

  /// Clear payment cache
  Future<void> clearPaymentCache() async {
    try {
      final userId = currentUserId;
      if (userId != null) {
        await _cacheService.removeCachedString('pending_subscription_$userId');
        await _cacheService.removeCachedString('pending_gift_$userId');
      }
      debugPrint('Mobile payment cache cleared');
    } catch (e) {
      debugPrint('Error clearing mobile payment cache: $e');
    }
  }

  /// Dispose service
  void dispose() {
    _onPaymentSuccess = null;
    _onPaymentError = null;
    debugPrint('Mobile PaymentService disposed');
  }
}

/// Payment operation result
class PaymentResult {
  final bool success;
  final String? error;

  const PaymentResult._({
    required this.success,
    this.error,
  });

  factory PaymentResult.success() {
    return const PaymentResult._(success: true);
  }

  factory PaymentResult.error(String error) {
    return PaymentResult._(success: false, error: error);
  }
}

/// Subscription products result
class SubscriptionProductsResult {
  final bool success;
  final Map<SubscriptionPlan, ProductDetails> products;
  final String? error;

  const SubscriptionProductsResult._({
    required this.success,
    this.products = const {},
    this.error,
  });

  factory SubscriptionProductsResult.success(Map<SubscriptionPlan, ProductDetails> products) {
    return SubscriptionProductsResult._(success: true, products: products);
  }

  factory SubscriptionProductsResult.error(String error) {
    return SubscriptionProductsResult._(success: false, error: error);
  }
}

/// Gift products result
class GiftProductsResult {
  final bool success;
  final Map<String, ProductDetails> products;
  final String? error;

  const GiftProductsResult._({
    required this.success,
    this.products = const {},
    this.error,
  });

  factory GiftProductsResult.success(Map<String, ProductDetails> products) {
    return GiftProductsResult._(success: true, products: products);
  }

  factory GiftProductsResult.error(String error) {
    return GiftProductsResult._(success: false, error: error);
  }
}

/// Mobile purchase history result
class MobilePurchaseHistoryResult {
  final bool success;
  final List<Map<String, dynamic>> purchases;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? error;

  const MobilePurchaseHistoryResult._({
    required this.success,
    this.purchases = const [],
    this.lastDocument,
    this.hasMore = false,
    this.error,
  });

  factory MobilePurchaseHistoryResult.success({
    required List<Map<String, dynamic>> purchases,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
  }) {
    return MobilePurchaseHistoryResult._(
      success: true,
      purchases: purchases,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  factory MobilePurchaseHistoryResult.error(String error) {
    return MobilePurchaseHistoryResult._(success: false, error: error);
  }
}