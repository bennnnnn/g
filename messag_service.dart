import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/message_model.dart';
import '../../models/enums.dart';
import 'user_service.dart';
import 'conversation_service.dart';
import 'validation_service.dart';
import 'media_service.dart';
import 'cache_service.dart';

class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final ConversationService _conversationService = ConversationService();
  final ValidationService _validationService = ValidationService();
  final MediaService _mediaService = MediaService();
  final CacheService _cacheService = CacheService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Send text message (with business rule enforcement)
  Future<MessageResult> sendMessage({
    required String conversationId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
    String? replyToMessageId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return MessageResult.error('No user signed in');
      }

      if (userId == receiverId) {
        return MessageResult.error('Cannot send message to yourself');
      }

      // Validate message content
      final contentValidation = _validationService.validateMessage(content);
      if (!contentValidation.isValid) {
        return MessageResult.error(contentValidation.error!);
      }

      // Get current user data
      final userResult = await _userService.getCurrentUser();
      if (!userResult.success || userResult.user == null) {
        return MessageResult.error('Failed to get user data');
      }

      final user = userResult.user!;

      // Get conversation to check premium status
      final conversationResult = await _conversationService.getConversationById(conversationId);
      if (!conversationResult.success || conversationResult.conversation == null) {
        return MessageResult.error('Conversation not found');
      }

      final conversation = conversationResult.conversation!;

      // BUSINESS RULE: Check message limits for free users
      final canSend = user.canMessageUser(receiverId, isConversationPremium: conversation.isPremiumConversation);
      if (!canSend) {
        // Get specific limit info for better error message
        final remaining = user.getRemainingMessagesForUser(receiverId);
        if (remaining <= 0) {
          return MessageResult.error(
            'You\'ve reached your message limit with this user (3 messages). Upgrade to premium for unlimited messaging.'
          );
        } else {
          final newUsersLeft = user.getRemainingNewUsersToday();
          if (newUsersLeft <= 0) {
            return MessageResult.error(
              'You\'ve reached your daily limit (2 new users). Upgrade to premium for unlimited messaging.'
            );
          }
        }
      }

      // Get receiver data for validation
      final receiverResult = await _userService.getUserById(receiverId);
      if (!receiverResult.success || receiverResult.user == null) {
        return MessageResult.error('Recipient not found');
      }

      final receiver = receiverResult.user!;

      // Check if receiver can receive messages
      if (!receiver.canReceiveMessages) {
        return MessageResult.error('This user is not available for messaging');
      }

      // Check if users have blocked each other
      if (user.blockedUsers.contains(receiverId) || receiver.blockedUsers.contains(userId)) {
        return MessageResult.error('Cannot send message to this user');
      }

      // Create message
      final now = DateTime.now();
      final message = MessageModel(
        id: '', // Will be set by Firestore
        conversationId: conversationId,
        senderId: userId,
        receiverId: receiverId,
        content: content.trim(),
        type: type,
        sentAt: now,
        status: MessageStatus.sending,
        metadata: metadata,
        replyToMessageId: replyToMessageId,
      );

      // Save message to Firestore
      final docRef = await _firestore.collection('messages').add(message.toFirestore());
      final savedMessage = message.copyWith(
        id: docRef.id,
        status: MessageStatus.sent,
      );

      // Update message status
      await _firestore.collection('messages').doc(docRef.id).update({
        'status': MessageStatus.sent.toString().split('.').last,
      });

      // Update conversation after message
      await _conversationService.updateConversationAfterMessage(
        conversationId: conversationId,
        message: savedMessage,
      );

      // Update user's message count (for business rules)
      await _userService.updateMessageCount(receiverId);

      // Clear message cache for this conversation
      await _cacheService.removeCachedMessages(conversationId);

      debugPrint('Message sent: ${docRef.id}, conversation: $conversationId');
      return MessageResult.success(savedMessage);
    } catch (e) {
      debugPrint('Error sending message: $e');
      return MessageResult.error('Failed to send message');
    }
  }

  /// Send image message
  Future<MessageResult> sendImageMessage({
    required String conversationId,
    required String receiverId,
    required File imageFile,
    String? caption,
    String? replyToMessageId,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return MessageResult.error('No user signed in');
      }

      // Validate image file
      final validation = _mediaService.validateImageFile(imageFile);
      if (!validation.isValid) {
        return MessageResult.error(validation.error!);
      }

      // Check message limits first (same as text message)
      final userResult = await _userService.getCurrentUser();
      if (!userResult.success || userResult.user == null) {
        return MessageResult.error('Failed to get user data');
      }

      final user = userResult.user!;
      final conversationResult = await _conversationService.getConversationById(conversationId);
      if (!conversationResult.success || conversationResult.conversation == null) {
        return MessageResult.error('Conversation not found');
      }

      final conversation = conversationResult.conversation!;
      final canSend = user.canMessageUser(receiverId, isConversationPremium: conversation.isPremiumConversation);
      if (!canSend) {
        return MessageResult.error('Message limit reached. Upgrade for unlimited messaging.');
      }

      // Upload image
      final uploadResult = await _mediaService.uploadImage(
        imageFile: imageFile,
        userId: userId,
        folder: 'messages',
        fileName: 'message_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!uploadResult.success) {
        return MessageResult.error('Failed to upload image: ${uploadResult.error}');
      }

      // Send message with image URL
      final messageResult = await sendMessage(
        conversationId: conversationId,
        receiverId: receiverId,
        content: caption ?? '📷 Photo',
        type: MessageType.image,
        replyToMessageId: replyToMessageId,
        metadata: {
          'mediaUrl': uploadResult.downloadUrl,
          'thumbnailUrl': uploadResult.thumbnailUrl,
          'fileName': uploadResult.fileName,
          'fileSize': uploadResult.fileSize,
          'originalCaption': caption,
        },
      );

      debugPrint('Image message sent: ${uploadResult.downloadUrl}');
      return messageResult;
    } catch (e) {
      debugPrint('Error sending image message: $e');
      return MessageResult.error('Failed to send image');
    }
  }

  /// Get messages for conversation (with caching)
  Future<MessagesResult> getMessages({
    required String conversationId,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return MessagesResult.error('No user signed in');
      }

      // Verify user is participant in conversation
      final conversationResult = await _conversationService.getConversationById(conversationId);
      if (!conversationResult.success || conversationResult.conversation == null) {
        return MessagesResult.error('Conversation not found');
      }

      final conversation = conversationResult.conversation!;
      if (!conversation.participantIds.contains(userId)) {
        return MessagesResult.error('Access denied');
      }

      // Try cache first (only for first page)
      if (lastDocument == null) {
        final cachedMessages = _cacheService.getCachedMessages(conversationId);
        if (cachedMessages != null && cachedMessages.isNotEmpty) {
          debugPrint('Messages loaded from cache: ${cachedMessages.length}');
          return MessagesResult.success(
            messages: cachedMessages.take(limit).toList(),
            hasMore: cachedMessages.length > limit,
          );
        }
      }

      // Get from Firestore
      Query query = _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('sentAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      final messages = querySnapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();

      // Cache messages (only first page)
      if (lastDocument == null && messages.isNotEmpty) {
        await _cacheService.cacheMessages(conversationId, messages);
      }

      debugPrint('Messages loaded from Firestore: ${messages.length}');
      return MessagesResult.success(
        messages: messages,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return MessagesResult.error('Failed to load messages');
    }
  }

  /// Mark message as read
  Future<MessageResult> markMessageAsRead(String messageId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return MessageResult.error('No user signed in');
      }

      // Get message first
      final messageResult = await getMessageById(messageId);
      if (!messageResult.success || messageResult.message == null) {
        return MessageResult.error('Message not found');
      }

      final message = messageResult.message!;

      // Only receiver can mark as read
      if (message.receiverId != userId) {
        return MessageResult.error('Cannot mark this message as read');
      }

      // Don't mark already read messages
      if (message.isRead) {
        return MessageResult.success(message);
      }

      final now = DateTime.now();
      final updatedMessage = message.copyWith(
        isRead: true,
        readAt: now,
        status: MessageStatus.read,
      );

      await _firestore.collection('messages').doc(messageId).update({
        'isRead': true,
        'readAt': Timestamp.fromDate(now),
        'status': MessageStatus.read.toString().split('.').last,
      });

      // Clear message cache
      await _cacheService.removeCachedMessages(message.conversationId);

      debugPrint('Message marked as read: $messageId');
      return MessageResult.success(updatedMessage);
    } catch (e) {
      debugPrint('Error marking message as read: $e');
      return MessageResult.error('Failed to mark message as read');
    }
  }

  /// Mark all messages in conversation as read
  Future<void> markConversationMessagesAsRead(String conversationId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      // Get unread messages for current user
      final unreadMessages = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isEmpty) return;

      final batch = _firestore.batch();
      final now = Timestamp.fromDate(DateTime.now());

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': now,
          'status': MessageStatus.read.toString().split('.').last,
        });
      }

      await batch.commit();

      // Mark conversation as read
      await _conversationService.markAsRead(conversationId);

      // Clear cache
      await _cacheService.removeCachedMessages(conversationId);

      debugPrint('Conversation messages marked as read: $conversationId');
    } catch (e) {
      debugPrint('Error marking conversation messages as read: $e');
    }
  }

  /// Delete message (soft delete)
  Future<MessageResult> deleteMessage({
    required String messageId,
    bool deleteForEveryone = false,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return MessageResult.error('No user signed in');
      }

      // Get message
      final messageResult = await getMessageById(messageId);
      if (!messageResult.success || messageResult.message == null) {
        return MessageResult.error('Message not found');
      }

      final message = messageResult.message!;

      // Check permissions
      if (message.senderId != userId) {
        return MessageResult.error('You can only delete your own messages');
      }

      // Check time limit for delete for everyone (15 minutes)
      if (deleteForEveryone) {
        final timeDiff = DateTime.now().difference(message.sentAt);
        if (timeDiff.inMinutes > 15) {
          return MessageResult.error('Can only delete for everyone within 15 minutes');
        }
      }

      // Soft delete message
      final deletedMessage = message.copyWith(
        content: deleteForEveryone ? 'This message was deleted' : message.content,
        status: MessageStatus.failed, // Use failed to indicate deleted
        metadata: {
          ...?message.metadata,
          'isDeleted': true,
          'deletedAt': DateTime.now().toIso8601String(),
          'deletedBy': userId,
          'deleteForEveryone': deleteForEveryone,
        },
      );

      await _firestore.collection('messages').doc(messageId).update({
        if (deleteForEveryone) 'content': 'This message was deleted',
        'status': MessageStatus.failed.toString().split('.').last,
        'metadata': deletedMessage.metadata,
      });

      // Clear cache
      await _cacheService.removeCachedMessages(message.conversationId);

      debugPrint('Message deleted: $messageId, for everyone: $deleteForEveryone');
      return MessageResult.success(deletedMessage);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return MessageResult.error('Failed to delete message');
    }
  }

  /// Get message by ID
  Future<MessageResult> getMessageById(String messageId) async {
    try {
      final doc = await _firestore.collection('messages').doc(messageId).get();
      
      if (!doc.exists) {
        return MessageResult.error('Message not found');
      }

      final message = MessageModel.fromFirestore(doc);
      
      // Check if current user has access to this message
      final userId = currentUserId;
      if (userId == null || 
          (message.senderId != userId && message.receiverId != userId)) {
        return MessageResult.error('Access denied');
      }

      return MessageResult.success(message);
    } catch (e) {
      debugPrint('Error getting message: $e');
      return MessageResult.error('Failed to get message');
    }
  }

  /// Search messages in conversation
  Future<MessagesResult> searchMessages({
    required String conversationId,
    required String query,
    int limit = 20,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return MessagesResult.error('No user signed in');
      }

      if (query.trim().isEmpty) {
        return MessagesResult.error('Search query cannot be empty');
      }

      // Verify access to conversation
      final conversationResult = await _conversationService.getConversationById(conversationId);
      if (!conversationResult.success || conversationResult.conversation == null) {
        return MessagesResult.error('Conversation not found');
      }

      final conversation = conversationResult.conversation!;
      if (!conversation.participantIds.contains(userId)) {
        return MessagesResult.error('Access denied');
      }

      // Firestore doesn't support full-text search on content field directly
      // This is a simplified implementation - in production, use Algolia or similar
      
      // Get all messages and filter client-side (not ideal for large datasets)
      final allMessagesResult = await getMessages(
        conversationId: conversationId,
        limit: 200, // Reasonable limit for search
      );

      if (!allMessagesResult.success) {
        return allMessagesResult;
      }

      final filteredMessages = allMessagesResult.messages
          .where((message) => 
              message.content.toLowerCase().contains(query.toLowerCase()) &&
              message.type == MessageType.text)
          .take(limit)
          .toList();

      debugPrint('Message search completed: ${filteredMessages.length} results');
      return MessagesResult.success(messages: filteredMessages);
    } catch (e) {
      debugPrint('Error searching messages: $e');
      return MessagesResult.error('Failed to search messages');
    }
  }

  /// Get unread message count for user
  Future<int> getUnreadMessageCount([String? conversationId]) async {
    try {
      final userId = currentUserId;
      if (userId == null) return 0;

      Query query = _firestore
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false);

      if (conversationId != null) {
        query = query.where('conversationId', isEqualTo: conversationId);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting unread message count: $e');
      return 0;
    }
  }

  /// Send typing indicator
  Future<void> sendTypingIndicator({
    required String conversationId,
    required bool isTyping,
  }) async {
    try {
      await _conversationService.updateTypingStatus(
        conversationId: conversationId,
        isTyping: isTyping,
      );
    } catch (e) {
      debugPrint('Error sending typing indicator: $e');
    }
  }

  /// Get message statistics for conversation
  Future<MessageStatsResult> getMessageStats(String conversationId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return MessageStatsResult.error('No user signed in');
      }

      // Verify access
      final conversationResult = await _conversationService.getConversationById(conversationId);
      if (!conversationResult.success || conversationResult.conversation == null) {
        return MessageStatsResult.error('Conversation not found');
      }

      final conversation = conversationResult.conversation!;
      if (!conversation.participantIds.contains(userId)) {
        return MessageStatsResult.error('Access denied');
      }

      // Get message statistics
      final totalMessages = conversation.totalMessagesCount;
      final userSentMessages = conversation.userMessageCounts[userId] ?? 0;
      final unreadCount = await getUnreadMessageCount(conversationId);
      
      // Calculate other user's message count
      final otherUserId = conversation.getOtherParticipantId(userId);
      final otherUserMessages = conversation.userMessageCounts[otherUserId] ?? 0;

      final stats = MessageStats(
        totalMessages: totalMessages,
        messagesSentByUser: userSentMessages,
        messagesReceivedByUser: otherUserMessages,
        unreadMessages: unreadCount,
        averageResponseTime: Duration.zero, // Would need more complex calculation
        lastMessageTime: conversation.lastMessageTime,
      );

      return MessageStatsResult.success(stats);
    } catch (e) {
      debugPrint('Error getting message stats: $e');
      return MessageStatsResult.error('Failed to get message statistics');
    }
  }

  /// Stream messages for real-time updates
  Stream<List<MessageModel>> streamMessages({
    required String conversationId,
    int limit = 50,
  }) {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }

  /// Stream unread message count
  Stream<int> streamUnreadMessageCount([String? conversationId]) {
    final userId = currentUserId;
    if (userId == null) return Stream.value(0);

    Query query = _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false);

    if (conversationId != null) {
      query = query.where('conversationId', isEqualTo: conversationId);
    }

    return query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  /// Clear message cache
  Future<void> clearMessageCache([String? conversationId]) async {
    try {
      if (conversationId != null) {
        await _cacheService.removeCachedMessages(conversationId);
      } else {
        // Clear all message caches (you'd need to implement this in CacheService)
        debugPrint('Clearing all message caches');
      }
    } catch (e) {
      debugPrint('Error clearing message cache: $e');
    }
  }

  /// Dispose service
  void dispose() {
    // Clean up any resources if needed
    debugPrint('MessageService disposed');
  }
}

/// Message operation result
class MessageResult {
  final bool success;
  final MessageModel? message;
  final String? error;

  const MessageResult._({
    required this.success,
    this.message,
    this.error,
  });

  factory MessageResult.success(MessageModel message) {
    return MessageResult._(success: true, message: message);
  }

  factory MessageResult.error(String error) {
    return MessageResult._(success: false, error: error);
  }
}

/// Messages list result
class MessagesResult {
  final bool success;
  final List<MessageModel> messages;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? error;

  const MessagesResult._({
    required this.success,
    this.messages = const [],
    this.lastDocument,
    this.hasMore = false,
    this.error,
  });

  factory MessagesResult.success({
    required List<MessageModel> messages,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
  }) {
    return MessagesResult._(
      success: true,
      messages: messages,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  factory MessagesResult.error(String error) {
    return MessagesResult._(success: false, error: error);
  }
}

/// Message statistics
class MessageStats {
  final int totalMessages;
  final int messagesSentByUser;
  final int messagesReceivedByUser;
  final int unreadMessages;
  final Duration averageResponseTime;
  final DateTime? lastMessageTime;

  MessageStats({
    required this.totalMessages,
    required this.messagesSentByUser,
    required this.messagesReceivedByUser,
    required this.unreadMessages,
    required this.averageResponseTime,
    this.lastMessageTime,
  });

  double get responseRate {
    if (messagesReceivedByUser == 0) return 0.0;
    return messagesSentByUser / messagesReceivedByUser;
  }

  String get formattedResponseTime {
    if (averageResponseTime.inMinutes < 60) {
      return '${averageResponseTime.inMinutes}m';
    } else if (averageResponseTime.inHours < 24) {
      return '${averageResponseTime.inHours}h';
    } else {
      return '${averageResponseTime.inDays}d';
    }
  }
}

/// Message statistics result
class MessageStatsResult {
  final bool success;
  final MessageStats? stats;
  final String? error;

  const MessageStatsResult._({
    required this.success,
    this.stats,
    this.error,
  });

  factory MessageStatsResult.success(MessageStats stats) {
    return MessageStatsResult._(success: true, stats: stats);
  }

  factory MessageStatsResult.error(String error) {
    return MessageStatsResult._(success: false, error: error);
  }
}