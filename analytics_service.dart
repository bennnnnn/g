import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../models/enums.dart';
import 'user_service.dart';
import 'cache_service.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final CacheService _cacheService = CacheService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Initialize analytics (set up listeners, etc.)
  Future<void> initialize() async {
    try {
      // Track app start
      await trackEvent(AnalyticsEvent.appStart);
      debugPrint('Analytics service initialized');
    } catch (e) {
      debugPrint('Error initializing analytics: $e');
    }
  }

  /// Track user event
  Future<void> trackEvent(
    AnalyticsEvent event, {
    Map<String, dynamic>? properties,
    String? targetUserId,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final now = DateTime.now();
      
      // Create event data
      final eventData = {
        'userId': userId,
        'event': event.toString().split('.').last,
        'properties': properties ?? {},
        'targetUserId': targetUserId,
        'timestamp': Timestamp.fromDate(now),
        'platform': 'mobile',
        'appVersion': '1.0.0', // Would come from package_info
        'deviceInfo': await _getDeviceInfo(),
      };

      // Save to Firestore (consider batching for performance)
      await _firestore.collection('analytics_events').add(eventData);

      // Cache recent events for offline analytics
      await _cacheRecentEvent(event, properties, now);

      debugPrint('Event tracked: ${event.toString().split('.').last}');
    } catch (e) {
      debugPrint('Error tracking event: $e');
      // Don't fail app functionality for analytics errors
    }
  }

  /// Track screen view
  Future<void> trackScreenView(String screenName, {Map<String, dynamic>? properties}) async {
    await trackEvent(
      AnalyticsEvent.screenView,
      properties: {
        'screenName': screenName,
        ...?properties,
      },
    );
  }

  /// Track user interaction (taps, swipes, etc.)
  Future<void> trackUserInteraction(
    String action,
    String element, {
    Map<String, dynamic>? properties,
  }) async {
    await trackEvent(
      AnalyticsEvent.userInteraction,
      properties: {
        'action': action,
        'element': element,
        ...?properties,
      },
    );
  }

  /// Track messaging events
  Future<void> trackMessageEvent({
    required MessageAnalyticsEvent event,
    String? conversationId,
    String? recipientId,
    MessageType? messageType,
    Map<String, dynamic>? properties,
  }) async {
    await trackEvent(
      AnalyticsEvent.messaging,
      properties: {
        'messageEvent': event.toString().split('.').last,
        'conversationId': conversationId,
        'messageType': messageType?.toString().split('.').last,
        ...?properties,
      },
      targetUserId: recipientId,
    );
  }

  /// Track subscription events
  Future<void> trackSubscriptionEvent({
    required SubscriptionAnalyticsEvent event,
    SubscriptionPlan? plan,
    double? amount,
    String? paymentMethod,
    Map<String, dynamic>? properties,
  }) async {
    await trackEvent(
      AnalyticsEvent.subscription,
      properties: {
        'subscriptionEvent': event.toString().split('.').last,
        'plan': plan?.toString().split('.').last,
        'amount': amount,
        'paymentMethod': paymentMethod,
        ...?properties,
      },
    );
  }

  /// Track gift events
  Future<void> trackGiftEvent({
    required GiftAnalyticsEvent event,
    String? giftId,
    String? recipientId,
    double? amount,
    String? giftCategory,
    Map<String, dynamic>? properties,
  }) async {
    await trackEvent(
      AnalyticsEvent.gift,
      properties: {
        'giftEvent': event.toString().split('.').last,
        'giftId': giftId,
        'amount': amount,
        'giftCategory': giftCategory,
        ...?properties,
      },
      targetUserId: recipientId,
    );
  }

  /// Track profile events
  Future<void> trackProfileEvent({
    required ProfileAnalyticsEvent event,
    String? targetUserId,
    Map<String, dynamic>? properties,
  }) async {
    await trackEvent(
      AnalyticsEvent.profile,
      properties: {
        'profileEvent': event.toString().split('.').last,
        ...?properties,
      },
      targetUserId: targetUserId,
    );
  }

  /// Track discovery/matching events
  Future<void> trackDiscoveryEvent({
    required DiscoveryAnalyticsEvent event,
    String? targetUserId,
    Map<String, dynamic>? filters,
    int? resultCount,
    Map<String, dynamic>? properties,
  }) async {
    await trackEvent(
      AnalyticsEvent.discovery,
      properties: {
        'discoveryEvent': event.toString().split('.').last,
        'filters': filters,
        'resultCount': resultCount,
        ...?properties,
      },
      targetUserId: targetUserId,
    );
  }

  /// Get user analytics summary
  Future<UserAnalyticsResult> getUserAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return UserAnalyticsResult.error('No user signed in');
      }

      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Get user events
      final eventsQuery = await _firestore
          .collection('analytics_events')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('timestamp', descending: true)
          .get();

      final events = eventsQuery.docs
          .map((doc) => doc.data())
          .toList();

      // Calculate analytics
      final analytics = _calculateUserAnalytics(events, start, end);

      return UserAnalyticsResult.success(analytics);
    } catch (e) {
      debugPrint('Error getting user analytics: $e');
      return UserAnalyticsResult.error('Failed to get analytics');
    }
  }

  /// Get app-wide analytics (admin only)
  Future<AppAnalyticsResult> getAppAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    String? eventType,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return AppAnalyticsResult.error('No user signed in');
      }

      // Check if user has analytics permission
      final userResult = await _userService.getCurrentUser();
      if (!userResult.success || userResult.user == null) {
        return AppAnalyticsResult.error('Failed to get user data');
      }

      final user = userResult.user!;
      if (!user.canViewAnalytics) {
        return AppAnalyticsResult.error('Access denied - analytics permission required');
      }

      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Build query
      Query query = _firestore
          .collection('analytics_events')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end));

      if (eventType != null) {
        query = query.where('event', isEqualTo: eventType);
      }

      // Get events (limit for performance)
      final eventsQuery = await query
          .orderBy('timestamp', descending: true)
          .limit(10000) // Reasonable limit
          .get();

      final events = eventsQuery.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      // Calculate app analytics
      final analytics = _calculateAppAnalytics(events, start, end);

      return AppAnalyticsResult.success(analytics);
    } catch (e) {
      debugPrint('Error getting app analytics: $e');
      return AppAnalyticsResult.error('Failed to get app analytics');
    }
  }

  /// Get popular content/features
  Future<PopularContentResult> getPopularContent({
    ContentType? contentType,
    Duration timeRange = const Duration(days: 7),
    int limit = 10,
  }) async {
    try {
      final startDate = DateTime.now().subtract(timeRange);

      Query query = _firestore
          .collection('analytics_events')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));

      if (contentType != null) {
        query = query.where('event', isEqualTo: contentType.toString().split('.').last);
      }

      final eventsQuery = await query.get();
      final events = eventsQuery.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      final popularContent = _calculatePopularContent(events, contentType, limit);

      return PopularContentResult.success(popularContent);
    } catch (e) {
      debugPrint('Error getting popular content: $e');
      return PopularContentResult.error('Failed to get popular content');
    }
  }

  /// Get user engagement metrics
  Future<EngagementMetricsResult> getEngagementMetrics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return EngagementMetricsResult.error('No user signed in');
      }

      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Get user events
      final eventsQuery = await _firestore
          .collection('analytics_events')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final events = eventsQuery.docs.map((doc) => doc.data()).toList();

      // Calculate engagement
      final metrics = _calculateEngagementMetrics(events, start, end);

      return EngagementMetricsResult.success(metrics);
    } catch (e) {
      debugPrint('Error getting engagement metrics: $e');
      return EngagementMetricsResult.error('Failed to get engagement metrics');
    }
  }

  /// Track funnel conversion
  Future<void> trackFunnelStep({
    required String funnelName,
    required String stepName,
    required int stepNumber,
    Map<String, dynamic>? properties,
  }) async {
    await trackEvent(
      AnalyticsEvent.funnel,
      properties: {
        'funnelName': funnelName,
        'stepName': stepName,
        'stepNumber': stepNumber,
        ...?properties,
      },
    );
  }

  /// Get funnel analytics
  Future<FunnelAnalyticsResult> getFunnelAnalytics({
    required String funnelName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final eventsQuery = await _firestore
          .collection('analytics_events')
          .where('event', isEqualTo: 'funnel')
          .where('properties.funnelName', isEqualTo: funnelName)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final events = eventsQuery.docs.map((doc) => doc.data()).toList();
      final funnelData = _calculateFunnelAnalytics(events, funnelName);

      return FunnelAnalyticsResult.success(funnelData);
    } catch (e) {
      debugPrint('Error getting funnel analytics: $e');
      return FunnelAnalyticsResult.error('Failed to get funnel analytics');
    }
  }

  /// Calculate user analytics from events
  UserAnalytics _calculateUserAnalytics(
    List<Map<String, dynamic>> events,
    DateTime startDate,
    DateTime endDate,
  ) {
    final eventCounts = <String, int>{};
    final dailyActivity = <String, int>{};
    final screenViews = <String, int>{};
    int totalEvents = events.length;

    for (final event in events) {
      final eventType = event['event'] as String;
      final timestamp = (event['timestamp'] as Timestamp).toDate();
      final properties = event['properties'] as Map<String, dynamic>? ?? {};

      // Count events by type
      eventCounts[eventType] = (eventCounts[eventType] ?? 0) + 1;

      // Daily activity
      final dateKey = '${timestamp.year}-${timestamp.month}-${timestamp.day}';
      dailyActivity[dateKey] = (dailyActivity[dateKey] ?? 0) + 1;

      // Screen views
      if (eventType == 'screenView') {
        final screenName = properties['screenName'] as String?;
        if (screenName != null) {
          screenViews[screenName] = (screenViews[screenName] ?? 0) + 1;
        }
      }
    }

    // Calculate session count (simplified - count app_start events)
    final sessionCount = eventCounts['appStart'] ?? 0;

    // Calculate average session duration (simplified)
    final totalDays = endDate.difference(startDate).inDays;
    final averageEventsPerDay = totalDays > 0 ? totalEvents / totalDays : 0.0;

    return UserAnalytics(
      totalEvents: totalEvents,
      sessionCount: sessionCount,
      eventCounts: eventCounts,
      dailyActivity: dailyActivity,
      mostViewedScreens: screenViews,
      averageEventsPerDay: averageEventsPerDay,
      dateRange: DateRange(start: startDate, end: endDate),
    );
  }

  /// Calculate app-wide analytics
  AppAnalytics _calculateAppAnalytics(
    List<Map<String, dynamic>> events,
    DateTime startDate,
    DateTime endDate,
  ) {
    final userCounts = <String, Set<String>>{};
    final eventCounts = <String, int>{};
    final dailyActiveUsers = <String, Set<String>>{};
    final totalUsers = <String>{};

    for (final event in events) {
      final eventType = event['event'] as String;
      final userId = event['userId'] as String;
      final timestamp = (event['timestamp'] as Timestamp).toDate();

      // Track unique users per event type
      userCounts[eventType] ??= <String>{};
      userCounts[eventType]!.add(userId);

      // Total event counts
      eventCounts[eventType] = (eventCounts[eventType] ?? 0) + 1;

      // Daily active users
      final dateKey = '${timestamp.year}-${timestamp.month}-${timestamp.day}';
      dailyActiveUsers[dateKey] ??= <String>{};
      dailyActiveUsers[dateKey]!.add(userId);

      // Total unique users
      totalUsers.add(userId);
    }

    // Calculate retention (simplified)
    final averageDailyUsers = dailyActiveUsers.isNotEmpty
        ? dailyActiveUsers.values.map((users) => users.length).reduce((a, b) => a + b) / dailyActiveUsers.length
        : 0.0;

    return AppAnalytics(
      totalUsers: totalUsers.length,
      totalEvents: events.length,
      eventCounts: eventCounts,
      userCounts: userCounts.map((key, value) => MapEntry(key, value.length)),
      dailyActiveUsers: dailyActiveUsers.map((key, value) => MapEntry(key, value.length)),
      averageDailyUsers: averageDailyUsers,
      dateRange: DateRange(start: startDate, end: endDate),
    );
  }

  /// Calculate popular content
  List<PopularContent> _calculatePopularContent(
    List<Map<String, dynamic>> events,
    ContentType? contentType,
    int limit,
  ) {
    final contentCounts = <String, int>{};
    final contentInfo = <String, Map<String, dynamic>>{};

    for (final event in events) {
      final properties = event['properties'] as Map<String, dynamic>? ?? {};
      String? contentId;
      String? contentName;

      // Extract content based on event type
      switch (event['event'] as String) {
        case 'profile':
          contentId = event['targetUserId'] as String?;
          contentName = 'Profile View';
          break;
        case 'gift':
          contentId = properties['giftId'] as String?;
          contentName = properties['giftCategory'] as String?;
          break;
        case 'screenView':
          contentId = properties['screenName'] as String?;
          contentName = contentId;
          break;
      }

      if (contentId != null) {
        contentCounts[contentId] = (contentCounts[contentId] ?? 0) + 1;
        contentInfo[contentId] = {
          'name': contentName ?? contentId,
          'type': event['event'],
        };
      }
    }

    // Sort by popularity and return top items
    final sortedContent = contentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedContent.take(limit).map((entry) {
      final info = contentInfo[entry.key] ?? {};
      return PopularContent(
        id: entry.key,
        name: info['name'] ?? entry.key,
        type: info['type'] ?? 'unknown',
        count: entry.value,
      );
    }).toList();
  }

  /// Calculate engagement metrics
  EngagementMetrics _calculateEngagementMetrics(
    List<Map<String, dynamic>> events,
    DateTime startDate,
    DateTime endDate,
  ) {
    final sessions = <String, List<DateTime>>{};
    final screenTimes = <String, Duration>{};
    
    // Group events by session (simplified)
    for (final event in events) {
      final timestamp = (event['timestamp'] as Timestamp).toDate();
      final dateKey = '${timestamp.year}-${timestamp.month}-${timestamp.day}';
      
      sessions[dateKey] ??= [];
      sessions[dateKey]!.add(timestamp);
    }

    // Calculate metrics
    final totalSessions = sessions.length;
    final totalDays = endDate.difference(startDate).inDays;
    final averageSessionsPerDay = totalDays > 0 ? totalSessions / totalDays : 0.0;
    
    // Calculate average session duration (simplified)
    Duration totalSessionDuration = Duration.zero;
    for (final sessionEvents in sessions.values) {
      if (sessionEvents.length > 1) {
        sessionEvents.sort();
        final sessionDuration = sessionEvents.last.difference(sessionEvents.first);
        totalSessionDuration += sessionDuration;
      }
    }
    
    final averageSessionDuration = totalSessions > 0 
        ? Duration(milliseconds: totalSessionDuration.inMilliseconds ~/ totalSessions)
        : Duration.zero;

    return EngagementMetrics(
      totalSessions: totalSessions,
      averageSessionsPerDay: averageSessionsPerDay,
      averageSessionDuration: averageSessionDuration,
      totalTimeSpent: totalSessionDuration,
      screenTimes: screenTimes,
      dateRange: DateRange(start: startDate, end: endDate),
    );
  }

  /// Calculate funnel analytics
  FunnelAnalytics _calculateFunnelAnalytics(
    List<Map<String, dynamic>> events,
    String funnelName,
  ) {
    final stepCounts = <int, int>{};
    final userProgress = <String, int>{};

    for (final event in events) {
      final properties = event['properties'] as Map<String, dynamic>? ?? {};
      final stepNumber = properties['stepNumber'] as int?;
      final userId = event['userId'] as String;

      if (stepNumber != null) {
        stepCounts[stepNumber] = (stepCounts[stepNumber] ?? 0) + 1;
        
        // Track furthest step for each user
        if (!userProgress.containsKey(userId) || userProgress[userId]! < stepNumber) {
          userProgress[userId] = stepNumber;
        }
      }
    }

    // Calculate conversion rates
    final sortedSteps = stepCounts.keys.toList()..sort();
    final conversions = <FunnelStep>[];
    
    int? previousCount;
    for (final step in sortedSteps) {
      final count = stepCounts[step]!;
      final conversionRate = previousCount != null ? (count / previousCount) * 100 : 100.0;
      
      conversions.add(FunnelStep(
        stepNumber: step,
        userCount: count,
        conversionRate: conversionRate,
      ));
      
      previousCount = count;
    }

    return FunnelAnalytics(
      funnelName: funnelName,
      steps: conversions,
      totalUsers: userProgress.length,
      completionRate: conversions.isNotEmpty && conversions.first.userCount > 0
          ? (conversions.last.userCount / conversions.first.userCount) * 100
          : 0.0,
    );
  }

  /// Cache recent event for offline analytics
  Future<void> _cacheRecentEvent(
    AnalyticsEvent event,
    Map<String, dynamic>? properties,
    DateTime timestamp,
  ) async {
    try {
      final recentEvents = _getRecentEventsFromCache();
      recentEvents.add({
        'event': event.toString().split('.').last,
        'properties': properties ?? {},
        'timestamp': timestamp.toIso8601String(),
      });

      // Keep only last 100 events
      if (recentEvents.length > 100) {
        recentEvents.removeRange(0, recentEvents.length - 100);
      }

      await _cacheService.cacheString(
        'recent_analytics_events',
        jsonEncode(recentEvents),
        expiry: const Duration(hours: 24),
      );
    } catch (e) {
      debugPrint('Error caching recent event: $e');
    }
  }

  /// Get recent events from cache
  List<Map<String, dynamic>> _getRecentEventsFromCache() {
    try {
      final cachedEvents = _cacheService.getCachedString('recent_analytics_events');
      if (cachedEvents != null) {
        final eventsData = jsonDecode(cachedEvents) as List;
        return eventsData.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error getting cached events: $e');
    }
    return [];
  }

  /// Get device info for analytics
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    // In a real app, you'd use device_info_plus package
    return {
      'platform': 'mobile',
      'os': 'unknown',
      'osVersion': 'unknown',
      'deviceModel': 'unknown',
      'appVersion': '1.0.0',
    };
  }

  /// Clear analytics cache
  Future<void> clearAnalyticsCache() async {
    try {
      await _cacheService.removeCachedString('recent_analytics_events');
      debugPrint('Analytics cache cleared');
    } catch (e) {
      debugPrint('Error clearing analytics cache: $e');
    }
  }

  /// Get cached analytics for offline viewing
  Future<UserAnalyticsResult> getCachedAnalytics() async {
    try {
      final recentEvents = _getRecentEventsFromCache();
      if (recentEvents.isEmpty) {
        return UserAnalyticsResult.error('No cached analytics available');
      }

      // Convert cached events to analytics format
      final events = recentEvents.map((event) => {
        'event': event['event'],
        'properties': event['properties'],
        'timestamp': Timestamp.fromDate(DateTime.parse(event['timestamp'])),
        'userId': currentUserId ?? '',
        'platform': 'mobile',
      }).toList();

      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 7));
      final analytics = _calculateUserAnalytics(events, startDate, endDate);

      return UserAnalyticsResult.success(analytics);
    } catch (e) {
      debugPrint('Error getting cached analytics: $e');
      return UserAnalyticsResult.error('Failed to get cached analytics');
    }
  }

  /// Batch track multiple events (for performance)
  Future<void> trackBatchEvents(List<BatchEvent> events) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final batch = _firestore.batch();
      final now = DateTime.now();

      for (final event in events) {
        final eventData = {
          'userId': userId,
          'event': event.event.toString().split('.').last,
          'properties': event.properties ?? {},
          'targetUserId': event.targetUserId,
          'timestamp': Timestamp.fromDate(event.timestamp ?? now),
          'platform': 'mobile',
          'appVersion': '1.0.0',
          'deviceInfo': await _getDeviceInfo(),
        };

        final docRef = _firestore.collection('analytics_events').doc();
        batch.set(docRef, eventData);
      }

      await batch.commit();
      debugPrint('Batch tracked ${events.length} events');
    } catch (e) {
      debugPrint('Error batch tracking events: $e');
    }
  }

  /// Set user properties for analytics
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      await _firestore.collection('user_properties').doc(userId).set({
        'userId': userId,
        'properties': properties,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));

      debugPrint('User properties set: ${properties.keys.join(', ')}');
    } catch (e) {
      debugPrint('Error setting user properties: $e');
    }
  }

  /// Track custom metrics
  Future<void> trackCustomMetric({
    required String metricName,
    required double value,
    Map<String, dynamic>? properties,
  }) async {
    await trackEvent(
      AnalyticsEvent.customMetric,
      properties: {
        'metricName': metricName,
        'value': value,
        'unit': properties?['unit'] ?? 'count',
        ...?properties,
      },
    );
  }

  /// Track performance metrics
  Future<void> trackPerformance({
    required String operation,
    required Duration duration,
    bool? success,
    String? errorMessage,
  }) async {
    await trackEvent(
      AnalyticsEvent.performance,
      properties: {
        'operation': operation,
        'duration': duration.inMilliseconds,
        'success': success ?? true,
        'errorMessage': errorMessage,
      },
    );
  }

  /// Track revenue events (for financial analytics)
  Future<void> trackRevenue({
    required double amount,
    required String currency,
    required String source, // 'subscription', 'gift', etc.
    String? transactionId,
    Map<String, dynamic>? properties,
  }) async {
    await trackEvent(
      AnalyticsEvent.revenue,
      properties: {
        'amount': amount,
        'currency': currency,
        'source': source,
        'transactionId': transactionId,
        ...?properties,
      },
    );
  }

  /// Export analytics data (admin function)
  Future<AnalyticsExportResult> exportAnalytics({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? eventTypes,
    ExportFormat format = ExportFormat.json,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return AnalyticsExportResult.error('No user signed in');
      }

      // Check export permission
      final userResult = await _userService.getCurrentUser();
      if (!userResult.success || userResult.user == null) {
        return AnalyticsExportResult.error('Failed to get user data');
      }

      final user = userResult.user!;
      if (!user.canExportData) {
        return AnalyticsExportResult.error('Access denied - export permission required');
      }

      // Build query
      Query query = _firestore
          .collection('analytics_events')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

      if (eventTypes != null && eventTypes.isNotEmpty) {
        query = query.where('event', whereIn: eventTypes);
      }

       final allEvents = <Map<String, dynamic>>[];
DocumentSnapshot? lastDoc;

do {
  Query batchQuery = query.orderBy('timestamp').limit(1000);
  if (lastDoc != null) {
    batchQuery = batchQuery.startAfterDocument(lastDoc);
  }

  final querySnapshot = await batchQuery.get();
  if (querySnapshot.docs.isEmpty) break;

  allEvents.addAll(querySnapshot.docs.map((doc) => {
    'id': doc.id,
    ...doc.data() as Map<String, dynamic>
  }));

  // Set lastDoc to null if this was the last batch
  lastDoc = querySnapshot.docs.length == 1000 ? querySnapshot.docs.last : null;
  
} while (lastDoc != null);
      // Format data based on export format
      String exportData;
      switch (format) {
        case ExportFormat.json:
          exportData = jsonEncode(allEvents);
          break;
        case ExportFormat.csv:
          exportData = _convertToCsv(allEvents);
          break;
      }

      // In a real app, you'd upload to cloud storage and return download URL
      debugPrint('Analytics exported: ${allEvents.length} events');
      return AnalyticsExportResult.success(
        data: exportData,
        recordCount: allEvents.length,
        format: format,
      );
    } catch (e) {
      debugPrint('Error exporting analytics: $e');
      return AnalyticsExportResult.error('Failed to export analytics');
    }
  }

  /// Convert events to CSV format
  String _convertToCsv(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return '';

    // Get all unique keys for CSV headers
    final allKeys = <String>{};
    for (final event in events) {
      allKeys.addAll(event.keys);
      if (event['properties'] is Map) {
        final props = event['properties'] as Map<String, dynamic>;
        allKeys.addAll(props.keys.map((key) => 'prop_$key'));
      }
    }

    final headers = allKeys.toList()..sort();
    final csvLines = <String>[];
    
    // Add header row
    csvLines.add(headers.map((h) => '"$h"').join(','));

    // Add data rows
    for (final event in events) {
      final row = headers.map((header) {
        dynamic value;
        if (header.startsWith('prop_')) {
          final propKey = header.substring(5);
          final props = event['properties'] as Map<String, dynamic>? ?? {};
          value = props[propKey];
        } else {
          value = event[header];
        }

        if (value is Timestamp) {
          value = value.toDate().toIso8601String();
        }

        return '"${value?.toString().replaceAll('"', '""') ?? ''}"';
      }).join(',');
      
      csvLines.add(row);
    }

    return csvLines.join('\n');
  }

  /// Dispose service
  void dispose() {
    debugPrint('AnalyticsService disposed');
  }
}

/// Analytics event types
enum AnalyticsEvent {
  appStart,
  appBackground,
  appForeground,
  screenView,
  userInteraction,
  messaging,
  subscription,
  gift,
  profile,
  discovery,
  funnel,
  customMetric,
  performance,
  revenue,
  error,
}

/// Message analytics events
enum MessageAnalyticsEvent {
  messageSent,
  messageReceived,
  messageRead,
  messageDeleted,
  conversationStarted,
  conversationEnded,
  typingStarted,
  typingStopped,
}

/// Subscription analytics events
enum SubscriptionAnalyticsEvent {
  subscriptionStarted,
  subscriptionCancelled,
  subscriptionRenewed,
  subscriptionExpired,
  subscriptionUpgraded,
  subscriptionDowngraded,
}

/// Gift analytics events
enum GiftAnalyticsEvent {
  giftSent,
  giftReceived,
  giftOpened,
  giftStoreViewed,
  giftCategoryViewed,
}

/// Profile analytics events
enum ProfileAnalyticsEvent {
  profileViewed,
  profileUpdated,
  photoUploaded,
  photoDeleted,
  profileVerified,
}

/// Discovery analytics events
enum DiscoveryAnalyticsEvent {
  discoverySearched,
  userSwiped,
  userLiked,
  userPassed,
  filterApplied,
  locationUpdated,
}

/// Content types for popular content tracking
enum ContentType {
  screen,
  gift,
  profile,
  feature,
}

/// Export formats
enum ExportFormat {
  json,
  csv,
}

/// Batch event for batch tracking
class BatchEvent {
  final AnalyticsEvent event;
  final Map<String, dynamic>? properties;
  final String? targetUserId;
  final DateTime? timestamp;

  BatchEvent({
    required this.event,
    this.properties,
    this.targetUserId,
    this.timestamp,
  });
}

/// Date range helper
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});

  Duration get duration => end.difference(start);
  
  int get days => duration.inDays;
  
  String get formatted => '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
}

/// User analytics data
class UserAnalytics {
  final int totalEvents;
  final int sessionCount;
  final Map<String, int> eventCounts;
  final Map<String, int> dailyActivity;
  final Map<String, int> mostViewedScreens;
  final double averageEventsPerDay;
  final DateRange dateRange;

  UserAnalytics({
    required this.totalEvents,
    required this.sessionCount,
    required this.eventCounts,
    required this.dailyActivity,
    required this.mostViewedScreens,
    required this.averageEventsPerDay,
    required this.dateRange,
  });

  String get formattedAverageEvents => averageEventsPerDay.toStringAsFixed(1);
  
  String? get mostUsedFeature {
    if (eventCounts.isEmpty) return null;
    return eventCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  String? get favoriteScreen {
    if (mostViewedScreens.isEmpty) return null;
    return mostViewedScreens.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}

/// App-wide analytics data
class AppAnalytics {
  final int totalUsers;
  final int totalEvents;
  final Map<String, int> eventCounts;
  final Map<String, int> userCounts;
  final Map<String, int> dailyActiveUsers;
  final double averageDailyUsers;
  final DateRange dateRange;

  AppAnalytics({
    required this.totalUsers,
    required this.totalEvents,
    required this.eventCounts,
    required this.userCounts,
    required this.dailyActiveUsers,
    required this.averageDailyUsers,
    required this.dateRange,
  });

  String get formattedAverageDailyUsers => averageDailyUsers.toStringAsFixed(0);
  
  double get eventsPerUser => totalUsers > 0 ? totalEvents / totalUsers : 0.0;
  
  String get formattedEventsPerUser => eventsPerUser.toStringAsFixed(1);
}

/// Popular content item
class PopularContent {
  final String id;
  final String name;
  final String type;
  final int count;

  PopularContent({
    required this.id,
    required this.name,
    required this.type,
    required this.count,
  });
}

/// Engagement metrics
class EngagementMetrics {
  final int totalSessions;
  final double averageSessionsPerDay;
  final Duration averageSessionDuration;
  final Duration totalTimeSpent;
  final Map<String, Duration> screenTimes;
  final DateRange dateRange;

  EngagementMetrics({
    required this.totalSessions,
    required this.averageSessionsPerDay,
    required this.averageSessionDuration,
    required this.totalTimeSpent,
    required this.screenTimes,
    required this.dateRange,
  });

  String get formattedAverageSessionDuration {
    final minutes = averageSessionDuration.inMinutes;
    final seconds = averageSessionDuration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  String get formattedTotalTime {
    final hours = totalTimeSpent.inHours;
    final minutes = (totalTimeSpent.inMinutes % 60);
    return '${hours}h ${minutes}m';
  }
}

/// Funnel step data
class FunnelStep {
  final int stepNumber;
  final int userCount;
  final double conversionRate;

  FunnelStep({
    required this.stepNumber,
    required this.userCount,
    required this.conversionRate,
  });

  String get formattedConversionRate => '${conversionRate.toStringAsFixed(1)}%';
}

/// Funnel analytics data
class FunnelAnalytics {
  final String funnelName;
  final List<FunnelStep> steps;
  final int totalUsers;
  final double completionRate;

  FunnelAnalytics({
    required this.funnelName,
    required this.steps,
    required this.totalUsers,
    required this.completionRate,
  });

  String get formattedCompletionRate => '${completionRate.toStringAsFixed(1)}%';
  
  int get dropOffCount => steps.isNotEmpty 
      ? steps.first.userCount - steps.last.userCount 
      : 0;
}

/// Analytics result classes
class UserAnalyticsResult {
  final bool success;
  final UserAnalytics? analytics;
  final String? error;

  const UserAnalyticsResult._({
    required this.success,
    this.analytics,
    this.error,
  });

  factory UserAnalyticsResult.success(UserAnalytics analytics) {
    return UserAnalyticsResult._(success: true, analytics: analytics);
  }

  factory UserAnalyticsResult.error(String error) {
    return UserAnalyticsResult._(success: false, error: error);
  }
}

class AppAnalyticsResult {
  final bool success;
  final AppAnalytics? analytics;
  final String? error;

  const AppAnalyticsResult._({
    required this.success,
    this.analytics,
    this.error,
  });

  factory AppAnalyticsResult.success(AppAnalytics analytics) {
    return AppAnalyticsResult._(success: true, analytics: analytics);
  }

  factory AppAnalyticsResult.error(String error) {
    return AppAnalyticsResult._(success: false, error: error);
  }
}

class PopularContentResult {
  final bool success;
  final List<PopularContent> content;
  final String? error;

  const PopularContentResult._({
    required this.success,
    this.content = const [],
    this.error,
  });

  factory PopularContentResult.success(List<PopularContent> content) {
    return PopularContentResult._(success: true, content: content);
  }

  factory PopularContentResult.error(String error) {
    return PopularContentResult._(success: false, error: error);
  }
}

class EngagementMetricsResult {
  final bool success;
  final EngagementMetrics? metrics;
  final String? error;

  const EngagementMetricsResult._({
    required this.success,
    this.metrics,
    this.error,
  });

  factory EngagementMetricsResult.success(EngagementMetrics metrics) {
    return EngagementMetricsResult._(success: true, metrics: metrics);
  }

  factory EngagementMetricsResult.error(String error) {
    return EngagementMetricsResult._(success: false, error: error);
  }
}

class FunnelAnalyticsResult {
  final bool success;
  final FunnelAnalytics? analytics;
  final String? error;

  const FunnelAnalyticsResult._({
    required this.success,
    this.analytics,
    this.error,
  });

  factory FunnelAnalyticsResult.success(FunnelAnalytics analytics) {
    return FunnelAnalyticsResult._(success: true, analytics: analytics);
  }

  factory FunnelAnalyticsResult.error(String error) {
    return FunnelAnalyticsResult._(success: false, error: error);
  }
}

class AnalyticsExportResult {
  final bool success;
  final String? data;
  final int recordCount;
  final ExportFormat format;
  final String? error;

  const AnalyticsExportResult._({
    required this.success,
    this.data,
    this.recordCount = 0,
    this.format = ExportFormat.json,
    this.error,
  });

  factory AnalyticsExportResult.success({
    required String data,
    required int recordCount,
    required ExportFormat format,
  }) {
    return AnalyticsExportResult._(
      success: true,
      data: data,
      recordCount: recordCount,
      format: format,
    );
  }

  factory AnalyticsExportResult.error(String error) {
    return AnalyticsExportResult._(success: false, error: error);
  }
}