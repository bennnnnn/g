import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import '../../models/user_model.dart';
import '../../models/enums.dart';
import 'user_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final UserService _userService = UserService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Initialize notification system
  Future<bool> initialize() async {
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Initialize Firebase messaging
      await _initializeFirebaseMessaging();
      
      // Request permissions
      await _requestPermissions();
      
      // Get and save FCM token
      await _updateFCMToken();
      
      return true;
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
      return false;
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );
  }

  /// Initialize Firebase messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle notification taps when app is terminated or in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Handle initial message if app was opened from notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    // Request Firebase messaging permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');
  }

  /// Update FCM token for current user
  Future<void> _updateFCMToken() async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      // Store FCM token in user preferences
      await _firestore.collection('users').doc(userId).update({
        'preferences.fcmToken': token,
        'preferences.lastTokenUpdate': Timestamp.fromDate(DateTime.now()),
      });

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _firestore.collection('users').doc(userId).update({
          'preferences.fcmToken': newToken,
          'preferences.lastTokenUpdate': Timestamp.fromDate(DateTime.now()),
        });
      });

      debugPrint('FCM token updated: $token');
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  /// Send message notification
  Future<void> sendMessageNotification({
    required String senderId,
    required String receiverId,
    required String messageContent,
    required String conversationId,
  }) async {
    try {
      // Get sender info
      final senderResult = await _userService.getUserById(senderId);
      if (!senderResult.success || senderResult.user == null) return;

      final sender = senderResult.user!;
      final senderName = sender.name ?? 'Someone';

      // Get receiver info to check notification preferences
      final receiverResult = await _userService.getUserById(receiverId);
      if (!receiverResult.success || receiverResult.user == null) return;

      final receiver = receiverResult.user!;

      // Check if receiver wants message notifications
      if (!_shouldSendNotification(receiver, NotificationType.message)) {
        return;
      }

      // Create notification data
      final notification = NotificationModel(
        id: '',
        recipientId: receiverId,
        senderId: senderId,
        type: NotificationType.message,
        title: '💬 New message from $senderName',
        message: messageContent.length > 100 
            ? '${messageContent.substring(0, 100)}...' 
            : messageContent,
        data: {
          'conversationId': conversationId,
          'senderId': senderId,
          'senderName': senderName,
          'type': 'message',
        },
        createdAt: DateTime.now(),
      );

      // Save notification to database
      await _saveNotification(notification);

      // Send push notification
      await _sendPushNotification(notification, receiver);

    } catch (e) {
      debugPrint('Error sending message notification: $e');
    }
  }

  /// Send gift notification
  Future<void> sendGiftNotification({
    required String senderId,
    required String receiverId,
    required String giftName,
    required String giftImageUrl,
    String? conversationId,
    String? personalMessage,
  }) async {
    try {
      // Get sender info
      final senderResult = await _userService.getUserById(senderId);
      if (!senderResult.success || senderResult.user == null) return;

      final sender = senderResult.user!;
      final senderName = sender.name ?? 'Someone';

      // Get receiver info
      final receiverResult = await _userService.getUserById(receiverId);
      if (!receiverResult.success || receiverResult.user == null) return;

      final receiver = receiverResult.user!;

      // Check notification preferences
      if (!_shouldSendNotification(receiver, NotificationType.gift)) {
        return;
      }

      // Create notification
      final notification = NotificationModel(
        id: '',
        recipientId: receiverId,
        senderId: senderId,
        type: NotificationType.gift,
        title: '🎁 You received a gift!',
        message: personalMessage != null 
            ? '$senderName sent you $giftName: "$personalMessage"'
            : '$senderName sent you $giftName',
        data: {
          'giftName': giftName,
          'giftImageUrl': giftImageUrl,
          'senderId': senderId,
          'senderName': senderName,
          'conversationId': conversationId,
          'personalMessage': personalMessage,
          'type': 'gift',
        },
        createdAt: DateTime.now(),
      );

      await _saveNotification(notification);
      await _sendPushNotification(notification, receiver);

    } catch (e) {
      debugPrint('Error sending gift notification: $e');
    }
  }

  /// Send profile view notification
  Future<void> sendProfileViewNotification({
    required String viewerId,
    required String viewedUserId,
  }) async {
    try {
      // Get viewer info
      final viewerResult = await _userService.getUserById(viewerId);
      if (!viewerResult.success || viewerResult.user == null) return;

      final viewer = viewerResult.user!;
      final viewerName = viewer.name ?? 'Someone';

      // Get viewed user info
      final viewedResult = await _userService.getUserById(viewedUserId);
      if (!viewedResult.success || viewedResult.user == null) return;

      final viewedUser = viewedResult.user!;

      // Check notification preferences
      if (!_shouldSendNotification(viewedUser, NotificationType.profileView)) {
        return;
      }

      // Create notification
      final notification = NotificationModel(
        id: '',
        recipientId: viewedUserId,
        senderId: viewerId,
        type: NotificationType.profileView,
        title: '👀 Someone viewed your profile',
        message: '$viewerName checked out your profile',
        data: {
          'viewerId': viewerId,
          'viewerName': viewerName,
          'type': 'profile_view',
        },
        createdAt: DateTime.now(),
      );

      await _saveNotification(notification);
      await _sendPushNotification(notification, viewedUser);

    } catch (e) {
      debugPrint('Error sending profile view notification: $e');
    }
  }

  /// Send subscription notification
  Future<void> sendSubscriptionNotification({
    required String userId,
    required SubscriptionPlan plan,
    required SubscriptionNotificationType type,
  }) async {
    try {
      final userResult = await _userService.getUserById(userId);
      if (!userResult.success || userResult.user == null) return;

      final user = userResult.user!;

      String title;
      String message;
      
      switch (type) {
        case SubscriptionNotificationType.activated:
          title = '🎉 ${plan.displayName} activated!';
          message = 'You now have unlimited messaging. Start connecting!';
          break;
        case SubscriptionNotificationType.expiring:
          title = '⏰ ${plan.displayName} expiring soon';
          message = 'Your subscription expires in 24 hours. Renew to keep unlimited messaging.';
          break;
        case SubscriptionNotificationType.expired:
          title = '😔 ${plan.displayName} expired';
          message = 'Your unlimited messaging has ended. Upgrade to continue conversations.';
          break;
        case SubscriptionNotificationType.renewed:
          title = '🔄 ${plan.displayName} renewed';
          message = 'Your subscription has been renewed. Continue messaging!';
          break;
      }

      final notification = NotificationModel(
        id: '',
        recipientId: userId,
        senderId: '',
        type: NotificationType.subscription,
        title: title,
        message: message,
        data: {
          'subscriptionPlan': plan.toString().split('.').last,
          'subscriptionType': type.toString().split('.').last,
          'type': 'subscription',
        },
        createdAt: DateTime.now(),
      );

      await _saveNotification(notification);
      await _sendPushNotification(notification, user);

    } catch (e) {
      debugPrint('Error sending subscription notification: $e');
    }
  }

  /// Send marketing notification
  Future<void> sendMarketingNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final userResult = await _userService.getUserById(userId);
      if (!userResult.success || userResult.user == null) return;

      final user = userResult.user!;

      // Check marketing notification preferences
      if (!_shouldSendNotification(user, NotificationType.marketing)) {
        return;
      }

      final notification = NotificationModel(
        id: '',
        recipientId: userId,
        senderId: '',
        type: NotificationType.marketing,
        title: title,
        message: message,
        data: {
          'type': 'marketing',
          ...?data,
        },
        createdAt: DateTime.now(),
      );

      await _saveNotification(notification);
      await _sendPushNotification(notification, user);

    } catch (e) {
      debugPrint('Error sending marketing notification: $e');
    }
  }

  /// Get user notifications with pagination
  Future<NotificationsResult> getUserNotifications({
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return NotificationsResult.error('No user signed in');
      }

      Query query = _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      final notifications = querySnapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();

      return NotificationsResult.success(
        notifications: notifications,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return NotificationsResult.error('Failed to load notifications');
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      final now = Timestamp.fromDate(DateTime.now());

      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': now,
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    try {
      final userId = currentUserId;
      if (userId == null) return 0;

      final querySnapshot = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting unread notification count: $e');
      return 0;
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Update notification preferences
  Future<void> updateNotificationPreferences({
    bool? messages,
    bool? gifts,
    bool? profileViews,
    bool? subscriptions,
    bool? marketing,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final Map<String, dynamic> preferences = {};
      
      if (messages != null) preferences['preferences.notificationPreferences.messages'] = messages;
      if (gifts != null) preferences['preferences.notificationPreferences.gifts'] = gifts;
      if (profileViews != null) preferences['preferences.notificationPreferences.profileViews'] = profileViews;
      if (subscriptions != null) preferences['preferences.notificationPreferences.subscriptions'] = subscriptions;
      if (marketing != null) preferences['preferences.notificationPreferences.marketing'] = marketing;

      await _firestore.collection('users').doc(userId).update(preferences);
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
    }
  }

  /// Save notification to database
  Future<void> _saveNotification(NotificationModel notification) async {
    await _firestore.collection('notifications').add(notification.toFirestore());
  }

  /// Send push notification
  Future<void> _sendPushNotification(NotificationModel notification, UserModel user) async {
    try {
      // Get user's FCM token from preferences
      final fcmToken = user.preferences?['fcmToken'] as String?;
      if (fcmToken == null) return;

      // TODO: Send push notification via your backend API
      // This would typically involve calling your server API that sends FCM messages
      // For now, just log the notification
      debugPrint('Sending push notification: ${notification.title}');
      
      // In production, you would:
      // 1. Call your backend API
      // 2. Backend sends FCM message using admin SDK
      // 3. Include notification payload and data
      
    } catch (e) {
      debugPrint('Error sending push notification: $e');
    }
  }

  /// Check if notification should be sent based on user preferences
  bool _shouldSendNotification(UserModel user, NotificationType type) {
    final preferences = user.preferences?['notificationPreferences'] as Map<String, dynamic>?;
    if (preferences == null) return true; // Default to enabled

    switch (type) {
      case NotificationType.message:
        return preferences['messages'] ?? true;
      case NotificationType.gift:
        return preferences['gifts'] ?? true;
      case NotificationType.profileView:
        return preferences['profileViews'] ?? true;
      case NotificationType.subscription:
        return preferences['subscriptions'] ?? true;
      case NotificationType.marketing:
        return preferences['marketing'] ?? false; // Default to disabled
      default:
        return true;
    }
  }

  /// Handle background message
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Background message: ${message.notification?.title}');
  }

  /// Handle foreground message
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
    
    // Show local notification when app is in foreground
    _showLocalNotification(message);
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    
    // Navigate based on notification type
    final type = message.data['type'] as String?;
    switch (type) {
      case 'message':
        // Navigate to conversation
        final conversationId = message.data['conversationId'] as String?;
        if (conversationId != null) {
          // TODO: Navigate to conversation screen
        }
        break;
      case 'gift':
        // Navigate to gift/conversation
        final conversationId = message.data['conversationId'] as String?;
        if (conversationId != null) {
          // TODO: Navigate to conversation screen
        }
        break;
      default:
        // Navigate to notifications screen
        // TODO: Navigate to notifications screen
        break;
    }
  }

  /// Handle local notification tap
  void _handleLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      debugPrint('Local notification tapped: $data');
      
      // Handle navigation based on payload
      final type = data['type'] as String?;
      switch (type) {
        case 'message':
          final conversationId = data['conversationId'] as String?;
          if (conversationId != null) {
            // TODO: Navigate to conversation
          }
          break;
        // Handle other types...
      }
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'dating_app_channel',
      'Dating App Notifications',
      channelDescription: 'Notifications for dating app',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Stream notifications for real-time updates
  Stream<List<NotificationModel>> streamUserNotifications() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
  }

  /// Dispose service
  void dispose() {
    // Clean up any resources if needed
  }
}

/// Notification model
class NotificationModel {
  final String id;
  final String recipientId;
  final String senderId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.type,
    required this.title,
    required this.message,
    this.data = const {},
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NotificationModel(
      id: doc.id,
      recipientId: data['recipientId'] ?? '',
      senderId: data['senderId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${data['type']}',
        orElse: () => NotificationType.other,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      isRead: data['isRead'] ?? false,
      readAt: data['readAt'] != null ? (data['readAt'] as Timestamp).toDate() : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'recipientId': recipientId,
      'senderId': senderId,
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'data': data,
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Notification types
enum NotificationType {
  message,
  gift,
  profileView,
  subscription,
  marketing,
  other,
}

/// Subscription notification types
enum SubscriptionNotificationType {
  activated,
  expiring,
  expired,
  renewed,
}

/// Notifications result
class NotificationsResult {
  final bool success;
  final List<NotificationModel> notifications;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? error;

  const NotificationsResult._({
    required this.success,
    this.notifications = const [],
    this.lastDocument,
    this.hasMore = false,
    this.error,
  });

  factory NotificationsResult.success({
    required List<NotificationModel> notifications,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
  }) {
    return NotificationsResult._(
      success: true,
      notifications: notifications,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  factory NotificationsResult.error(String error) {
    return NotificationsResult._(success: false, error: error);
  }
}