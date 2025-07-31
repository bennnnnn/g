import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/enums.dart';
import 'user_service.dart';
import 'analytics_service.dart';
import 'notification_service.dart';
import 'cache_service.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final NotificationService _notificationService = NotificationService();
  final CacheService _cacheService = CacheService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      final userResult = await _userService.getCurrentUser();
      if (!userResult.success || userResult.user == null) return false;

      return userResult.user!.isAdmin;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  /// Verify admin access (throws if not admin)
  Future<void> _verifyAdmin() async {
    if (!await isAdmin()) {
      throw Exception('Admin access required');
    }
  }

  /// Get all users with admin filters
  Future<AdminUsersResult> getAllUsers({
    String? searchQuery,
    SubscriptionPlan? subscriptionPlan,
    bool? isBlocked,
    bool? isVerified,
    DateTime? createdAfter,
    DateTime? lastActiveAfter,
    AdminSortBy sortBy = AdminSortBy.newest,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      await _verifyAdmin();

      // Build query
      Query query = _firestore.collection('users');

      // Apply filters
      if (subscriptionPlan != null) {
        query = query.where('subscriptionPlan', isEqualTo: subscriptionPlan.toString().split('.').last);
      }

      if (isBlocked != null) {
        query = query.where('isBlocked', isEqualTo: isBlocked);
      }

      if (isVerified != null) {
        query = query.where('isVerified', isEqualTo: isVerified);
      }

      if (createdAfter != null) {
        query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(createdAfter));
      }

      if (lastActiveAfter != null) {
        query = query.where('lastActiveAt', isGreaterThan: Timestamp.fromDate(lastActiveAfter));
      }

      // Add sorting
      switch (sortBy) {
        case AdminSortBy.newest:
          query = query.orderBy('createdAt', descending: true);
          break;
        case AdminSortBy.lastActive:
          query = query.orderBy('lastActiveAt', descending: true);
          break;
        case AdminSortBy.name:
          query = query.orderBy('name', descending: false);
          break;
      }

      // Add pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      var users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Apply search filter (client-side)
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.toLowerCase();
        users = users.where((user) =>
            user.name?.toLowerCase().contains(query) == true ||
            user.email?.toLowerCase().contains(query) == true ||
            user.phoneNumber.contains(query)).toList();
      }

      debugPrint('Admin: Loaded ${users.length} users');
      return AdminUsersResult.success(
        users: users,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error getting users: $e');
      return AdminUsersResult.error('Failed to get users: ${e.toString()}');
    }
  }

  /// Block/unblock user
  Future<AdminActionResult> toggleUserBlock({
    required String userId,
    required bool block,
    String? reason,
  }) async {
    try {
      await _verifyAdmin();
      final adminId = currentUserId!;

      // Update user
      await _firestore.collection('users').doc(userId).update({
        'isBlocked': block,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        if (block) ...{
          'blockedAt': Timestamp.fromDate(DateTime.now()),
          'blockedBy': adminId,
          'blockReason': reason ?? 'Admin blocked user',
        } else ...{
          'unblockedAt': Timestamp.fromDate(DateTime.now()),
          'unblockedBy': adminId,
        }
      });

      // Log action
      await _logAdminAction(
        action: block ? 'block_user' : 'unblock_user',
        targetUserId: userId,
        details: reason,
      );

      // Clear cache
      await _cacheService.removeCachedUser(userId);

      debugPrint('Admin: User ${block ? 'blocked' : 'unblocked'}: $userId');
      return AdminActionResult.success('User ${block ? 'blocked' : 'unblocked'} successfully');
    } catch (e) {
      debugPrint('Error toggling user block: $e');
      return AdminActionResult.error('Failed to ${block ? 'block' : 'unblock'} user');
    }
  }

  /// Verify/unverify user
  Future<AdminActionResult> toggleUserVerification({
    required String userId,
    required bool verify,
  }) async {
    try {
      await _verifyAdmin();
      final adminId = currentUserId!;

      // Update user
      await _firestore.collection('users').doc(userId).update({
        'isVerified': verify,
        'isPhotoVerified': verify, // Auto photo verify when admin verifies
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        if (verify) ...{
          'verifiedAt': Timestamp.fromDate(DateTime.now()),
          'verifiedBy': adminId,
        }
      });

      // Log action
      await _logAdminAction(
        action: verify ? 'verify_user' : 'unverify_user',
        targetUserId: userId,
      );

      // Clear cache
      await _cacheService.removeCachedUser(userId);

      debugPrint('Admin: User ${verify ? 'verified' : 'unverified'}: $userId');
      return AdminActionResult.success('User ${verify ? 'verified' : 'unverified'} successfully');
    } catch (e) {
      debugPrint('Error toggling user verification: $e');
      return AdminActionResult.error('Failed to ${verify ? 'verify' : 'unverify'} user');
    }
  }

  /// Make user admin or remove admin
  Future<AdminActionResult> toggleAdminStatus({
    required String userId,
    required bool makeAdmin,
  }) async {
    try {
      await _verifyAdmin();
      final currentAdminId = currentUserId!;

      // Can't change own admin status
      if (userId == currentAdminId) {
        return AdminActionResult.error('Cannot change your own admin status');
      }

      final now = DateTime.now();

      // Update user
      await _firestore.collection('users').doc(userId).update({
        'isAdmin': makeAdmin,
        'updatedAt': Timestamp.fromDate(now),
        if (makeAdmin) ...{
          'adminSince': Timestamp.fromDate(now),
          'adminPromotedBy': currentAdminId,
        } else ...{
          'adminSince': null,
          'adminRemovedBy': currentAdminId,
          'adminRemovedAt': Timestamp.fromDate(now),
        }
      });

      // Log action
      await _logAdminAction(
        action: makeAdmin ? 'promote_admin' : 'remove_admin',
        targetUserId: userId,
      );

      // Clear cache
      await _cacheService.removeCachedUser(userId);

      debugPrint('Admin: User ${makeAdmin ? 'promoted to' : 'removed from'} admin: $userId');
      return AdminActionResult.success('User ${makeAdmin ? 'promoted to admin' : 'removed from admin'} successfully');
    } catch (e) {
      debugPrint('Error toggling admin status: $e');
      return AdminActionResult.error('Failed to update admin status');
    }
  }

  /// Send broadcast notification to users
  Future<AdminActionResult> sendBroadcast({
    required String title,
    required String message,
    List<String>? targetUserIds, // If null, sends to all active users
    bool? premiumOnly,
    bool? verifiedOnly,
  }) async {
    try {
      await _verifyAdmin();

      // Get target users
      List<String> recipientIds;
      if (targetUserIds != null) {
        recipientIds = targetUserIds;
      } else {
        recipientIds = await _getBroadcastUsers(
          premiumOnly: premiumOnly,
          verifiedOnly: verifiedOnly,
        );
      }

      if (recipientIds.isEmpty) {
        return AdminActionResult.error('No users match the broadcast criteria');
      }

      // Create broadcast record
      final broadcastId = _firestore.collection('broadcasts').doc().id;
      await _firestore.collection('broadcasts').doc(broadcastId).set({
        'id': broadcastId,
        'title': title,
        'message': message,
        'senderId': currentUserId,
        'recipientIds': recipientIds,
        'premiumOnly': premiumOnly ?? false,
        'verifiedOnly': verifiedOnly ?? false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'status': 'sending',
        'totalRecipients': recipientIds.length,
      });

      // Send notifications (in batches to avoid overwhelming)
      int sentCount = 0;
      const batchSize = 50;

      for (int i = 0; i < recipientIds.length; i += batchSize) {
        final batch = recipientIds.skip(i).take(batchSize).toList();
        
        for (final userId in batch) {
          try {
            await _notificationService.sendMarketingNotification(
              userId: userId,
              title: title,
              message: message,
              data: {'broadcastId': broadcastId},
            );
            sentCount++;
          } catch (e) {
            debugPrint('Failed to send to $userId: $e');
          }
        }

        // Small delay between batches
        if (i + batchSize < recipientIds.length) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      // Update broadcast status
      await _firestore.collection('broadcasts').doc(broadcastId).update({
        'status': 'completed',
        'sentCount': sentCount,
        'completedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Log action
      await _logAdminAction(
        action: 'send_broadcast',
        details: 'Sent to $sentCount users: $title',
      );

      debugPrint('Admin: Broadcast sent to $sentCount users');
      return AdminActionResult.success('Broadcast sent to $sentCount users');
    } catch (e) {
      debugPrint('Error sending broadcast: $e');
      return AdminActionResult.error('Failed to send broadcast');
    }
  }

  /// Get app statistics for dashboard
  Future<AdminStatsResult> getDashboardStats() async {
    try {
      await _verifyAdmin();

      // Get basic user stats
      final allUsersQuery = await _firestore.collection('users').get();
      final totalUsers = allUsersQuery.docs.length;

      final activeUsersQuery = await _firestore
          .collection('users')
          .where('lastActiveAt', isGreaterThan: 
              Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7))))
          .get();
      final activeUsers = activeUsersQuery.docs.length;

      final premiumUsersQuery = await _firestore
          .collection('users')
          .where('subscriptionPlan', whereNotIn: ['free'])
          .get();
      final premiumUsers = premiumUsersQuery.docs.length;

      final blockedUsersQuery = await _firestore
          .collection('users')
          .where('isBlocked', isEqualTo: true)
          .get();
      final blockedUsers = blockedUsersQuery.docs.length;

      // Get today's messages
      final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0);
      final todayMessagesQuery = await _firestore
          .collection('messages')
          .where('sentAt', isGreaterThan: Timestamp.fromDate(todayStart))
          .get();
      final todayMessages = todayMessagesQuery.docs.length;

      // Get pending reports
      final pendingReportsQuery = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .get();
      final pendingReports = pendingReportsQuery.docs.length;

      // Get subscription revenue (last 30 days)
      final last30Days = DateTime.now().subtract(const Duration(days: 30));
      final paymentsQuery = await _firestore
          .collection('payments')
          .where('type', isEqualTo: 'subscription')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(last30Days))
          .where('status', isEqualTo: 'completed')
          .get();

      double subscriptionRevenue = 0.0;
      for (final doc in paymentsQuery.docs) {
        final data = doc.data();
        subscriptionRevenue += (data['amount'] ?? 0.0).toDouble();
      }

      // Get gift revenue (last 30 days)
      final giftPaymentsQuery = await _firestore
          .collection('payments')
          .where('type', isEqualTo: 'gift')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(last30Days))
          .where('status', isEqualTo: 'completed')
          .get();

      double giftRevenue = 0.0;
      for (final doc in giftPaymentsQuery.docs) {
        final data = doc.data();
        giftRevenue += (data['amount'] ?? 0.0).toDouble();
      }

      final stats = AdminStats(
        totalUsers: totalUsers,
        activeUsers: activeUsers,
        premiumUsers: premiumUsers,
        blockedUsers: blockedUsers,
        todayMessages: todayMessages,
        pendingReports: pendingReports,
        subscriptionRevenue: subscriptionRevenue,
        giftRevenue: giftRevenue,
        lastUpdated: DateTime.now(),
      );

      return AdminStatsResult.success(stats);
    } catch (e) {
      debugPrint('Error getting dashboard stats: $e');
      return AdminStatsResult.error('Failed to get dashboard statistics');
    }
  }

  /// Get user reports
  Future<ReportsResult> getReports({
    String? status = 'pending',
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      await _verifyAdmin();

      Query query = _firestore.collection('reports');

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final querySnapshot = await query.get();
      final reports = querySnapshot.docs.map((doc) => 
          Report.fromFirestore(doc)).toList();

      return ReportsResult.success(
        reports: reports,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error getting reports: $e');
      return ReportsResult.error('Failed to get reports');
    }
  }

  /// Resolve a report
  Future<AdminActionResult> resolveReport({
    required String reportId,
    required String action, // 'resolved', 'dismissed'
    String? notes,
  }) async {
    try {
      await _verifyAdmin();

      await _firestore.collection('reports').doc(reportId).update({
        'status': action,
        'resolvedBy': currentUserId,
        'resolvedAt': Timestamp.fromDate(DateTime.now()),
        'adminNotes': notes,
      });

      // Log action
      await _logAdminAction(
        action: 'resolve_report',
        details: '$action: $notes',
      );

      debugPrint('Admin: Report $action: $reportId');
      return AdminActionResult.success('Report $action successfully');
    } catch (e) {
      debugPrint('Error resolving report: $e');
      return AdminActionResult.error('Failed to resolve report');
    }
  }

  /// Get broadcast history
  Future<BroadcastHistoryResult> getBroadcastHistory({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      await _verifyAdmin();

      Query query = _firestore
          .collection('broadcasts')
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      final broadcasts = querySnapshot.docs.map((doc) => 
          Broadcast.fromFirestore(doc)).toList();

      return BroadcastHistoryResult.success(
        broadcasts: broadcasts,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error getting broadcast history: $e');
      return BroadcastHistoryResult.error('Failed to get broadcast history');
    }
  }

  /// Get admin activity log
  Future<AdminLogResult> getAdminLog({
    int limit = 100,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      await _verifyAdmin();

      Query query = _firestore
          .collection('admin_actions')
          .orderBy('timestamp', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      final logs = querySnapshot.docs.map((doc) => 
          AdminLog.fromFirestore(doc)).toList();

      return AdminLogResult.success(
        logs: logs,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error getting admin log: $e');
      return AdminLogResult.error('Failed to get admin log');
    }
  }

  /// Delete user account (soft delete)
  Future<AdminActionResult> deleteUser({
    required String userId,
    String? reason,
  }) async {
    try {
      await _verifyAdmin();

      // Soft delete - anonymize user data
      await _firestore.collection('users').doc(userId).update({
        'isDeleted': true,
        'deletedAt': Timestamp.fromDate(DateTime.now()),
        'deletedBy': currentUserId,
        'deletionReason': reason ?? 'Admin deleted user',
        'name': 'Deleted User',
        'email': null,
        'bio': null,
        'photos': [],
        'phoneNumber': 'deleted_${DateTime.now().millisecondsSinceEpoch}',
      });

      // Log action
      await _logAdminAction(
        action: 'delete_user',
        targetUserId: userId,
        details: reason,
      );

      // Clear cache
      await _cacheService.removeCachedUser(userId);

      debugPrint('Admin: User deleted: $userId');
      return AdminActionResult.success('User deleted successfully');
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return AdminActionResult.error('Failed to delete user');
    }
  }

  /// Get users for broadcast based on filters
  Future<List<String>> _getBroadcastUsers({
    bool? premiumOnly,
    bool? verifiedOnly,
  }) async {
    Query query = _firestore
        .collection('users')
        .where('isBlocked', isEqualTo: false)
        .where('isDeleted', isEqualTo: false);

    if (premiumOnly == true) {
      query = query.where('subscriptionPlan', whereNotIn: ['free']);
    }

    if (verifiedOnly == true) {
      query = query.where('isVerified', isEqualTo: true);
    }

    final querySnapshot = await query.get();
    return querySnapshot.docs.map((doc) => doc.id).toList();
  }

  /// Log admin action
  Future<void> _logAdminAction({
    required String action,
    String? targetUserId,
    String? details,
  }) async {
    try {
      await _firestore.collection('admin_actions').add({
        'adminId': currentUserId,
        'action': action,
        'targetUserId': targetUserId,
        'details': details,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });

      // Track in analytics
      await _analyticsService.trackEvent(
        AnalyticsEvent.userInteraction,
        properties: {
          'action': 'admin_action',
          'adminAction': action,
          'targetUserId': targetUserId,
        },
      );
    } catch (e) {
      debugPrint('Error logging admin action: $e');
    }
  }

  /// Dispose service
  void dispose() {
    debugPrint('AdminService disposed');
  }
}

/// Admin sort options
enum AdminSortBy {
  newest,
  lastActive,
  name,
}

/// Admin statistics
class AdminStats {
  final int totalUsers;
  final int activeUsers;
  final int premiumUsers;
  final int blockedUsers;
  final int todayMessages;
  final int pendingReports;
  final double subscriptionRevenue;
  final double giftRevenue;
  final DateTime lastUpdated;

  AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.premiumUsers,
    required this.blockedUsers,
    required this.todayMessages,
    required this.pendingReports,
    required this.subscriptionRevenue,
    required this.giftRevenue,
    required this.lastUpdated,
  });

  double get activeUserPercentage => totalUsers > 0 ? (activeUsers / totalUsers) * 100 : 0.0;
  double get premiumUserPercentage => totalUsers > 0 ? (premiumUsers / totalUsers) * 100 : 0.0;
  double get totalRevenue => subscriptionRevenue + giftRevenue;

  String get formattedSubscriptionRevenue => '\$${subscriptionRevenue.toStringAsFixed(2)}';
  String get formattedGiftRevenue => '\$${giftRevenue.toStringAsFixed(2)}';
  String get formattedTotalRevenue => '\$${totalRevenue.toStringAsFixed(2)}';
}

/// Report model
class Report {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? adminNotes;

  Report({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.resolvedBy,
    this.resolvedAt,
    this.adminNotes,
  });

  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Report(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reportedUserId: data['reportedUserId'] ?? '',
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      resolvedBy: data['resolvedBy'],
      resolvedAt: data['resolvedAt'] != null 
          ? (data['resolvedAt'] as Timestamp).toDate() 
          : null,
      adminNotes: data['adminNotes'],
    );
  }

  bool get isPending => status == 'pending';
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

/// Broadcast model
class Broadcast {
  final String id;
  final String title;
  final String message;
  final String senderId;
  final List<String> recipientIds;
  final bool premiumOnly;
  final bool verifiedOnly;
  final DateTime createdAt;
  final String status;
  final int totalRecipients;
  final int? sentCount;

  Broadcast({
    required this.id,
    required this.title,
    required this.message,
    required this.senderId,
    required this.recipientIds,
    required this.premiumOnly,
    required this.verifiedOnly,
    required this.createdAt,
    required this.status,
    required this.totalRecipients,
    this.sentCount,
  });

  factory Broadcast.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Broadcast(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      senderId: data['senderId'] ?? '',
      recipientIds: List<String>.from(data['recipientIds'] ?? []),
      premiumOnly: data['premiumOnly'] ?? false,
      verifiedOnly: data['verifiedOnly'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      totalRecipients: data['totalRecipients'] ?? 0,
      sentCount: data['sentCount'],
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

/// Admin log model
class AdminLog {
  final String id;
  final String adminId;
  final String action;
  final String? targetUserId;
  final String? details;
  final DateTime timestamp;

  AdminLog({
    required this.id,
    required this.adminId,
    required this.action,
    this.targetUserId,
    this.details,
    required this.timestamp,
  });

  factory AdminLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AdminLog(
      id: doc.id,
      adminId: data['adminId'] ?? '',
      action: data['action'] ?? '',
      targetUserId: data['targetUserId'],
      details: data['details'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }

  String get actionDisplayName {
    switch (action) {
      case 'block_user': return 'Blocked User';
      case 'unblock_user': return 'Unblocked User';
      case 'verify_user': return 'Verified User';
      case 'unverify_user': return 'Unverified User';
      case 'promote_admin': return 'Promoted to Admin';
      case 'remove_admin': return 'Removed Admin';
      case 'send_broadcast': return 'Sent Broadcast';
      case 'resolve_report': return 'Resolved Report';
      case 'delete_user': return 'Deleted User';
      default: return action;
    }
  }
}

/// Result classes
class AdminUsersResult {
  final bool success;
  final List<UserModel> users;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? error;

  const AdminUsersResult._({
    required this.success,
    this.users = const [],
    this.lastDocument,
    this.hasMore = false,
    this.error,
  });

  factory AdminUsersResult.success({
    required List<UserModel> users,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
  }) {
    return AdminUsersResult._(
      success: true,
      users: users,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  factory AdminUsersResult.error(String error) {
    return AdminUsersResult._(success: false, error: error);
  }
}

class AdminActionResult {
  final bool success;
  final String? message;
  final String? error;

  const AdminActionResult._({
    required this.success,
    this.message,
    this.error,
  });

  factory AdminActionResult.success(String message) {
    return AdminActionResult._(success: true, message: message);
  }

  factory AdminActionResult.error(String error) {
    return AdminActionResult._(success: false, error: error);
  }
}

class AdminStatsResult {
  final bool success;
  final AdminStats? stats;
  final String? error;

  const AdminStatsResult._({
    required this.success,
    this.stats,
    this.error,
  });

  factory AdminStatsResult.success(AdminStats stats) {
    return AdminStatsResult._(success: true, stats: stats);
  }

  factory AdminStatsResult.error(String error) {
    return AdminStatsResult._(success: false, error: error);
  }
}

class ReportsResult {
  final bool success;
  final List<Report> reports;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? error;

  const ReportsResult._({
    required this.success,
    this.reports = const [],
    this.lastDocument,
    this.hasMore = false,
    this.error,
  });

  factory ReportsResult.success({
    required List<Report> reports,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
  }) {
    return ReportsResult._(
      success: true,
      reports: reports,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  factory ReportsResult.error(String error) {
    return ReportsResult._(success: false, error: error);
  }
}

class BroadcastHistoryResult {
  final bool success;
  final List<Broadcast> broadcasts;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? error;

  const BroadcastHistoryResult._({
    required this.success,
    this.broadcasts = const [],
    this.lastDocument,
    this.hasMore = false,
    this.error,
  });

  factory BroadcastHistoryResult.success({
    required List<Broadcast> broadcasts,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
  }) {
    return BroadcastHistoryResult._(
      success: true,
      broadcasts: broadcasts,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  factory BroadcastHistoryResult.error(String error) {
    return BroadcastHistoryResult._(success: false, error: error);
  }
}

class AdminLogResult {
  final bool success;
  final List<AdminLog> logs;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? error;

  const AdminLogResult._({
    required this.success,
    this.logs = const [],
    this.lastDocument,
    this.hasMore = false,
    this.error,
  });

  factory AdminLogResult.success({
    required List<AdminLog> logs,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
  }) {
    return AdminLogResult._(
      success: true,
      logs: logs,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  factory AdminLogResult.error(String error) {
    return AdminLogResult._(success: false, error: error);
  }
}