import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class MessageModel {
  final String id;
  final String conversationId;  // Changed from matchId to conversationId for consistency
  final String senderId;
  final String receiverId;
  final String content;
  final MessageType type;
  final DateTime sentAt;
  final DateTime? readAt;
  final bool isRead;
  final bool isDelivered;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final Map<String, dynamic>? metadata;
  final String? replyToMessageId;
  final MessageStatus status;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.type = MessageType.text,
    required this.sentAt,
    this.readAt,
    this.isRead = false,
    this.isDelivered = false,
    this.mediaUrl,
    this.thumbnailUrl,
    this.metadata,
    this.replyToMessageId,
    this.status = MessageStatus.sent,
  });

  // Check if message is sent by current user
  bool isSentByUser(String currentUserId) {
    return senderId == currentUserId;
  }

  // Get time since message was sent
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(sentAt);

    if (difference.inMinutes < 1) {
      return 'now';
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

  // Get formatted time for display
  String getFormattedTime() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(sentAt.year, sentAt.month, sentAt.day);
    
    if (messageDate == today) {
      // Today: show time only
      return '${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}';
    } else if (today.difference(messageDate).inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (today.difference(messageDate).inDays < 7) {
      // This week: show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[sentAt.weekday - 1];
    } else {
      // Older: show date
      return '${sentAt.day}/${sentAt.month}/${sentAt.year}';
    }
  }

  // Check if message needs delivery confirmation
  bool get needsDeliveryConfirmation {
    return status == MessageStatus.sent && !isDelivered;
  }

  // Check if message is successfully sent
  bool get isSuccessfullySent {
    return status.isSuccessful;
  }

  // Convert from Firestore
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MessageModel(
      id: doc.id,
      conversationId: data['conversationId'] ?? data['matchId'] ?? '', // Support both field names
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${data['type']}',
        orElse: () => MessageType.text,
      ),
      sentAt: (data['sentAt'] as Timestamp).toDate(),
      readAt: data['readAt'] != null ? (data['readAt'] as Timestamp).toDate() : null,
      isRead: data['isRead'] ?? false,
      isDelivered: data['isDelivered'] ?? false,
      mediaUrl: data['mediaUrl'],
      thumbnailUrl: data['thumbnailUrl'],
      metadata: data['metadata'],
      replyToMessageId: data['replyToMessageId'],
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${data['status']}',
        orElse: () => MessageStatus.sent,
      ),
    );
  }

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type.toString().split('.').last,
      'sentAt': Timestamp.fromDate(sentAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'isRead': isRead,
      'isDelivered': isDelivered,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'metadata': metadata,
      'replyToMessageId': replyToMessageId,
      'status': status.toString().split('.').last,
    };
  }

  // Convert from JSON (for local storage or API)
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? json['matchId'] ?? '',
      senderId: json['senderId'] ?? '',
      receiverId: json['receiverId'] ?? '',
      content: json['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${json['type']}',
        orElse: () => MessageType.text,
      ),
      sentAt: DateTime.parse(json['sentAt']),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      isRead: json['isRead'] ?? false,
      isDelivered: json['isDelivered'] ?? false,
      mediaUrl: json['mediaUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      metadata: json['metadata'],
      replyToMessageId: json['replyToMessageId'],
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${json['status']}',
        orElse: () => MessageStatus.sent,
      ),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type.toString().split('.').last,
      'sentAt': sentAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'isRead': isRead,
      'isDelivered': isDelivered,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'metadata': metadata,
      'replyToMessageId': replyToMessageId,
      'status': status.toString().split('.').last,
    };
  }

  // Create a copy with updated fields
  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? type,
    DateTime? sentAt,
    DateTime? readAt,
    bool? isRead,
    bool? isDelivered,
    String? mediaUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
    String? replyToMessageId,
    MessageStatus? status,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, content: $content, type: $type, sentAt: $sentAt)';
  }
}