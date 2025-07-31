import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../models/gift_model.dart';
import '../../models/enums.dart';
import 'user_service.dart';
import 'payment_service.dart';
import 'validation_service.dart';
import 'cache_service.dart';
import 'notification_service.dart';

class GiftService {
  static final GiftService _instance = GiftService._internal();
  factory GiftService() => _instance;
  GiftService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final PaymentService _paymentService = PaymentService();
  final ValidationService _validationService = ValidationService();
  final CacheService _cacheService = CacheService();
  final NotificationService _notificationService = NotificationService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Initialize with default gifts
  Future<void> initializeDefaultGifts() async {
    try {
      // Check if gifts already exist
      final existingGifts = await _firestore.collection('gifts').limit(1).get();
      if (existingGifts.docs.isNotEmpty) {
        debugPrint('Gifts already initialized');
        return;
      }

      final defaultGifts = _getDefaultGifts();
      final batch = _firestore.batch();

      for (final gift in defaultGifts) {
        final docRef = _firestore.collection('gifts').doc();
        batch.set(docRef, gift.copyWith(id: docRef.id).toFirestore());
      }

      await batch.commit();
      debugPrint('Default gifts initialized: ${defaultGifts.length} gifts');
    } catch (e) {
      debugPrint('Error initializing default gifts: $e');
    }
  }

  /// Get all available gifts (with caching)
  Future<GiftsResult> getAvailableGifts({
    GiftCategory? category,
    GiftRarity? rarity,
    bool premiumOnly = false,
    double? maxPrice,
  }) async {
    try {
      // Try cache first
      final cacheKey = 'gifts_${category?.toString() ?? 'all'}_${rarity?.toString() ?? 'all'}_$premiumOnly';
      final cachedGifts = _cacheService.getCachedString(cacheKey);
      
      if (cachedGifts != null) {
        try {
          final giftsData = jsonDecode(cachedGifts) as List;
          final gifts = giftsData.map((data) => GiftModel.fromJson(data)).toList();
          debugPrint('Gifts loaded from cache: ${gifts.length}');
          return GiftsResult.success(gifts);
        } catch (e) {
          // Cache data corrupted, continue to fetch from Firestore
          await _cacheService.removeCachedString(cacheKey);
        }
      }

      // Build query
      Query query = _firestore.collection('gifts').where('isActive', isEqualTo: true);

      if (category != null) {
        query = query.where('category', isEqualTo: category.toString().split('.').last);
      }

      if (rarity != null) {
        query = query.where('rarity', isEqualTo: rarity.toString().split('.').last);
      }

      if (premiumOnly) {
        query = query.where('isPremiumOnly', isEqualTo: true);
      }

      // Order by price (ascending)
      query = query.orderBy('price', descending: false);

      final querySnapshot = await query.get();
      var gifts = querySnapshot.docs.map((doc) => GiftModel.fromFirestore(doc)).toList();

      // Apply price filter client-side
      if (maxPrice != null) {
        gifts = gifts.where((gift) => gift.finalPrice <= maxPrice).toList();
      }

      // Cache the results
      if (gifts.isNotEmpty) {
        await _cacheService.cacheString(
          cacheKey,
          jsonEncode(gifts.map((g) => g.toJson()).toList()),
          expiry: const Duration(hours: 6),
        );
      }

      debugPrint('Gifts loaded from Firestore: ${gifts.length}');
      return GiftsResult.success(gifts);
    } catch (e) {
      debugPrint('Error getting available gifts: $e');
      return GiftsResult.error('Failed to load gifts');
    }
  }

  /// Get gifts by category
  Future<GiftsResult> getGiftsByCategory(GiftCategory category) async {
    return getAvailableGifts(category: category);
  }

  /// Get gift by ID
  Future<GiftResult> getGiftById(String giftId) async {
    try {
      // Try cache first
      final cachedGift = _cacheService.getCachedString('gift_$giftId');
      if (cachedGift != null) {
        try {
          final giftData = jsonDecode(cachedGift) as Map<String, dynamic>;
          final gift = GiftModel.fromJson(giftData);
          return GiftResult.success(gift);
        } catch (e) {
          await _cacheService.removeCachedString('gift_$giftId');
        }
      }

      final doc = await _firestore.collection('gifts').doc(giftId).get();
      
      if (!doc.exists) {
        return GiftResult.error('Gift not found');
      }

      final gift = GiftModel.fromFirestore(doc);
      
      if (!gift.isAvailable) {
        return GiftResult.error('Gift is no longer available');
      }

      // Cache the gift
      await _cacheService.cacheString(
        'gift_$giftId',
        jsonEncode(gift.toJson()),
        expiry: const Duration(hours: 6),
      );

      return GiftResult.success(gift);
    } catch (e) {
      debugPrint('Error getting gift: $e');
      return GiftResult.error('Failed to load gift');
    }
  }

  /// Send gift to user
  Future<GiftSendResult> sendGift({
    required String giftId,
    required String recipientUserId,
    String? personalMessage,
    String? conversationId,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return GiftSendResult.error('No user signed in');
      }

      if (userId == recipientUserId) {
        return GiftSendResult.error('Cannot send gift to yourself');
      }

      // Get gift details
      final giftResult = await getGiftById(giftId);
      if (!giftResult.success || giftResult.gift == null) {
        return GiftSendResult.error('Gift not found or unavailable');
      }

      final gift = giftResult.gift!;

      // Validate gift purchase
      final giftValidation = _validationService.validateGiftPurchase(
        giftId: giftId,
        recipientId: recipientUserId,
        amount: gift.finalPrice,
      );

      if (!giftValidation.isValid) {
        return GiftSendResult.error(giftValidation.error!);
      }

      // Get recipient user data
      final recipientResult = await _userService.getUserById(recipientUserId);
      if (!recipientResult.success || recipientResult.user == null) {
        return GiftSendResult.error('Recipient not found');
      }

      final recipient = recipientResult.user!;

      // Check if recipient can receive gifts
      if (!recipient.canReceiveMessages) {
        return GiftSendResult.error('This user cannot receive gifts');
      }

      // Get sender user data
      final senderResult = await _userService.getCurrentUser();
      if (!senderResult.success || senderResult.user == null) {
        return GiftSendResult.error('Failed to get sender data');
      }

      final sender = senderResult.user!;

      // Check if users have blocked each other
      if (sender.blockedUsers.contains(recipientUserId) || 
          recipient.blockedUsers.contains(userId)) {
        return GiftSendResult.error('Cannot send gift to this user');
      }

      // Check premium-only gifts
      if (gift.isPremiumOnly && !sender.isPremium) {
        return GiftSendResult.error('This gift requires a premium subscription');
      }

      // Process payment through PaymentService (App Store/Google Play)
      final paymentResult = await _paymentService.purchaseGift(
        giftId: giftId,
        recipientUserId: recipientUserId,
        personalMessage: personalMessage,
        conversationId: conversationId,
      );

      if (!paymentResult.success) {
        return GiftSendResult.error('Payment failed: ${paymentResult.error}');
      }

      // Create sent gift record
      final now = DateTime.now();
      final sentGift = SentGiftModel(
        id: '', // Will be set by Firestore
        giftId: giftId,
        gift: gift,
        senderId: userId,
        receiverId: recipientUserId,
        conversationId: conversationId,
        sentAt: now,
        message: personalMessage,
        metadata: {
          'paymentStatus': 'completed',
          'originalPrice': gift.price,
          'finalPrice': gift.finalPrice,
          'rarity': gift.rarity.toString().split('.').last,
          'paymentMethod': 'mobile_store',
        },
      );

      // Save sent gift to Firestore
      final docRef = await _firestore.collection('sent_gifts').add(sentGift.toFirestore());
      final savedSentGift = sentGift.copyWith(id: docRef.id);

      // Send gift notification
      await _notificationService.sendGiftNotification(
        senderId: userId,
        receiverId: recipientUserId,
        giftName: gift.name,
        giftImageUrl: gift.imageUrl,
        personalMessage: personalMessage,
        conversationId: conversationId,
      );

      // Clear relevant caches
      await _clearGiftCaches();

      debugPrint('Gift sent: $giftId to $recipientUserId, value: ${gift.finalPrice}');
      return GiftSendResult.success(
        sentGift: savedSentGift,
        paymentId: savedSentGift.id,
      );
    } catch (e) {
      debugPrint('Error sending gift: $e');
      return GiftSendResult.error('Failed to send gift');
    }
  }

  /// Get gifts sent by current user
  Future<SentGiftsResult> getSentGifts({
    String? recipientUserId,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return SentGiftsResult.error('No user signed in');
      }

      Query query = _firestore
          .collection('sent_gifts')
          .where('senderId', isEqualTo: userId);

      if (recipientUserId != null) {
        query = query.where('receiverId', isEqualTo: recipientUserId);
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.orderBy('sentAt', descending: true).limit(limit);

      final querySnapshot = await query.get();
      final sentGifts = querySnapshot.docs
          .map((doc) => SentGiftModel.fromFirestore(doc))
          .toList();

      debugPrint('Sent gifts loaded: ${sentGifts.length}');
      return SentGiftsResult.success(
        sentGifts: sentGifts,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error getting sent gifts: $e');
      return SentGiftsResult.error('Failed to load sent gifts');
    }
  }

  /// Get gifts received by current user
  Future<SentGiftsResult> getReceivedGifts({
    String? senderUserId,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return SentGiftsResult.error('No user signed in');
      }

      Query query = _firestore
          .collection('sent_gifts')
          .where('receiverId', isEqualTo: userId);

      if (senderUserId != null) {
        query = query.where('senderId', isEqualTo: senderUserId);
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.orderBy('sentAt', descending: true).limit(limit);

      final querySnapshot = await query.get();
      final receivedGifts = querySnapshot.docs
          .map((doc) => SentGiftModel.fromFirestore(doc))
          .toList();

      debugPrint('Received gifts loaded: ${receivedGifts.length}');
      return SentGiftsResult.success(
        sentGifts: receivedGifts,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error getting received gifts: $e');
      return SentGiftsResult.error('Failed to load received gifts');
    }
  }

  /// Mark gift as read
  Future<SentGiftResult> markGiftAsRead(String sentGiftId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return SentGiftResult.error('No user signed in');
      }

      // Get sent gift
      final doc = await _firestore.collection('sent_gifts').doc(sentGiftId).get();
      if (!doc.exists) {
        return SentGiftResult.error('Gift not found');
      }

      final sentGift = SentGiftModel.fromFirestore(doc);

      // Only receiver can mark as read
      if (sentGift.receiverId != userId) {
        return SentGiftResult.error('Access denied');
      }

      if (sentGift.isRead) {
        return SentGiftResult.success(sentGift);
      }

      // Update as read
      final updatedSentGift = sentGift.copyWith(isRead: true);
      
      await _firestore.collection('sent_gifts').doc(sentGiftId).update({
        'isRead': true,
      });

      debugPrint('Gift marked as read: $sentGiftId');
      return SentGiftResult.success(updatedSentGift);
    } catch (e) {
      debugPrint('Error marking gift as read: $e');
      return SentGiftResult.error('Failed to mark gift as read');
    }
  }

  /// Get unread gifts count
  Future<int> getUnreadGiftsCount() async {
    try {
      final userId = currentUserId;
      if (userId == null) return 0;

      final querySnapshot = await _firestore
          .collection('sent_gifts')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting unread gifts count: $e');
      return 0;
    }
  }

  /// Stream received gifts for real-time updates
  Stream<List<SentGiftModel>> streamReceivedGifts() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('sent_gifts')
        .where('receiverId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SentGiftModel.fromFirestore(doc))
            .toList());
  }

  /// Get gift categories with counts
  Future<Map<GiftCategory, int>> getGiftCategoryCounts() async {
    try {
      final giftsResult = await getAvailableGifts();
      if (!giftsResult.success) return {};

      final categoryCounts = <GiftCategory, int>{};
      for (final gift in giftsResult.gifts) {
        categoryCounts[gift.category] = (categoryCounts[gift.category] ?? 0) + 1;
      }

      return categoryCounts;
    } catch (e) {
      debugPrint('Error getting gift category counts: $e');
      return {};
    }
  }

  /// Clear gift-related caches
  Future<void> _clearGiftCaches() async {
    try {
      // Clear gift list caches
      final categories = GiftCategory.values;
      for (final category in categories) {
        await _cacheService.removeCachedString('gifts_${category.toString()}_all_false');
        await _cacheService.removeCachedString('gifts_${category.toString()}_all_true');
      }
      
      await _cacheService.removeCachedString('gifts_all_all_false');
      await _cacheService.removeCachedString('gifts_all_all_true');
    } catch (e) {
      debugPrint('Error clearing gift caches: $e');
    }
  }

  /// Get default gifts for initialization
  List<GiftModel> _getDefaultGifts() {
    final now = DateTime.now();
    
    return [
      // Hearts & Love
      GiftModel(
        id: '',
        name: 'Red Rose',
        description: 'A beautiful red rose to show your love',
        imageUrl: '🌹',
        animationUrl: '',
        price: 2.99,
        category: GiftCategory.hearts,
        rarity: GiftRarity.common,
        createdAt: now,
        tags: ['love', 'romance', 'classic'],
      ),
      GiftModel(
        id: '',
        name: 'Heart Bouquet',
        description: 'A romantic bouquet of hearts',
        imageUrl: '💐',
        animationUrl: '',
        price: 4.99,
        category: GiftCategory.hearts,
        rarity: GiftRarity.uncommon,
        createdAt: now,
        tags: ['love', 'hearts', 'special'],
      ),
      
      // Flowers
      GiftModel(
        id: '',
        name: 'Sunflower',
        description: 'Bright and cheerful sunflower',
        imageUrl: '🌻',
        animationUrl: '',
        price: 1.99,
        category: GiftCategory.flowers,
        rarity: GiftRarity.common,
        createdAt: now,
        tags: ['happy', 'bright', 'cheerful'],
      ),
      GiftModel(
        id: '',
        name: 'Tropical Flower',
        description: 'Exotic tropical bloom',
        imageUrl: '🌺',
        animationUrl: '',
        price: 3.49,
        category: GiftCategory.flowers,
        rarity: GiftRarity.uncommon,
        createdAt: now,
        tags: ['exotic', 'tropical', 'special'],
      ),

      // Food & Treats
      GiftModel(
        id: '',
        name: 'Chocolate Box',
        description: 'Delicious box of chocolates',
        imageUrl: '🍫',
        animationUrl: '',
        price: 3.99,
        category: GiftCategory.food,
        rarity: GiftRarity.common,
        createdAt: now,
        tags: ['sweet', 'chocolate', 'treat'],
      ),
      GiftModel(
        id: '',
        name: 'Birthday Cake',
        description: 'Special celebration cake',
        imageUrl: '🍰',
        animationUrl: '',
        price: 5.99,
        category: GiftCategory.food,
        rarity: GiftRarity.rare,
        createdAt: now,
        tags: ['celebration', 'birthday', 'special'],
      ),

      // Drinks
      GiftModel(
        id: '',
        name: 'Coffee Date',
        description: 'Virtual coffee date invitation',
        imageUrl: '☕',
        animationUrl: '',
        price: 2.49,
        category: GiftCategory.drinks,
        rarity: GiftRarity.common,
        createdAt: now,
        tags: ['coffee', 'date', 'casual'],
      ),
      GiftModel(
        id: '',
        name: 'Champagne',
        description: 'Celebrate with champagne',
        imageUrl: '🍾',
        animationUrl: '',
        price: 7.99,
        category: GiftCategory.drinks,
        rarity: GiftRarity.rare,
        createdAt: now,
        tags: ['celebration', 'champagne', 'luxury'],
      ),

      // Jewelry
      GiftModel(
        id: '',
        name: 'Diamond Ring',
        description: 'Sparkling diamond ring',
        imageUrl: '💍',
        animationUrl: '',
        price: 19.99,
        category: GiftCategory.jewelry,
        rarity: GiftRarity.legendary,
        createdAt: now,
        tags: ['diamond', 'luxury', 'precious'],
        isPremiumOnly: true,
      ),
      GiftModel(
        id: '',
        name: 'Golden Star',
        description: 'Shining golden star',
        imageUrl: '⭐',
        animationUrl: '',
        price: 11.99,
        category: GiftCategory.jewelry,
        rarity: GiftRarity.epic,
        createdAt: now,
        tags: ['gold', 'star', 'special'],
      ),

      // Activities
      GiftModel(
        id: '',
        name: 'Movie Night',
        description: 'Virtual movie night together',
        imageUrl: '🎬',
        animationUrl: '',
        price: 4.49,
        category: GiftCategory.activities,
        rarity: GiftRarity.uncommon,
        createdAt: now,
        tags: ['movie', 'date', 'fun'],
      ),

      // Premium/Special
      GiftModel(
        id: '',
        name: 'Crown',
        description: 'Royal crown for a queen/king',
        imageUrl: '👑',
        animationUrl: '',
        price: 9.99,
        category: GiftCategory.premium,
        rarity: GiftRarity.epic,
        createdAt: now,
        tags: ['royal', 'crown', 'special'],
        isPremiumOnly: true,
      ),
    ];
  }

  /// Clear all gift caches
  Future<void> clearGiftCache() async {
    try {
      await _clearGiftCaches();
      debugPrint('Gift cache cleared');
    } catch (e) {
      debugPrint('Error clearing gift cache: $e');
    }
  }

  /// Dispose service
  void dispose() {
    debugPrint('GiftService disposed');
  }
}

/// Gift operation result
class GiftResult {
  final bool success;
  final GiftModel? gift;
  final String? error;

  const GiftResult._({
    required this.success,
    this.gift,
    this.error,
  });

  factory GiftResult.success(GiftModel gift) {
    return GiftResult._(success: true, gift: gift);
  }

  factory GiftResult.error(String error) {
    return GiftResult._(success: false, error: error);
  }
}

/// Gifts list result
class GiftsResult {
  final bool success;
  final List<GiftModel> gifts;
  final String? error;

  const GiftsResult._({
    required this.success,
    this.gifts = const [],
    this.error,
  });

  factory GiftsResult.success(List<GiftModel> gifts) {
    return GiftsResult._(success: true, gifts: gifts);
  }

  factory GiftsResult.error(String error) {
    return GiftsResult._(success: false, error: error);
  }
}

/// Gift send result
class GiftSendResult {
  final bool success;
  final SentGiftModel? sentGift;
  final String? paymentId;
  final String? error;

  const GiftSendResult._({
    required this.success,
    this.sentGift,
    this.paymentId,
    this.error,
  });

  factory GiftSendResult.success({
    required SentGiftModel sentGift,
    required String paymentId,
  }) {
    return GiftSendResult._(
      success: true,
      sentGift: sentGift,
      paymentId: paymentId,
    );
  }

  factory GiftSendResult.error(String error) {
    return GiftSendResult._(success: false, error: error);
  }
}

/// Sent gift result
class SentGiftResult {
  final bool success;
  final SentGiftModel? sentGift;
  final String? error;

  const SentGiftResult._({
    required this.success,
    this.sentGift,
    this.error,
  });

  factory SentGiftResult.success(SentGiftModel sentGift) {
    return SentGiftResult._(success: true, sentGift: sentGift);
  }

  factory SentGiftResult.error(String error) {
    return SentGiftResult._(success: false, error: error);
  }
}

/// Sent gifts list result
class SentGiftsResult {
  final bool success;
  final List<SentGiftModel> sentGifts;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? error;

  const SentGiftsResult._({
    required this.success,
    this.sentGifts = const [],
    this.lastDocument,
    this.hasMore = false,
    this.error,
  });

  factory SentGiftsResult.success({
    required List<SentGiftModel> sentGifts,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
  }) {
    return SentGiftsResult._(
      success: true,
      sentGifts: sentGifts,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  factory SentGiftsResult.error(String error) {
    return SentGiftsResult._(success: false, error: error);
  }
}