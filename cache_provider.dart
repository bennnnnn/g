// providers/cache_provider.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/cache_service.dart';
import '../models/user_model.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class CacheProvider extends ChangeNotifier {
  final CacheService _cacheService = CacheService();
  
  bool _isInitialized = false;
  Map<String, dynamic> _cacheInfo = {};
  
  bool get isInitialized => _isInitialized;
  Map<String, dynamic> get cacheInfo => _cacheInfo;

  /// Initialize cache service
  Future<void> initialize() async {
    try {
      await _cacheService.initialize();
      _isInitialized = true;
      await refreshCacheInfo();
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing cache provider: $e');
    }
  }

  /// Refresh cache information
  Future<void> refreshCacheInfo() async {
    _cacheInfo = _cacheService.getCacheInfo();
    notifyListeners();
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    await _cacheService.clearAllCache();
    await refreshCacheInfo();
    debugPrint('All cache cleared by user');
  }

  /// Clear expired cache
  Future<void> clearExpiredCache() async {
    await _cacheService.clearExpiredCache();
    await refreshCacheInfo();
    debugPrint('Expired cache cleared');
  }

  /// Get cache string with provider context
  String? getCachedString(String key) {
    return _cacheService.getCachedString(key);
  }

  /// Cache string with provider context
  Future<void> cacheString(String key, String value, {Duration? expiry}) async {
    await _cacheService.cacheString(key, value, expiry: expiry);
    await refreshCacheInfo();
  }

  /// Remove cached string
  Future<void> removeCachedString(String key) async {
    await _cacheService.removeCachedString(key);
    await refreshCacheInfo();
  }

  /// Cache user data
  Future<void> cacheUser(UserModel user) async {
    await _cacheService.cacheUser(user);
    await refreshCacheInfo();
  }

  /// Get cached user
  UserModel? getCachedUser(String userId) {
    return _cacheService.getCachedUser(userId);
  }

  /// Remove cached user
  Future<void> removeCachedUser(String userId) async {
    await _cacheService.removeCachedUser(userId);
    await refreshCacheInfo();
  }

  /// Cache conversations
  Future<void> cacheConversations(List<ConversationModel> conversations) async {
    await _cacheService.cacheConversations(conversations);
    await refreshCacheInfo();
  }

  /// Get cached conversations
  List<ConversationModel>? getCachedConversations() {
    return _cacheService.getCachedConversations();
  }

  /// Remove cached conversations
  Future<void> removeCachedConversations() async {
    await _cacheService.removeCachedConversations();
    await refreshCacheInfo();
  }

  /// Cache messages for conversation
  Future<void> cacheMessages(String conversationId, List<MessageModel> messages) async {
    await _cacheService.cacheMessages(conversationId, messages);
    await refreshCacheInfo();
  }

  /// Get cached messages
  List<MessageModel>? getCachedMessages(String conversationId) {
    return _cacheService.getCachedMessages(conversationId);
  }

  /// Remove cached messages
  Future<void> removeCachedMessages(String conversationId) async {
    await _cacheService.removeCachedMessages(conversationId);
    await refreshCacheInfo();
  }

  /// Cache integer
  Future<void> cacheInt(String key, int value) async {
    await _cacheService.cacheInt(key, value);
    await refreshCacheInfo();
  }

  /// Get cached integer
  int? getCachedInt(String key) {
    return _cacheService.getCachedInt(key);
  }

  /// Cache boolean
  Future<void> cacheBool(String key, bool value) async {
    await _cacheService.cacheBool(key, value);
    await refreshCacheInfo();
  }

  /// Get cached boolean
  bool? getCachedBool(String key) {
    return _cacheService.getCachedBool(key);
  }

  /// Check if online (for cache strategy)
  bool get isOnline => _cacheService.isOnline;

  /// Get cache size statistics
  int get totalCacheItems => _cacheInfo['totalKeys'] as int? ?? 0;
  int get cachedUsers => _cacheInfo['users'] as int? ?? 0;
  int get cachedConversations => _cacheInfo['conversations'] as int? ?? 0;
  int get cachedMessages => _cacheInfo['messages'] as int? ?? 0;
  int get otherCachedItems => _cacheInfo['other'] as int? ?? 0;

  /// Get cache health status
  String get cacheHealthStatus {
    if (!_isInitialized) return 'Not initialized';
    if (totalCacheItems == 0) return 'Empty';
    if (totalCacheItems > 1000) return 'Large';
    if (totalCacheItems > 500) return 'Medium';
    return 'Good';
  }

  /// Check if cache needs cleanup
  bool get needsCleanup => totalCacheItems > 1000;
}
 