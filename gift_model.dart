import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class GiftModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String animationUrl;
  final double price; // Price in USD (changed from int to double for decimal prices)
  final GiftCategory category;
  final GiftRarity rarity;
  final bool isActive;
  final bool isPremiumOnly;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final List<String> tags;

  GiftModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.animationUrl,
    required this.price,
    required this.category,
    this.rarity = GiftRarity.common,
    this.isActive = true,
    this.isPremiumOnly = false,
    required this.createdAt,
    this.metadata,
    this.tags = const [],
  });

  // Get final price with rarity multiplier
  double get finalPrice {
    return price * rarity.priceMultiplier;
  }

  // Get formatted price string
  String get formattedPrice {
    return '\$${finalPrice.toStringAsFixed(2)}';
  }

  // Check if gift is available for purchase
  bool get isAvailable {
    return isActive;
  }

  // Convert from Firestore
  factory GiftModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return GiftModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      animationUrl: data['animationUrl'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      category: GiftCategory.values.firstWhere(
        (e) => e.toString() == 'GiftCategory.${data['category']}',
        orElse: () => GiftCategory.hearts,
      ),
      rarity: GiftRarity.values.firstWhere(
        (e) => e.toString() == 'GiftRarity.${data['rarity']}',
        orElse: () => GiftRarity.common,
      ),
      isActive: data['isActive'] ?? true,
      isPremiumOnly: data['isPremiumOnly'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      metadata: data['metadata'],
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'animationUrl': animationUrl,
      'price': price,
      'category': category.toString().split('.').last,
      'rarity': rarity.toString().split('.').last,
      'isActive': isActive,
      'isPremiumOnly': isPremiumOnly,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
      'tags': tags,
    };
  }

  // Convert from JSON
  factory GiftModel.fromJson(Map<String, dynamic> json) {
    return GiftModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      animationUrl: json['animationUrl'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      category: GiftCategory.values.firstWhere(
        (e) => e.toString() == 'GiftCategory.${json['category']}',
        orElse: () => GiftCategory.hearts,
      ),
      rarity: GiftRarity.values.firstWhere(
        (e) => e.toString() == 'GiftRarity.${json['rarity']}',
        orElse: () => GiftRarity.common,
      ),
      isActive: json['isActive'] ?? true,
      isPremiumOnly: json['isPremiumOnly'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      metadata: json['metadata'],
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'animationUrl': animationUrl,
      'price': price,
      'category': category.toString().split('.').last,
      'rarity': rarity.toString().split('.').last,
      'isActive': isActive,
      'isPremiumOnly': isPremiumOnly,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
      'tags': tags,
    };
  }

  // Create a copy with updated fields
  GiftModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? animationUrl,
    double? price,
    GiftCategory? category,
    GiftRarity? rarity,
    bool? isActive,
    bool? isPremiumOnly,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
    List<String>? tags,
  }) {
    return GiftModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      animationUrl: animationUrl ?? this.animationUrl,
      price: price ?? this.price,
      category: category ?? this.category,
      rarity: rarity ?? this.rarity,
      isActive: isActive ?? this.isActive,
      isPremiumOnly: isPremiumOnly ?? this.isPremiumOnly,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
    );
  }

  @override
  String toString() {
    return 'GiftModel(id: $id, name: $name, price: $formattedPrice, category: $category)';
  }
}

class SentGiftModel {
  final String id;
  final String giftId;
  final GiftModel gift;
  final String senderId;
  final String receiverId;
  final String? conversationId; // Changed from matchId to conversationId for consistency
  final String? messageId;
  final DateTime sentAt;
  final bool isRead;
  final String? message; // Optional message with gift
  final Map<String, dynamic>? metadata;

  SentGiftModel({
    required this.id,
    required this.giftId,
    required this.gift,
    required this.senderId,
    required this.receiverId,
    this.conversationId,
    this.messageId,
    required this.sentAt,
    this.isRead = false,
    this.message,
    this.metadata,
  });

  // Check if gift is from current user
  bool isSentByUser(String currentUserId) {
    return senderId == currentUserId;
  }

  // Get time since gift was sent
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(sentAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  // Convert from Firestore
  factory SentGiftModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SentGiftModel(
      id: doc.id,
      giftId: data['giftId'] ?? '',
      gift: GiftModel.fromJson(data['gift']),
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      conversationId: data['conversationId'] ?? data['matchId'], // Support both field names
      messageId: data['messageId'],
      sentAt: (data['sentAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      message: data['message'],
      metadata: data['metadata'],
    );
  }

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'giftId': giftId,
      'gift': gift.toJson(),
      'senderId': senderId,
      'receiverId': receiverId,
      'conversationId': conversationId,
      'messageId': messageId,
      'sentAt': Timestamp.fromDate(sentAt),
      'isRead': isRead,
      'message': message,
      'metadata': metadata,
    };
  }

  // Convert from JSON
  factory SentGiftModel.fromJson(Map<String, dynamic> json) {
    return SentGiftModel(
      id: json['id'] ?? '',
      giftId: json['giftId'] ?? '',
      gift: GiftModel.fromJson(json['gift']),
      senderId: json['senderId'] ?? '',
      receiverId: json['receiverId'] ?? '',
      conversationId: json['conversationId'] ?? json['matchId'],
      messageId: json['messageId'],
      sentAt: DateTime.parse(json['sentAt']),
      isRead: json['isRead'] ?? false,
      message: json['message'],
      metadata: json['metadata'],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'giftId': giftId,
      'gift': gift.toJson(),
      'senderId': senderId,
      'receiverId': receiverId,
      'conversationId': conversationId,
      'messageId': messageId,
      'sentAt': sentAt.toIso8601String(),
      'isRead': isRead,
      'message': message,
      'metadata': metadata,
    };
  }

  // Create a copy with updated fields
  SentGiftModel copyWith({
    String? id,
    String? giftId,
    GiftModel? gift,
    String? senderId,
    String? receiverId,
    String? conversationId,
    String? messageId,
    DateTime? sentAt,
    bool? isRead,
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    return SentGiftModel(
      id: id ?? this.id,
      giftId: giftId ?? this.giftId,
      gift: gift ?? this.gift,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      conversationId: conversationId ?? this.conversationId,
      messageId: messageId ?? this.messageId,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      message: message ?? this.message,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'SentGiftModel(id: $id, gift: ${gift.name}, from: $senderId, to: $receiverId)';
  }
}