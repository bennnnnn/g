// services/conversation_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/conversation_model.dart';
 

/// Pure conversation data service - handles only Firebase operations and business logic
class ConversationService {
  static final ConversationService _instance = ConversationService._internal();
  factory ConversationService() => _instance;
  ConversationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Get conversations for current user
  Future<ConversationListResult> getUserConversations({
    bool includeArchived = false,
    bool activeOnly = true,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return ConversationListResult.error('No user signed in');
      }

      Query query = _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId);

      if (!includeArchived) {
        query = query.where('isArchived', isEqualTo: false);
      }

      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query
          .orderBy('lastMessageTime', descending: true)
          .limit(limit);

      final querySnapshot = await query.get();
      final conversations = querySnapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .toList();

      return ConversationListResult.success(
        conversations: conversations,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error getting user conversations: $e');
      return ConversationListResult.error('Failed to load conversations');
    }
  }

  /// Get conversation by ID
  Future<ConversationResult> getConversationById(String conversationId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return ConversationResult.error('No user signed in');
      }

      final doc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!doc.exists) {
        return ConversationResult.error('Conversation not found');
      }

      final conversation = ConversationModel.fromFirestore(doc);

      // Verify user is participant
      if (!conversation.participantIds.contains(userId)) {
        return ConversationResult.error('Access denied');
      }

      return ConversationResult.success(conversation);
    } catch (e) {
      debugPrint('Error getting conversation: $e');
      return ConversationResult.error('Failed to load conversation');
    }
  }

  /// Create new conversation
  Future<ConversationResult> createConversation({
    required String otherUserId,
    String? initialMessage,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return ConversationResult.error('No user signed in');
      }

      if (userId == otherUserId) {
        return ConversationResult.error('Cannot create conversation with yourself');
      }

      // Check if conversation already exists
      final existingResult = await findExistingConversation(otherUserId);
      if (existingResult.success && existingResult.conversation != null) {
        return existingResult;
      }

      // Create new conversation
      final now = DateTime.now();
      final conversation = ConversationModel(
        id: '', // Will be set by Firestore
        participantIds: [userId, otherUserId],
        createdAt: now,
        updatedAt: now,
        isActive: true,
        unreadCounts: {userId: 0, otherUserId: 0},
        lastReadAt: {userId: now, otherUserId: null},
        userMessageCounts: {userId: 0, otherUserId: 0},
        isPremiumConversation: false, // Will be updated based on user status
      );

      final docRef = await _firestore
          .collection('conversations')
          .add(conversation.toFirestore());

      final createdConversation = conversation.copyWith(id: docRef.id);

      return ConversationResult.success(createdConversation);
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      return ConversationResult.error('Failed to create conversation');
    }
  }

  /// Find existing conversation between two users
  Future<ConversationResult> findExistingConversation(String otherUserId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return ConversationResult.error('No user signed in');
      }

      final querySnapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in querySnapshot.docs) {
        final conversation = ConversationModel.fromFirestore(doc);
        if (conversation.participantIds.contains(otherUserId)) {
          return ConversationResult.success(conversation);
        }
      }

      return ConversationResult.error('No existing conversation found');
    } catch (e) {
      debugPrint('Error finding existing conversation: $e');
      return ConversationResult.error('Failed to find conversation');
    }
  }

  /// Mark conversation as read
  Future<ConversationResult> markAsRead(String conversationId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return ConversationResult.error('No user signed in');
      }

      final now = DateTime.now();
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'unreadCounts.$userId': 0,
        'lastReadAt.$userId': Timestamp.fromDate(now),
      });

      return getConversationById(conversationId);
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
      return ConversationResult.error('Failed to mark as read');
    }
  }

  /// Update conversation after message
  Future<ConversationResult> updateConversationAfterMessage({
    required String conversationId,
    required dynamic message, // MessageModel
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return ConversationResult.error('No user signed in');
      }

      final now = DateTime.now();
      final updates = <String, dynamic>{
        'lastMessageId': message.id,
        'lastMessageTime': Timestamp.fromDate(message.sentAt),
        'lastMessage': message.content,
        'lastMessageSenderId': message.senderId,
        'lastMessageType': message.type.toString().split('.').last,
        'updatedAt': Timestamp.fromDate(now),
        'totalMessagesCount': FieldValue.increment(1),
        'userMessageCounts.${message.senderId}': FieldValue.increment(1),
      };

      // Update unread count for receiver
      if (message.receiverId != message.senderId) {
        updates['unreadCounts.${message.receiverId}'] = FieldValue.increment(1);
      }

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update(updates);

      return getConversationById(conversationId);
    } catch (e) {
      debugPrint('Error updating conversation after message: $e');
      return ConversationResult.error('Failed to update conversation');
    }
  }

  /// Update typing status
  Future<void> updateTypingStatus({
    required String conversationId,
    required bool isTyping,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'isTyping.$userId': isTyping,
      });
    } catch (e) {
      debugPrint('Error updating typing status: $e');
    }
  }

  /// Archive conversation
  Future<ConversationResult> archiveConversation(String conversationId) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'isArchived': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return ConversationResult.success(null);
    } catch (e) {
      debugPrint('Error archiving conversation: $e');
      return ConversationResult.error('Failed to archive conversation');
    }
  }

  /// Delete conversation
  Future<ConversationResult> deleteConversation(String conversationId) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return ConversationResult.success(null);
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      return ConversationResult.error('Failed to delete conversation');
    }
  }

  /// Block user and end conversation
  Future<ConversationResult> blockUserAndEndConversation({
    required String conversationId,
    required String userIdToBlock,
  }) async {
    try {
      // End conversation
      await deleteConversation(conversationId);

      return ConversationResult.success(null);
    } catch (e) {
      debugPrint('Error blocking user and ending conversation: $e');
      return ConversationResult.error('Failed to block user');
    }
  }

  /// Search conversations
  Future<ConversationListResult> searchConversations({
    required String query,
    int limit = 20,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return ConversationListResult.error('No user signed in');
      }

      if (query.trim().isEmpty) {
        return ConversationListResult.error('Search query cannot be empty');
      }

      // Get all user conversations first (Firestore doesn't support full-text search)
      final allConversationsResult = await getUserConversations(limit: 100);
      if (!allConversationsResult.success) {
        return allConversationsResult;
      }

      // Filter conversations based on last message content
      final searchTerm = query.toLowerCase();
      final filteredConversations = allConversationsResult.conversations
          .where((conversation) =>
              conversation.lastMessage?.toLowerCase().contains(searchTerm) == true)
          .take(limit)
          .toList();

      return ConversationListResult.success(
        conversations: filteredConversations,
        hasMore: false,
      );
    } catch (e) {
      debugPrint('Error searching conversations: $e');
      return ConversationListResult.error('Failed to search conversations');
    }
  }

  /// Get unread conversations
  Future<ConversationListResult> getUnreadConversations() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return ConversationListResult.error('No user signed in');
      }

      final querySnapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .where('unreadCounts.$userId', isGreaterThan: 0)
          .orderBy('lastMessageTime', descending: true)
          .get();

      final conversations = querySnapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .toList();

      return ConversationListResult.success(conversations: conversations);
    } catch (e) {
      debugPrint('Error getting unread conversations: $e');
      return ConversationListResult.error('Failed to get unread conversations');
    }
  }

  /// Get total unread count
  Future<int> getTotalUnreadCount() async {
    try {
      final userId = currentUserId;
      if (userId == null) return 0;

      final unreadResult = await getUnreadConversations();
      if (!unreadResult.success) return 0;

      return unreadResult.conversations
          .map((c) => c.getUnreadCount(userId))
          .fold(0, (sum, count) => sum + count);
    } catch (e) {
      debugPrint('Error getting total unread count: $e');
      return 0;
    }
  }

  /// Stream user conversations (for real-time updates)
  Stream<List<ConversationModel>> streamUserConversations({
    bool includeArchived = false,
  }) {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    Query query = _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: userId);

    if (!includeArchived) {
      query = query.where('isArchived', isEqualTo: false);
    }

    return query
        .where('isActive', isEqualTo: true)
        .orderBy('lastMessageTime', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ConversationModel.fromFirestore(doc))
            .toList());
  }

  /// Stream single conversation (for real-time updates)
  Stream<ConversationModel?> streamConversation(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map((doc) => doc.exists ? ConversationModel.fromFirestore(doc) : null);
  }

  /// Get conversation statistics
  Future<ConversationStatsResult> getConversationStats(String conversationId) async {
    try {
      final conversationResult = await getConversationById(conversationId);
      if (!conversationResult.success || conversationResult.conversation == null) {
        return ConversationStatsResult.error('Conversation not found');
      }

      final conversation = conversationResult.conversation!;
      
      final stats = ConversationStats(
        totalMessages: conversation.totalMessagesCount,
        totalGifts: conversation.totalGiftsSent,
        totalGiftValue: conversation.totalGiftValue,
        lastMessageTime: conversation.lastMessageTime,
        participantCount: conversation.participantIds.length,
        isActive: conversation.isActive,
        isPremium: conversation.isPremiumConversation,
      );

      return ConversationStatsResult.success(stats);
    } catch (e) {
      debugPrint('Error getting conversation stats: $e');
      return ConversationStatsResult.error('Failed to get statistics');
    }
  }
}

extension on FutureOr<int> {
  FutureOr<int> operator +(int other) {
    if (this is int) {
      return (this as int)  + other;
    } else {
         throw Exception('Cannot add int to non-int value');
    
    }

  }
}

/// Conversation operation result
class ConversationResult {
  final bool success;
  final ConversationModel? conversation;
  final String? error;

  const ConversationResult._({
    required this.success,
    this.conversation,
    this.error,
  });

  factory ConversationResult.success(ConversationModel? conversation) {
    return ConversationResult._(success: true, conversation: conversation);
  }

  factory ConversationResult.error(String error) {
    return ConversationResult._(success: false, error: error);
  }
}

/// Conversation list result
class ConversationListResult {
  final bool success;
  final List<ConversationModel> conversations;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? error;

  const ConversationListResult._({
    required this.success,
    this.conversations = const [],
    this.lastDocument,
    this.hasMore = false,
    this.error,
  });

  factory ConversationListResult.success({
    required List<ConversationModel> conversations,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
  }) {
    return ConversationListResult._(
      success: true,
      conversations: conversations,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  factory ConversationListResult.error(String error) {
    return ConversationListResult._(success: false, error: error);
  }
}

/// Conversation statistics
class ConversationStats {
  final int totalMessages;
  final int totalGifts;
  final double totalGiftValue;
  final DateTime? lastMessageTime;
  final int participantCount;
  final bool isActive;
  final bool isPremium;

  ConversationStats({
    required this.totalMessages,
    required this.totalGifts,
    required this.totalGiftValue,
    this.lastMessageTime,
    required this.participantCount,
    required this.isActive,
    required this.isPremium,
  });
}

/// Conversation statistics result
class ConversationStatsResult {
  final bool success;
  final ConversationStats? stats;
  final String? error;

  const ConversationStatsResult._({
    required this.success,
    this.stats,
    this.error,
  });

  factory ConversationStatsResult.success(ConversationStats stats) {
    return ConversationStatsResult._(success: true, stats: stats);
  }

  factory ConversationStatsResult.error(String error) {
    return ConversationStatsResult._(success: false, error: error);
  }
}