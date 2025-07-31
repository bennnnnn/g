// providers/message_provider.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/enums.dart';
import '../services/messag_service.dart';

class MessageProvider extends ChangeNotifier {
  final MessageService _messageService = MessageService();
  
  // Message state for current conversation
  String? _currentConversationId;
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  String? _error;
  DocumentSnapshot? _lastDocument;
  
  // Message sending state
  bool _isSendingMessage = false;
  bool _isSendingImage = false;
  final Map<String, double> _uploadProgress = {};
  final Map<String, String?> _uploadErrors = {};
  
  // Message interaction state
  final Set<String> _selectedMessages = {};
  bool _isSelectionMode = false;
  MessageModel? _replyToMessage;
  
  // Search state
  List<MessageModel> _searchResults = [];
  bool _isSearching = false;
  String _currentSearchQuery = '';
  
  // Real-time state
  StreamSubscription<List<MessageModel>>? _messageStreamSubscription;
  StreamSubscription<int>? _unreadCountStreamSubscription;
  
  // Typing state
  bool _isTyping = false;
  Timer? _typingTimer;
  
  // Current user context
  UserModel? _currentUser;
  
  // Unread count
  int _unreadCount = 0;

  // Getters
  String? get currentConversationId => _currentConversationId;
  List<MessageModel> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreMessages => _hasMoreMessages;
  String? get error => _error;
  
  bool get isSendingMessage => _isSendingMessage;
  bool get isSendingImage => _isSendingImage;
  Map<String, double> get uploadProgress => Map.unmodifiable(_uploadProgress);
  Map<String, String?> get uploadErrors => Map.unmodifiable(_uploadErrors);
  
  Set<String> get selectedMessages => Set.unmodifiable(_selectedMessages);
  bool get isSelectionMode => _isSelectionMode;
  bool get hasSelectedMessages => _selectedMessages.isNotEmpty;
  MessageModel? get replyToMessage => _replyToMessage;
  
  List<MessageModel> get searchResults => List.unmodifiable(_searchResults);
  bool get isSearching => _isSearching;
  String get currentSearchQuery => _currentSearchQuery;
  bool get hasSearchResults => _searchResults.isNotEmpty;
  
  bool get isTyping => _isTyping;
  UserModel? get currentUser => _currentUser;
  int get unreadCount => _unreadCount;
  bool get hasMessages => _messages.isNotEmpty;

  /// Initialize for conversation
  Future<void> initializeForConversation({
    required String conversationId,
    UserModel? currentUser,
  }) async {
    // Clean up previous conversation
    if (_currentConversationId != conversationId) {
      await _cleanup();
    }
    
    _currentConversationId = conversationId;
    _currentUser = currentUser;
    
    // Load messages
    await loadMessages(refresh: true);
    
    // Start real-time updates
    _startRealTimeUpdates();
    
    // Mark messages as read
    await _markConversationAsRead();
  }

  /// Load messages for current conversation
  Future<void> loadMessages({bool refresh = false}) async {
    if (_currentConversationId == null) return;
    
    if (refresh) {
      _messages.clear();
      _lastDocument = null;
      _hasMoreMessages = true;
    }

    _isLoading = refresh;
    _isLoadingMore = !refresh;
    _error = null;
    notifyListeners();

    try {
      final result = await _messageService.getMessages(
        conversationId: _currentConversationId!,
        limit: 50,
        lastDocument: _lastDocument,
      );

      if (result.success) {
        if (refresh) {
          _messages = result.messages.reversed.toList(); // Reverse for chat order
        } else {
          // Insert older messages at the beginning
          _messages.insertAll(0, result.messages.reversed);
        }
        
        _lastDocument = result.lastDocument;
        _hasMoreMessages = result.hasMore;
      } else {
        _error = result.error ?? 'Failed to load messages';
      }
    } catch (e) {
      _error = 'Failed to load messages';
      debugPrint('Error loading messages: $e');
    }

    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  /// Load more messages (older messages)
  Future<void> loadMoreMessages() async {
    if (!_hasMoreMessages || _isLoadingMore || _isLoading) return;
    
    await loadMessages(refresh: false);
  }

  /// Send text message
  Future<bool> sendMessage({
    required String content,
    required String receiverId,
    String? replyToMessageId,
  }) async {
    if (_currentConversationId == null || content.trim().isEmpty) return false;

    _isSendingMessage = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _messageService.sendMessage(
        conversationId: _currentConversationId!,
        receiverId: receiverId,
        content: content.trim(),
        type: MessageType.text,
        replyToMessageId: replyToMessageId ?? _replyToMessage?.id,
      );

      if (result.success && result.message != null) {
        // Clear reply state
        clearReply();
        
        // Message will be added via real-time stream
        _isSendingMessage = false;
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Failed to send message';
        _isSendingMessage = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to send message';
      _isSendingMessage = false;
      notifyListeners();
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  /// Send image message
  Future<bool> sendImageMessage({
    required File imageFile,
    required String receiverId,
    String? caption,
    String? replyToMessageId,
  }) async {
    if (_currentConversationId == null) return false;

    final uploadId = DateTime.now().millisecondsSinceEpoch.toString();
    
    _isSendingImage = true;
    _uploadProgress[uploadId] = 0.0;
    _uploadErrors.remove(uploadId);
    notifyListeners();

    try {
      final result = await _messageService.sendImageMessage(
        conversationId: _currentConversationId!,
        receiverId: receiverId,
        imageFile: imageFile,
        caption: caption,
        replyToMessageId: replyToMessageId ?? _replyToMessage?.id,
      );

      if (result.success) {
        // Clear reply state
        clearReply();
        
        _uploadProgress[uploadId] = 1.0;
        _isSendingImage = false;
        
        // Remove upload progress after delay
        Future.delayed(const Duration(seconds: 2), () {
          _uploadProgress.remove(uploadId);
          notifyListeners();
        });
        
        notifyListeners();
        return true;
      } else {
        _uploadErrors[uploadId] = result.error ?? 'Upload failed';
        _isSendingImage = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _uploadErrors[uploadId] = 'Upload failed';
      _isSendingImage = false;
      notifyListeners();
      debugPrint('Error sending image: $e');
      return false;
    }
  }

  /// Delete message
  Future<bool> deleteMessage({
    required String messageId,
    bool deleteForEveryone = false,
  }) async {
    try {
      final result = await _messageService.deleteMessage(
        messageId: messageId,
        deleteForEveryone: deleteForEveryone,
      );

      if (result.success) {
        // Update message in local list
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index >= 0 && result.message != null) {
          _messages[index] = result.message!;
          notifyListeners();
        }
        return true;
      } else {
        _error = result.error ?? 'Failed to delete message';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to delete message';
      notifyListeners();
      debugPrint('Error deleting message: $e');
      return false;
    }
  }

  /// Search messages in current conversation
  Future<void> searchMessages(String query) async {
    if (_currentConversationId == null || query.trim().isEmpty) {
      clearSearch();
      return;
    }

    _isSearching = true;
    _currentSearchQuery = query;
    _error = null;
    notifyListeners();

    try {
      final result = await _messageService.searchMessages(
        conversationId: _currentConversationId!,
        query: query.trim(),
        limit: 50,
      );

      if (result.success) {
        _searchResults = result.messages;
      } else {
        _error = result.error ?? 'Search failed';
        _searchResults = [];
      }
    } catch (e) {
      _error = 'Search failed';
      _searchResults = [];
      debugPrint('Error searching messages: $e');
    }

    _isSearching = false;
    notifyListeners();
  }

  /// Clear search results
  void clearSearch() {
    _searchResults.clear();
    _currentSearchQuery = '';
    _isSearching = false;
    notifyListeners();
  }

  /// Start/stop typing indicator
  void updateTypingStatus(bool isTyping) {
    if (_currentConversationId == null || _isTyping == isTyping) return;

    _isTyping = isTyping;
    
    // Cancel previous timer
    _typingTimer?.cancel();
    
    // Send typing indicator
    _messageService.sendTypingIndicator(
      conversationId: _currentConversationId!,
      isTyping: isTyping,
    );

    if (isTyping) {
      // Auto-stop typing after 3 seconds
      _typingTimer = Timer(const Duration(seconds: 3), () {
        updateTypingStatus(false);
      });
    }

    notifyListeners();
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    try {
      final result = await _messageService.markMessageAsRead(messageId);
      
      if (result.success && result.message != null) {
        // Update message in local list
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index >= 0) {
          _messages[index] = result.message!;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  /// Mark all messages in conversation as read
  Future<void> _markConversationAsRead() async {
    if (_currentConversationId == null) return;
    
    try {
      await _messageService.markConversationMessagesAsRead(_currentConversationId!);
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
    }
  }

  /// Message selection methods
  void toggleMessageSelection(String messageId) {
    if (_selectedMessages.contains(messageId)) {
      _selectedMessages.remove(messageId);
    } else {
      _selectedMessages.add(messageId);
    }
    
    // Exit selection mode if no messages selected
    if (_selectedMessages.isEmpty) {
      _isSelectionMode = false;
    }
    
    notifyListeners();
  }

  void selectMessage(String messageId) {
    _selectedMessages.add(messageId);
    _isSelectionMode = true;
    notifyListeners();
  }

  void deselectMessage(String messageId) {
    _selectedMessages.remove(messageId);
    if (_selectedMessages.isEmpty) {
      _isSelectionMode = false;
    }
    notifyListeners();
  }

  void selectAllMessages() {
    _selectedMessages.clear();
    _selectedMessages.addAll(_messages.map((m) => m.id));
    _isSelectionMode = true;
    notifyListeners();
  }

  void clearSelection() {
    _selectedMessages.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  void enterSelectionMode() {
    _isSelectionMode = true;
    notifyListeners();
  }

  void exitSelectionMode() {
    _selectedMessages.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  /// Delete selected messages
  Future<bool> deleteSelectedMessages({bool deleteForEveryone = false}) async {
    if (_selectedMessages.isEmpty) return false;

    bool allDeleted = true;
    final messagesToDelete = List<String>.from(_selectedMessages);

    for (final messageId in messagesToDelete) {
      final deleted = await deleteMessage(
        messageId: messageId,
        deleteForEveryone: deleteForEveryone,
      );
      if (!deleted) allDeleted = false;
    }

    // Clear selection after deletion attempt
    clearSelection();
    
    return allDeleted;
  }

  /// Reply to message
  void setReplyToMessage(MessageModel message) {
    _replyToMessage = message;
    notifyListeners();
  }

  void clearReply() {
    _replyToMessage = null;
    notifyListeners();
  }

  /// Get message by ID
  MessageModel? getMessageById(String messageId) {
    try {
      return _messages.firstWhere((m) => m.id == messageId);
    } catch (e) {
      return null;
    }
  }

  /// Check if message is selected
  bool isMessageSelected(String messageId) {
    return _selectedMessages.contains(messageId);
  }

  /// Get message statistics
  Future<MessageStatsResult> getMessageStats() async {
    if (_currentConversationId == null) {
      return MessageStatsResult.error('No conversation selected');
    }
    
    try {
      return await _messageService.getMessageStats(_currentConversationId!);
    } catch (e) {
      debugPrint('Error getting message stats: $e');
      return MessageStatsResult.error('Failed to get statistics');
    }
  }

  /// Get messages sent by current user
  List<MessageModel> get messagesSentByCurrentUser {
    if (_currentUser == null) return [];
    
    return _messages.where((message) => 
        message.senderId == _currentUser!.id).toList();
  }

  /// Get messages received by current user
  List<MessageModel> get messagesReceivedByCurrentUser {
    if (_currentUser == null) return [];
    
    return _messages.where((message) => 
        message.receiverId == _currentUser!.id).toList();
  }

  /// Get unread messages
  List<MessageModel> get unreadMessages {
    if (_currentUser == null) return [];
    
    return _messages.where((message) => 
        message.receiverId == _currentUser!.id && !message.isRead).toList();
  }

  /// Check if user can send message (business rules)
  bool canSendMessage(String receiverId) {
    if (_currentUser == null) return false;
    
    // This would check business rules like message limits
    return _currentUser!.canMessageUser(receiverId);
  }

  /// Get remaining messages for user
  int getRemainingMessagesForUser(String userId) {
    return _currentUser?.getRemainingMessagesForUser(userId) ?? 0;
  }

  /// Check if conversation has premium status
  bool get isConversationPremium {
    // This would be passed from ConversationProvider or determined from messages
    return false; // Simplified for now
  }

  /// Start real-time message updates
  void _startRealTimeUpdates() {
    if (_currentConversationId == null) return;
    
    _messageStreamSubscription?.cancel();
    _unreadCountStreamSubscription?.cancel();
    
    // Stream messages for current conversation
    _messageStreamSubscription = _messageService
        .streamMessages(conversationId: _currentConversationId!, limit: 100)
        .listen(
      (messages) {
        _messages = messages.reversed.toList(); // Reverse for chat order
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Message stream error: $error');
        _error = 'Real-time updates failed';
        notifyListeners();
      },
    );
    
    // Stream unread count
    _unreadCountStreamSubscription = _messageService
        .streamUnreadMessageCount(_currentConversationId!)
        .listen(
      (count) {
        _unreadCount = count;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Unread count stream error: $error');
      },
    );
  }

  /// Clear upload error
  void clearUploadError(String uploadId) {
    _uploadErrors.remove(uploadId);
    notifyListeners();
  }

  /// Clear all upload errors
  void clearAllUploadErrors() {
    _uploadErrors.clear();
    notifyListeners();
  }

  /// Set error state
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Update current user
  void updateCurrentUser(UserModel? user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Refresh messages
  Future<void> refresh() async {
    await loadMessages(refresh: true);
  }

  /// Check if message can be deleted by current user
  bool canDeleteMessage(MessageModel message) {
    if (_currentUser == null) return false;
    
    // User can delete their own messages
    if (message.senderId == _currentUser!.id) {
      return true;
    }
    
    // Admins can delete any message (if needed)
    return _currentUser!.hasAdminAccess;
  }

  /// Check if message can be deleted for everyone
  bool canDeleteMessageForEveryone(MessageModel message) {
    if (_currentUser == null) return false;
    
    // Only sender can delete for everyone, and only within time limit (15 minutes)
    if (message.senderId == _currentUser!.id) {
      final timeDiff = DateTime.now().difference(message.sentAt);
      return timeDiff.inMinutes <= 15;
    }
    
    return false;
  }

  /// Get last message in conversation
  MessageModel? get lastMessage {
    return _messages.isNotEmpty ? _messages.last : null;
  }

  /// Get message count
  int get messageCount => _messages.length;

  /// Check if there are any media messages
  bool get hasMediaMessages {
    return _messages.any((message) => 
        message.type == MessageType.image || 
        message.type == MessageType.video ||
        message.type == MessageType.gif);
  }

  /// Get media messages only
  List<MessageModel> get mediaMessages {
    return _messages.where((message) => 
        message.type == MessageType.image || 
        message.type == MessageType.video ||
        message.type == MessageType.gif).toList();
  }

  /// Cleanup when changing conversations
  Future<void> _cleanup() async {
    // Cancel streams
    _messageStreamSubscription?.cancel();
    _unreadCountStreamSubscription?.cancel();
    _typingTimer?.cancel();
    
    // Clear state
    _messages.clear();
    _searchResults.clear();
    _selectedMessages.clear();
    _uploadProgress.clear();
    _uploadErrors.clear();
    
    // Reset flags
    _isLoading = false;
    _isLoadingMore = false;
    _isSendingMessage = false;
    _isSendingImage = false;
    _isSearching = false;
    _isSelectionMode = false;
    _isTyping = false;
    _hasMoreMessages = true;
    
    // Clear references
    _lastDocument = null;
    _replyToMessage = null;
    _error = null;
    _currentSearchQuery = '';
    _unreadCount = 0;
  }

  @override
  void dispose() {
    _messageStreamSubscription?.cancel();
    _unreadCountStreamSubscription?.cancel();
    _typingTimer?.cancel();
    
    _messages.clear();
    _searchResults.clear();
    _selectedMessages.clear();
    _uploadProgress.clear();
    _uploadErrors.clear();
    
    super.dispose();
  }
}