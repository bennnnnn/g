import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/conversation_model.dart';
import '../../models/message_model.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;

  /// Initialize cache service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      debugPrint('Cache service initialized');
    } catch (e) {
      debugPrint('Error initializing cache: $e');
    }
  }

  // USER CACHING

  /// Cache user data
  Future<void> cacheUser(UserModel user) async {
    try {
      await _prefs?.setString('user_${user.id}', jsonEncode(user.toFirestore()));
      await _prefs?.setString('current_user', user.id);
      await _prefs?.setInt('user_cache_time_${user.id}', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching user: $e');
    }
  }

  /// Get cached user
  UserModel? getCachedUser(String userId) {
    try {
      final userJson = _prefs?.getString('user_$userId');
      if (userJson == null) return null;

      // Check if cache is still valid (24 hours)
      final cacheTime = _prefs?.getInt('user_cache_time_$userId') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final hoursDiff = (now - cacheTime) / (1000 * 60 * 60);
      
      if (hoursDiff > 24) {
        removeCachedUser(userId);
        return null;
      }

      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      return UserModel.fromFirestore(MockDocumentSnapshot(userId, userData) as DocumentSnapshot<Object?>);
    } catch (e) {
      debugPrint('Error getting cached user: $e');
      return null;
    }
  }

  /// Get current cached user
  UserModel? getCurrentCachedUser() {
    final currentUserId = _prefs?.getString('current_user');
    if (currentUserId == null) return null;
    return getCachedUser(currentUserId);
  }

  /// Remove cached user
  Future<void> removeCachedUser(String userId) async {
    try {
      await _prefs?.remove('user_$userId');
      await _prefs?.remove('user_cache_time_$userId');
    } catch (e) {
      debugPrint('Error removing cached user: $e');
    }
  }

  // CONVERSATION CACHING

  /// Cache conversations list
  Future<void> cacheConversations(List<ConversationModel> conversations) async {
    try {
      final conversationsJson = conversations.map((c) => c.toFirestore()).toList();
      await _prefs?.setString('conversations', jsonEncode(conversationsJson));
      await _prefs?.setInt('conversations_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching conversations: $e');
    }
  }

  /// Get cached conversations
  List<ConversationModel>? getCachedConversations() {
    try {
      final conversationsJson = _prefs?.getString('conversations');
      if (conversationsJson == null) return null;

      // Check if cache is valid (1 hour for conversations)
      final cacheTime = _prefs?.getInt('conversations_cache_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final minutesDiff = (now - cacheTime) / (1000 * 60);
      
      if (minutesDiff > 60) {
        removeCachedConversations();
        return null;
      }

      final conversationsData = jsonDecode(conversationsJson) as List;
      return conversationsData.map((data) => 
        ConversationModel.fromFirestore(MockDocumentSnapshot('', data) as DocumentSnapshot<Object?>)
      ).toList();
    } catch (e) {
      debugPrint('Error getting cached conversations: $e');
      return null;
    }
  }

  /// Remove cached conversations
  Future<void> removeCachedConversations() async {
    try {
      await _prefs?.remove('conversations');
      await _prefs?.remove('conversations_cache_time');
    } catch (e) {
      debugPrint('Error removing cached conversations: $e');
    }
  }

  // MESSAGE CACHING

  /// Cache messages for conversation
  Future<void> cacheMessages(String conversationId, List<MessageModel> messages) async {
    try {
      final messagesJson = messages.map((m) => m.toFirestore()).toList();
      await _prefs?.setString('messages_$conversationId', jsonEncode(messagesJson));
      await _prefs?.setInt('messages_cache_time_$conversationId', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching messages: $e');
    }
  }

  /// Get cached messages
  List<MessageModel>? getCachedMessages(String conversationId) {
    try {
      final messagesJson = _prefs?.getString('messages_$conversationId');
      if (messagesJson == null) return null;

      // Check if cache is valid (30 minutes for messages)
      final cacheTime = _prefs?.getInt('messages_cache_time_$conversationId') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final minutesDiff = (now - cacheTime) / (1000 * 60);
      
      if (minutesDiff > 30) {
        removeCachedMessages(conversationId);
        return null;
      }

      final messagesData = jsonDecode(messagesJson) as List;
      return messagesData.map((data) => 
        MessageModel.fromFirestore(MockDocumentSnapshot('', data) as DocumentSnapshot<Object?>)
      ).toList();
    } catch (e) {
      debugPrint('Error getting cached messages: $e');
      return null;
    }
  }

  /// Remove cached messages
  Future<void> removeCachedMessages(String conversationId) async {
    try {
      await _prefs?.remove('messages_$conversationId');
      await _prefs?.remove('messages_cache_time_$conversationId');
    } catch (e) {
      debugPrint('Error removing cached messages: $e');
    }
  }

  // GENERIC CACHING

  /// Cache any string data
  Future<void> cacheString(String key, String value, {Duration? expiry}) async {
    try {
      await _prefs?.setString(key, value);
      if (expiry != null) {
        final expiryTime = DateTime.now().add(expiry).millisecondsSinceEpoch;
        await _prefs?.setInt('${key}_expiry', expiryTime);
      }
    } catch (e) {
      debugPrint('Error caching string: $e');
    }
  }

  /// Get cached string
  String? getCachedString(String key) {
    try {
      // Check expiry
      final expiryTime = _prefs?.getInt('${key}_expiry');
      if (expiryTime != null) {
        if (DateTime.now().millisecondsSinceEpoch > expiryTime) {
          removeCachedString(key);
          return null;
        }
      }

      return _prefs?.getString(key);
    } catch (e) {
      debugPrint('Error getting cached string: $e');
      return null;
    }
  }

  /// Remove cached string
  Future<void> removeCachedString(String key) async {
    try {
      await _prefs?.remove(key);
      await _prefs?.remove('${key}_expiry');
    } catch (e) {
      debugPrint('Error removing cached string: $e');
    }
  }

  /// Cache integer
  Future<void> cacheInt(String key, int value) async {
    try {
      await _prefs?.setInt(key, value);
    } catch (e) {
      debugPrint('Error caching int: $e');
    }
  }

  /// Get cached integer
  int? getCachedInt(String key) {
    try {
      return _prefs?.getInt(key);
    } catch (e) {
      debugPrint('Error getting cached int: $e');
      return null;
    }
  }

  /// Cache boolean
  Future<void> cacheBool(String key, bool value) async {
    try {
      await _prefs?.setBool(key, value);
    } catch (e) {
      debugPrint('Error caching bool: $e');
    }
  }

  /// Get cached boolean
  bool? getCachedBool(String key) {
    try {
      return _prefs?.getBool(key);
    } catch (e) {
      debugPrint('Error getting cached bool: $e');
      return null;
    }
  }

  // UTILITY METHODS

  /// Clear all cache
  Future<void> clearAllCache() async {
    try {
      await _prefs?.clear();
      debugPrint('All cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Clear expired cache
  Future<void> clearExpiredCache() async {
    try {
      final keys = _prefs?.getKeys() ?? <String>{};
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final key in keys) {
        if (key.endsWith('_expiry')) {
          final expiryTime = _prefs?.getInt(key);
          if (expiryTime != null && now > expiryTime) {
            final dataKey = key.replaceAll('_expiry', '');
            await _prefs?.remove(dataKey);
            await _prefs?.remove(key);
          }
        }
      }
    } catch (e) {
      debugPrint('Error clearing expired cache: $e');
    }
  }

  /// Get cache size info
  Map<String, dynamic> getCacheInfo() {
    try {
      final keys = _prefs?.getKeys() ?? <String>{};
      int userCount = 0;
      int conversationCount = 0;
      int messageCount = 0;
      int otherCount = 0;

      for (final key in keys) {
        if (key.startsWith('user_')) userCount++;
        else if (key.startsWith('conversations')) conversationCount++;
        else if (key.startsWith('messages_')) messageCount++;
        else otherCount++;
      }

      return {
        'totalKeys': keys.length,
        'users': userCount,
        'conversations': conversationCount,
        'messages': messageCount,
        'other': otherCount,
      };
    } catch (e) {
      debugPrint('Error getting cache info: $e');
      return {};
    }
  }

  /// Check if connected to internet
  bool get isOnline {
    // You can implement connectivity checking here
    // For now, assume online
    return true;
  }
}

/// Mock DocumentSnapshot for cache deserialization
class MockDocumentSnapshot {
  final String id;
  final Map<String, dynamic> _data;

  MockDocumentSnapshot(this.id, this._data);

  Map<String, dynamic> data() => _data;
  bool get exists => true;
}