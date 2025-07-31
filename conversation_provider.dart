// providers/conversation_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/conversation_service.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';

/// Pure UI state management for conversations - orchestrates ConversationService
class ConversationProvider extends ChangeNotifier {
  final ConversationService _conversationService = ConversationService();
  
  // UI State - these should ONLY be in providers
  List<ConversationModel> _conversations = [];
  List<ConversationModel> _unreadConversations = [];
  List<ConversationModel> _searchResults = [];
  
  // Loading states
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isCreatingConversation = false;
  bool _isArchiving = false;
  bool _isDeleting = false;
  bool _isSearching = false;
  
  // Error states
  String? _error;
  
  // Pagination state
  DocumentSnapshot? _lastDocument;
  bool _hasMoreConversations = true;
  
  // Current conversation state
  ConversationModel? _currentConversation;
  
  // Search state
  String _currentSearchQuery = '';
  
  // Unread state
  int _totalUnreadCount = 0;
  final Map<String, int> _conversationUnreadCounts = {};
  
  // Typing indicators
  final Map<String, bool> _typingIndicators = {};
  
  // Real-time streams
  StreamSubscription<List<ConversationModel>>? _conversationStream;
  StreamSubscription<ConversationModel?>? _currentConversationStream;
  
  // Current user context
  UserModel? _currentUser;

  // Getters - UI can access these
  List<ConversationModel> get conversations => List.unmodifiable(_conversations);
  List<ConversationModel> get unreadConversations => List.unmodifiable(_unreadConversations);
  List<ConversationModel> get searchResults => List.unmodifiable(_searchResults);
  
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isCreatingConversation => _isCreatingConversation;
  bool get isArchiving => _isArchiving;
  bool get isDeleting => _isDeleting;
  bool get isSearching => _isSearching;
  bool get hasMoreConversations => _hasMoreConversations;
  
  String? get error => _error;
  ConversationModel? get currentConversation => _currentConversation;
  String get currentSearchQuery => _currentSearchQuery;
  bool get hasSearchResults => _searchResults.isNotEmpty;
  
  int get totalUnreadCount => _totalUnreadCount;
  Map<String, int> get conversationUnreadCounts => Map.unmodifiable(_conversationUnreadCounts);
  Map<String, bool> get typingIndicators => Map.unmodifiable(_typingIndicators);
  
  UserModel? get currentUser => _currentUser;
  bool get hasConversations => _conversations.isNotEmpty;

  /// Initialize with current user
  Future<void> initialize({UserModel? currentUser}) async {
    _currentUser = currentUser;
    await loadConversations();
    _startRealTimeUpdates();
    await _updateUnreadCounts();
  }

  /// Load conversations - orchestrates service call
  Future<void> loadConversations({bool refresh = false}) async {
    if (refresh) {
      _conversations.clear();
      _lastDocument = null;
      _hasMoreConversations = true;
    }

    _setLoading(refresh);
    _setLoadingMore(!refresh);
    _clearError();

    try {
      final result = await _conversationService.getUserConversations(
        includeArchived: false,
        activeOnly: true,
        limit: 20,
        lastDocument: _lastDocument,
      );

      if (result.success) {
        if (refresh) {
          _conversations = result.conversations;
        } else {
          _conversations.addAll(result.conversations);
        }
        
        _lastDocument = result.lastDocument;
        _hasMoreConversations = result.hasMore;
        
        await _updateUnreadConversations();
        await _updateUnreadCounts();
      } else {
        _setError(result.error ?? 'Failed to load conversations');
      }
    } catch (e) {
      _setError('Failed to load conversations');
      debugPrint('Error in loadConversations: $e');
    }

    _setLoading(false);
    _setLoadingMore(false);
  }

  /// Load more conversations (pagination)
  Future<void> loadMoreConversations() async {
    if (!_hasMoreConversations || _isLoadingMore || _isLoading) return;
    await loadConversations(refresh: false);
  }

  /// Create new conversation - orchestrates service call
  Future<ConversationModel?> createConversation({
    required String otherUserId,
    String? initialMessage,
  }) async {
    _setCreatingConversation(true);
    _clearError();

    try {
      final result = await _conversationService.createConversation(
        otherUserId: otherUserId,
        initialMessage: initialMessage,
      );

      if (result.success && result.conversation != null) {
        final conversation = result.conversation!;
        
        // Update UI state
        final existingIndex = _conversations.indexWhere((c) => c.id == conversation.id);
        if (existingIndex >= 0) {
          _conversations[existingIndex] = conversation;
        } else {
          _conversations.insert(0, conversation);
        }
        
        _setCreatingConversation(false);
        return conversation;
      } else {
        _setError(result.error ?? 'Failed to create conversation');
        _setCreatingConversation(false);
        return null;
      }
    } catch (e) {
      _setError('Failed to create conversation');
      _setCreatingConversation(false);
      debugPrint('Error in createConversation: $e');
      return null;
    }
  }

  /// Open conversation and start real-time updates
  Future<void> openConversation(String conversationId) async {
    try {
      final result = await _conversationService.getConversationById(conversationId);
      
      if (result.success && result.conversation != null) {
        _currentConversation = result.conversation!;
        _startCurrentConversationUpdates(conversationId);
        await markConversationAsRead(conversationId);
        notifyListeners();
      } else {
        _setError(result.error ?? 'Failed to open conversation');
      }
    } catch (e) {
      _setError('Failed to open conversation');
      debugPrint('Error in openConversation: $e');
    }
  }

  /// Close current conversation
  void closeConversation() {
    _currentConversation = null;
    _currentConversationStream?.cancel();
    _currentConversationStream = null;
    _typingIndicators.clear();
    notifyListeners();
  }

  /// Mark conversation as read - orchestrates service call
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final result = await _conversationService.markAsRead(conversationId);
      
      if (result.success && result.conversation != null) {
        final updatedConversation = result.conversation!;
        
        // Update UI state
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index >= 0) {
          _conversations[index] = updatedConversation;
        }
        
        if (_currentConversation?.id == conversationId) {
          _currentConversation = updatedConversation;
        }
        
        await _updateUnreadCounts();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in markConversationAsRead: $e');
    }
  }

  /// Archive conversation - orchestrates service call
  Future<bool> archiveConversation(String conversationId) async {
    _setArchiving(true);
    _clearError();

    try {
      final result = await _conversationService.archiveConversation(conversationId);
      
      if (result.success) {
        // Update UI state
        _conversations.removeWhere((c) => c.id == conversationId);
        _unreadConversations.removeWhere((c) => c.id == conversationId);
        
        _setArchiving(false);
        return true;
      } else {
        _setError(result.error ?? 'Failed to archive conversation');
        _setArchiving(false);
        return false;
      }
    } catch (e) {
      _setError('Failed to archive conversation');
      _setArchiving(false);
      debugPrint('Error in archiveConversation: $e');
      return false;
    }
  }

  /// Delete conversation - orchestrates service call
  Future<bool> deleteConversation(String conversationId) async {
    _setDeleting(true);
    _clearError();

    try {
      final result = await _conversationService.deleteConversation(conversationId);
      
      if (result.success) {
        // Update UI state
        _conversations.removeWhere((c) => c.id == conversationId);
        _unreadConversations.removeWhere((c) => c.id == conversationId);
        
        if (_currentConversation?.id == conversationId) {
          closeConversation();
        }
        
        _setDeleting(false);
        return true;
      } else {
        _setError(result.error ?? 'Failed to delete conversation');
        _setDeleting(false);
        return false;
      }
    } catch (e) {
      _setError('Failed to delete conversation');
      _setDeleting(false);
      debugPrint('Error in deleteConversation: $e');
      return false;
    }
  }

  /// Block user and end conversation
  Future<bool> blockUserAndEndConversation({
    required String conversationId,
    required String userIdToBlock,
  }) async {
    try {
      final result = await _conversationService.blockUserAndEndConversation(
        conversationId: conversationId,
        userIdToBlock: userIdToBlock,
      );
      
      if (result.success) {
        // Update UI state
        _conversations.removeWhere((c) => c.id == conversationId);
        _unreadConversations.removeWhere((c) => c.id == conversationId);
        
        if (_currentConversation?.id == conversationId) {
          closeConversation();
        }
        
        notifyListeners();
        return true;
      } else {
        _setError(result.error ?? 'Failed to block user');
        return false;
      }
    } catch (e) {
      _setError('Failed to block user');
      debugPrint('Error in blockUserAndEndConversation: $e');
      return false;
    }
  }

  /// Search conversations - orchestrates service call
  Future<void> searchConversations(String query) async {
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }

    _setSearching(true);
    _currentSearchQuery = query;
    _clearError();

    try {
      final result = await _conversationService.searchConversations(
        query: query,
        limit: 20,
      );

      if (result.success) {
        _searchResults = result.conversations;
      } else {
        _setError(result.error ?? 'Search failed');
        _searchResults = [];
      }
    } catch (e) {
      _setError('Search failed');
      _searchResults = [];
      debugPrint('Error in searchConversations: $e');
    }

    _setSearching(false);
  }

  /// Clear search results
  void clearSearch() {
    _searchResults.clear();
    _currentSearchQuery = '';
    _setSearching(false);
  }

  /// Update typing status - orchestrates service call
  Future<void> updateTypingStatus({
    required String conversationId,
    required bool isTyping,
  }) async {
    try {
      await _conversationService.updateTypingStatus(
        conversationId: conversationId,
        isTyping: isTyping,
      );
    } catch (e) {
      debugPrint('Error in updateTypingStatus: $e');
    }
  }

  /// Get conversation statistics
  Future<ConversationStatsResult> getConversationStats(String conversationId) async {
    try {
      return await _conversationService.getConversationStats(conversationId);
    } catch (e) {
      debugPrint('Error in getConversationStats: $e');
      return ConversationStatsResult.error('Failed to get statistics');
    }
  }

  /// Update current user (called from AppProviders)
  void updateCurrentUser(UserModel? user) {
    if (_currentUser != user) {
      _currentUser = user;
      notifyListeners();
    }
  }

  /// Refresh conversations (pull to refresh)
  Future<void> refresh() async {
    await loadConversations(refresh: true);
  }

  // PRIVATE HELPER METHODS - UI state management only

  /// Update unread conversations
  Future<void> _updateUnreadConversations() async {
    try {
      final result = await _conversationService.getUnreadConversations();
      
      if (result.success) {
        _unreadConversations = result.conversations;
      }
    } catch (e) {
      debugPrint('Error updating unread conversations: $e');
    }
  }

  /// Update unread counts
  Future<void> _updateUnreadCounts() async {
    try {
      _totalUnreadCount = await _conversationService.getTotalUnreadCount();
      
      _conversationUnreadCounts.clear();
      
      if (_currentUser != null) {
        for (final conversation in _conversations) {
          final unreadCount = conversation.getUnreadCount(_currentUser!.id);
          if (unreadCount > 0) {
            _conversationUnreadCounts[conversation.id] = unreadCount;
          }
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating unread counts: $e');
    }
  }

  /// Start real-time conversation updates
  void _startRealTimeUpdates() {
    _conversationStream?.cancel();
    
    _conversationStream = _conversationService
        .streamUserConversations(includeArchived: false)
        .listen(
      (conversations) {
        _conversations = conversations;
        _updateUnreadConversations();
        _updateUnreadCounts();
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Conversation stream error: $error');
        _setError('Real-time updates failed');
      },
    );
  }

  /// Start real-time updates for current conversation
  void _startCurrentConversationUpdates(String conversationId) {
    _currentConversationStream?.cancel();
    
    _currentConversationStream = _conversationService
        .streamConversation(conversationId)
        .listen(
      (conversation) {
        if (conversation != null) {
          _currentConversation = conversation;
          
          // Update typing indicators
          if (_currentUser != null) {
            _typingIndicators.clear();
            for (final participantId in conversation.participantIds) {
              if (participantId != _currentUser!.id) {
                _typingIndicators[participantId] = conversation.isUserTyping(participantId);
              }
            }
          }
          
          // Update in conversations list
          final index = _conversations.indexWhere((c) => c.id == conversationId);
          if (index >= 0) {
            _conversations[index] = conversation;
          }
          
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('Current conversation stream error: $error');
      },
    );
  }

  // STATE MANAGEMENT HELPERS - These should ONLY be in providers

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setLoadingMore(bool loadingMore) {
    if (_isLoadingMore != loadingMore) {
      _isLoadingMore = loadingMore;
      notifyListeners();
    }
  }

  void _setCreatingConversation(bool creating) {
    if (_isCreatingConversation != creating) {
      _isCreatingConversation = creating;
      notifyListeners();
    }
  }

  void _setArchiving(bool archiving) {
    if (_isArchiving != archiving) {
      _isArchiving = archiving;
      notifyListeners();
    }
  }

  void _setDeleting(bool deleting) {
    if (_isDeleting != deleting) {
      _isDeleting = deleting;
      notifyListeners();
    }
  }

  void _setSearching(bool searching) {
    if (_isSearching != searching) {
      _isSearching = searching;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  void _clearError() {
    _setError(null);
  }

  // BUSINESS LOGIC HELPERS - These can stay in providers

  /// Check if user can create conversation (business rule)
  bool canCreateConversation(String otherUserId) {
    if (_currentUser == null) return false;
    
    // Check message limits based on business rules in UserModel
    return _currentUser!.canMessageUser(otherUserId);
  }

  /// Get remaining message count for user
  int getRemainingMessagesForUser(String userId) {
    return _currentUser?.getRemainingMessagesForUser(userId) ?? 0;
  }

  /// Check if conversation exists with user
  bool hasConversationWith(String userId) {
    return _conversations.any((conversation) => 
        conversation.participantIds.contains(userId));
  }

  /// Get conversation with specific user
  ConversationModel? getConversationWith(String userId) {
    try {
      return _conversations.firstWhere((conversation) => 
          conversation.participantIds.contains(userId));
    } catch (e) {
      return null;
    }
  }

  /// Get conversation by ID
  ConversationModel? getConversationById(String conversationId) {
    try {
      return _conversations.firstWhere((c) => c.id == conversationId);
    } catch (e) {
      return null;
    }
  }

  /// Check if conversation is premium (affects message limits)
  bool isConversationPremium(String conversationId) {
    final conversation = getConversationById(conversationId);
    return conversation?.isPremiumConversation ?? false;
  }

  /// Get unread count for specific conversation
  int getUnreadCountForConversation(String conversationId) {
    return _conversationUnreadCounts[conversationId] ?? 0;
  }

  /// Check if someone is typing in conversation
  bool isSomeoneTypingInConversation(String conversationId) {
    final conversation = getConversationById(conversationId);
    return conversation?.isSomeoneTyping ?? false;
  }

  /// Get typing users in conversation
  List<String> getTypingUsersInConversation(String conversationId) {
    final conversation = getConversationById(conversationId);
    if (conversation == null || _currentUser == null) return [];
    
    return conversation.participantIds
        .where((participantId) => 
            participantId != _currentUser!.id && 
            conversation.isUserTyping(participantId))
        .toList();
  }

  /// Clear all state (cleanup on logout)
  void clear() {
    // Cancel streams
    _conversationStream?.cancel();
    _currentConversationStream?.cancel();
    
    // Clear state
    _conversations.clear();
    _unreadConversations.clear();
    _searchResults.clear();
    _conversationUnreadCounts.clear();
    _typingIndicators.clear();
    
    // Reset flags
    _isLoading = false;
    _isLoadingMore = false;
    _isCreatingConversation = false;
    _isArchiving = false;
    _isDeleting = false;
    _isSearching = false;
    _hasMoreConversations = true;
    
    // Clear references
    _lastDocument = null;
    _currentConversation = null;
    _currentUser = null;
    _error = null;
    _currentSearchQuery = '';
    _totalUnreadCount = 0;
    
    notifyListeners();
  }

  @override
  void dispose() {
    _conversationStream?.cancel();
    _currentConversationStream?.cancel();
    clear();
    super.dispose();
  }
}