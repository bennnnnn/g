import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class ConversationModel {
  final String id;
  final List<String> participantIds;
  final String? lastMessageId;
  final DateTime? lastMessageTime;
  final String? lastMessage;
  final String? lastMessageSenderId;    // Who sent the last message
  final MessageType? lastMessageType;   // Type of last message (text, gift, etc.)
  final Map<String, int> unreadCounts;  // per user
  final Map<String, DateTime?> lastReadAt; // When each user last read
  final DateTime createdAt;
  final DateTime updatedAt;             // When conversation was last updated
  final bool isActive;
  final bool isArchived;                // If conversation is archived
  final Map<String, bool> isTyping;     // Typing indicators per user
  final Map<String, dynamic>? metadata; // Additional conversation data
  
  // BUSINESS LOGIC FIELDS
  final int totalMessagesCount;         // Total messages in conversation
  final Map<String, int> userMessageCounts; // Messages sent by each user
  final bool isPremiumConversation;     // If ANY participant is premium (enables unlimited for all)
  final DateTime? lastGiftSentAt;       // When last gift was sent
  final int totalGiftsSent;             // Total gifts exchanged
  final double totalGiftValue;          // Total value of gifts

  ConversationModel({
    required this.id,
    required this.participantIds,
    this.lastMessageId,
    this.lastMessageTime,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageType,
    this.unreadCounts = const {},
    this.lastReadAt = const {},
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.isArchived = false,
    this.isTyping = const {},
    this.metadata,
    this.totalMessagesCount = 0,
    this.userMessageCounts = const {},
    this.isPremiumConversation = false,
    this.lastGiftSentAt,
    this.totalGiftsSent = 0,
    this.totalGiftValue = 0.0,
  });

  // HELPER METHODS

  // Get the other participant's ID (for 1-on-1 conversations)
  String? getOtherParticipantId(String currentUserId) {
    return participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  // Check if user has unread messages
  bool hasUnreadMessages(String userId) {
    return (unreadCounts[userId] ?? 0) > 0;
  }

  // Get total unread count for user
  int getUnreadCount(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  // Check if someone is typing
  bool get isSomeoneTyping {
    return isTyping.values.any((typing) => typing);
  }

  // Check if specific user is typing
  bool isUserTyping(String userId) {
    return isTyping[userId] ?? false;
  }

  // Get conversation display name (for UI)
  String getDisplayName(Map<String, String> userNames, String currentUserId) {
    final otherUserId = getOtherParticipantId(currentUserId);
    return userNames[otherUserId] ?? 'Unknown User';
  }

  // Check if user can send unlimited messages in this conversation
  bool canUserSendUnlimited(String userId, bool userIsPremium) {
    return userIsPremium || isPremiumConversation;
  }

  // Check if this conversation allows unlimited messaging for anyone
  bool get allowsUnlimitedMessaging {
    return isPremiumConversation;
  }

  // Check if conversation needs attention (has unread messages or recent activity)
  bool needsAttention(String userId) {
    return hasUnreadMessages(userId) || 
           (lastMessageTime != null && 
            DateTime.now().difference(lastMessageTime!).inHours < 24);
  }

  // Get last activity description for UI
  String getLastActivityDescription() {
    if (lastMessageTime == null) return 'No messages yet';
    
    final difference = DateTime.now().difference(lastMessageTime!);
    
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

  // Update premium status when a premium user joins conversation
  ConversationModel updatePremiumStatus(bool hasPremiumParticipant) {
    return copyWith(isPremiumConversation: hasPremiumParticipant);
  }

  // Convert from Firestore
  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ConversationModel(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      lastMessageId: data['lastMessageId'],
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : null,
      lastMessage: data['lastMessage'],
      lastMessageSenderId: data['lastMessageSenderId'],
      lastMessageType: data['lastMessageType'] != null
          ? MessageType.values.firstWhere(
              (e) => e.toString() == 'MessageType.${data['lastMessageType']}',
              orElse: () => MessageType.text,
            )
          : null,
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      lastReadAt: (data['lastReadAt'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, value != null ? (value as Timestamp).toDate() : null),
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? 
                 (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      isArchived: data['isArchived'] ?? false,
      isTyping: Map<String, bool>.from(data['isTyping'] ?? {}),
      metadata: data['metadata'],
      totalMessagesCount: data['totalMessagesCount'] ?? 0,
      userMessageCounts: Map<String, int>.from(data['userMessageCounts'] ?? {}),
      isPremiumConversation: data['isPremiumConversation'] ?? false,
      lastGiftSentAt: data['lastGiftSentAt'] != null
          ? (data['lastGiftSentAt'] as Timestamp).toDate()
          : null,
      totalGiftsSent: data['totalGiftsSent'] ?? 0,
      totalGiftValue: (data['totalGiftValue'] ?? 0.0).toDouble(),
    );
  }

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'participantIds': participantIds,
      'lastMessageId': lastMessageId,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageType': lastMessageType?.toString().split('.').last,
      'unreadCounts': unreadCounts,
      'lastReadAt': lastReadAt.map(
        (key, value) => MapEntry(key, value != null ? Timestamp.fromDate(value) : null),
      ),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'isArchived': isArchived,
      'isTyping': isTyping,
      'metadata': metadata,
      'totalMessagesCount': totalMessagesCount,
      'userMessageCounts': userMessageCounts,
      'isPremiumConversation': isPremiumConversation,
      'lastGiftSentAt': lastGiftSentAt != null
          ? Timestamp.fromDate(lastGiftSentAt!)
          : null,
      'totalGiftsSent': totalGiftsSent,
      'totalGiftValue': totalGiftValue,
    };
  }

  // Create a copy with updated fields
  ConversationModel copyWith({
    String? id,
    List<String>? participantIds,
    String? lastMessageId,
    DateTime? lastMessageTime,
    String? lastMessage,
    String? lastMessageSenderId,
    MessageType? lastMessageType,
    Map<String, int>? unreadCounts,
    Map<String, DateTime?>? lastReadAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? isArchived,
    Map<String, bool>? isTyping,
    Map<String, dynamic>? metadata,
    int? totalMessagesCount,
    Map<String, int>? userMessageCounts,
    bool? isPremiumConversation,
    DateTime? lastGiftSentAt,
    int? totalGiftsSent,
    double? totalGiftValue,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      isTyping: isTyping ?? this.isTyping,
      metadata: metadata ?? this.metadata,
      totalMessagesCount: totalMessagesCount ?? this.totalMessagesCount,
      userMessageCounts: userMessageCounts ?? this.userMessageCounts,
      isPremiumConversation: isPremiumConversation ?? this.isPremiumConversation,
      lastGiftSentAt: lastGiftSentAt ?? this.lastGiftSentAt,
      totalGiftsSent: totalGiftsSent ?? this.totalGiftsSent,
      totalGiftValue: totalGiftValue ?? this.totalGiftValue,
    );
  }

  @override
  String toString() {
    return 'ConversationModel(id: $id, participants: $participantIds, messages: $totalMessagesCount)';
  }
}