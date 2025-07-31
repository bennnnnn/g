import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_service.dart';
import '../services/analytics_service.dart';
import '../models/user_model.dart';
import '../models/enums.dart';
import 'auth_state_provider.dart';

class AdminProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Loading states
  bool _isLoading = false;
  bool _isUsersLoading = false;
  bool _isStatsLoading = false;
  bool _isReportsLoading = false;
  bool _isBroadcastLoading = false;

  // Data states
  List<UserModel> _users = [];
  AdminStats? _dashboardStats;
  List<Report> _reports = [];
  List<Broadcast> _broadcastHistory = [];
  List<AdminLog> _adminLogs = [];
  
  // Pagination
  DocumentSnapshot? _lastUserDocument;
  DocumentSnapshot? _lastReportDocument;
  DocumentSnapshot? _lastBroadcastDocument;
  DocumentSnapshot? _lastLogDocument;
  
  bool _hasMoreUsers = false;
  bool _hasMoreReports = false;
  bool _hasMoreBroadcasts = false;
  bool _hasMoreLogs = false;

  // Filters and search
  String _userSearchQuery = '';
  SubscriptionPlan? _subscriptionFilter;
  bool? _blockedFilter;
  bool? _verifiedFilter;
  AdminSortBy _sortBy = AdminSortBy.newest;

  // Error states
  String? _error;
  String? _userError;
  String? _statsError;
  String? _reportsError;
  String? _broadcastError;

  // Admin status
  bool _isAdmin = false;

  // Getters
  bool get isLoading => _isLoading;
  bool get isUsersLoading => _isUsersLoading;
  bool get isStatsLoading => _isStatsLoading;
  bool get isReportsLoading => _isReportsLoading;
  bool get isBroadcastLoading => _isBroadcastLoading;

  List<UserModel> get users => _users;
  AdminStats? get dashboardStats => _dashboardStats;
  List<Report> get reports => _reports;
  List<Broadcast> get broadcastHistory => _broadcastHistory;
  List<AdminLog> get adminLogs => _adminLogs;

  bool get hasMoreUsers => _hasMoreUsers;
  bool get hasMoreReports => _hasMoreReports;
  bool get hasMoreBroadcasts => _hasMoreBroadcasts;
  bool get hasMoreLogs => _hasMoreLogs;

  String get userSearchQuery => _userSearchQuery;
  SubscriptionPlan? get subscriptionFilter => _subscriptionFilter;
  bool? get blockedFilter => _blockedFilter;
  bool? get verifiedFilter => _verifiedFilter;
  AdminSortBy get sortBy => _sortBy;

  String? get error => _error;
  String? get userError => _userError;
  String? get statsError => _statsError;
  String? get reportsError => _reportsError;
  String? get broadcastError => _broadcastError;

  bool get isAdmin => _isAdmin;
  bool get hasAnyData => _users.isNotEmpty || _dashboardStats != null;

  // Analytics getters
  String get formattedTotalUsers => _dashboardStats?.totalUsers.toString() ?? '0';
  String get formattedActiveUsers => _dashboardStats?.activeUsers.toString() ?? '0';
  String get formattedPremiumUsers => _dashboardStats?.premiumUsers.toString() ?? '0';
  String get formattedRevenue => _dashboardStats?.formattedTotalRevenue ?? '\$0.00';
  int get pendingReportsCount => _reports.where((r) => r.isPending).length;

  /// Update auth state provider dependency (for AppProviders)
  void updateAuth(AuthStateProvider authStateProvider) {
    // Initialize if user is authenticated and has admin access
    if (authStateProvider.isAuthenticated && authStateProvider.hasAdminAccess) {
      if (!_isAdmin) {
        initialize();
      }
    }
    // Clear data if user logged out or no longer admin
    else {
      clear();
    }
  }

  /// Initialize admin provider
  Future<void> initialize() async {
    _setLoading(true);
    _clearError();

    try {
      // Check admin status
      _isAdmin = await _adminService.isAdmin();
      
      if (_isAdmin) {
        // Load initial data
        await Future.wait([
          loadDashboardStats(),
          loadUsers(refresh: true),
          loadReports(refresh: true),
        ]);

        // Track admin session
        await _analyticsService.trackEvent(
          AnalyticsEvent.userInteraction,
          properties: {
            'action': 'admin_session_start',
            'screen': 'admin_dashboard',
          },
        );
      }
    } catch (e) {
      _setError('Failed to initialize admin panel: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Load dashboard statistics
  Future<void> loadDashboardStats() async {
    _isStatsLoading = true;
    _statsError = null;
    notifyListeners();

    try {
      final result = await _adminService.getDashboardStats();
      
      if (result.success && result.stats != null) {
        _dashboardStats = result.stats;
        _statsError = null;
      } else {
        _statsError = result.error ?? 'Failed to load dashboard statistics';
      }
    } catch (e) {
      _statsError = 'Error loading statistics: ${e.toString()}';
    } finally {
      _isStatsLoading = false;
      notifyListeners();
    }
  }

  /// Load users with filters and pagination
  Future<void> loadUsers({
    bool refresh = false,
    bool loadMore = false,
  }) async {
    if (loadMore && !_hasMoreUsers) return;
    if (loadMore && _isUsersLoading) return;

    _isUsersLoading = true;
    _userError = null;
    
    if (refresh) {
      _users.clear();
      _lastUserDocument = null;
      _hasMoreUsers = false;
    }
    
    notifyListeners();

    try {
      final result = await _adminService.getAllUsers(
        searchQuery: _userSearchQuery.isNotEmpty ? _userSearchQuery : null,
        subscriptionPlan: _subscriptionFilter,
        isBlocked: _blockedFilter,
        isVerified: _verifiedFilter,
        sortBy: _sortBy,
        limit: 20,
        lastDocument: loadMore ? _lastUserDocument : null,
      );

      if (result.success) {
        if (loadMore) {
          _users.addAll(result.users);
        } else {
          _users = result.users;
        }
        
        _lastUserDocument = result.lastDocument;
        _hasMoreUsers = result.hasMore;
        _userError = null;
      } else {
        _userError = result.error ?? 'Failed to load users';
      }
    } catch (e) {
      _userError = 'Error loading users: ${e.toString()}';
    } finally {
      _isUsersLoading = false;
      notifyListeners();
    }
  }

  /// Search users
  Future<void> searchUsers(String query) async {
    _userSearchQuery = query;
    await loadUsers(refresh: true);
  }

  /// Set user filters
  Future<void> setUserFilters({
    SubscriptionPlan? subscription,
    bool? blocked,
    bool? verified,
    AdminSortBy? sort,
  }) async {
    bool hasChanges = false;

    if (subscription != _subscriptionFilter) {
      _subscriptionFilter = subscription;
      hasChanges = true;
    }

    if (blocked != _blockedFilter) {
      _blockedFilter = blocked;
      hasChanges = true;
    }

    if (verified != _verifiedFilter) {
      _verifiedFilter = verified;
      hasChanges = true;
    }

    if (sort != null && sort != _sortBy) {
      _sortBy = sort;
      hasChanges = true;
    }

    if (hasChanges) {
      await loadUsers(refresh: true);
    }
  }

  /// Clear all filters
  Future<void> clearFilters() async {
    _userSearchQuery = '';
    _subscriptionFilter = null;
    _blockedFilter = null;
    _verifiedFilter = null;
    _sortBy = AdminSortBy.newest;
    
    await loadUsers(refresh: true);
  }

  /// Block/unblock user
  Future<bool> toggleUserBlock(String userId, bool block, {String? reason}) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _adminService.toggleUserBlock(
        userId: userId,
        block: block,
        reason: reason,
      );

      if (result.success) {
        // Update user in local list
        final userIndex = _users.indexWhere((u) => u.id == userId);
        if (userIndex != -1) {
          _users[userIndex] = _users[userIndex].copyWith(isBlocked: block);
        }

        // Track admin action
        await _analyticsService.trackEvent(
          AnalyticsEvent.userInteraction,
          properties: {
            'action': block ? 'admin_block_user' : 'admin_unblock_user',
            'target_user_id': userId,
            'reason': reason,
          },
        );

        // Refresh stats to reflect changes
        await loadDashboardStats();
        
        notifyListeners();
        return true;
      } else {
        _setError(result.error ?? 'Failed to ${block ? 'block' : 'unblock'} user');
        return false;
      }
    } catch (e) {
      _setError('Error ${block ? 'blocking' : 'unblocking'} user: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verify/unverify user
  Future<bool> toggleUserVerification(String userId, bool verify) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _adminService.toggleUserVerification(
        userId: userId,
        verify: verify,
      );

      if (result.success) {
        // Update user in local list
        final userIndex = _users.indexWhere((u) => u.id == userId);
        if (userIndex != -1) {
          _users[userIndex] = _users[userIndex].copyWith(
            isVerified: verify,
            isPhotoVerified: verify,
          );
        }

        // Track admin action
        await _analyticsService.trackEvent(
          AnalyticsEvent.userInteraction,
          properties: {
            'action': verify ? 'admin_verify_user' : 'admin_unverify_user',
            'target_user_id': userId,
          },
        );

        notifyListeners();
        return true;
      } else {
        _setError(result.error ?? 'Failed to ${verify ? 'verify' : 'unverify'} user');
        return false;
      }
    } catch (e) {
      _setError('Error ${verify ? 'verifying' : 'unverifying'} user: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Promote/demote admin
  Future<bool> toggleAdminStatus(String userId, bool makeAdmin) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _adminService.toggleAdminStatus(
        userId: userId,
        makeAdmin: makeAdmin,
      );

      if (result.success) {
        // Update user in local list
        final userIndex = _users.indexWhere((u) => u.id == userId);
        if (userIndex != -1) {
          _users[userIndex] = _users[userIndex].copyWith(
            isAdmin: makeAdmin,
            role: makeAdmin ? 'admin' : 'user',
            adminSince: makeAdmin ? DateTime.now() : null,
          );
        }

        // Track admin action
        await _analyticsService.trackEvent(
          AnalyticsEvent.userInteraction,
          properties: {
            'action': makeAdmin ? 'admin_promote_user' : 'admin_demote_user',
            'target_user_id': userId,
          },
        );

        notifyListeners();
        return true;
      } else {
        _setError(result.error ?? 'Failed to ${makeAdmin ? 'promote' : 'demote'} user');
        return false;
      }
    } catch (e) {
      _setError('Error ${makeAdmin ? 'promoting' : 'demoting'} user: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete user account
  Future<bool> deleteUser(String userId, {String? reason}) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _adminService.deleteUser(
        userId: userId,
        reason: reason,
      );

      if (result.success) {
        // Remove user from local list
        _users.removeWhere((u) => u.id == userId);

        // Track admin action
        await _analyticsService.trackEvent(
          AnalyticsEvent.userInteraction,
          properties: {
            'action': 'admin_delete_user',
            'target_user_id': userId,
            'reason': reason,
          },
        );

        // Refresh stats
        await loadDashboardStats();
        
        notifyListeners();
        return true;
      } else {
        _setError(result.error ?? 'Failed to delete user');
        return false;
      }
    } catch (e) {
      _setError('Error deleting user: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Load reports
  Future<void> loadReports({
    bool refresh = false,
    bool loadMore = false,
    String status = 'pending',
  }) async {
    if (loadMore && !_hasMoreReports) return;
    if (loadMore && _isReportsLoading) return;

    _isReportsLoading = true;
    _reportsError = null;
    
    if (refresh) {
      _reports.clear();
      _lastReportDocument = null;
      _hasMoreReports = false;
    }
    
    notifyListeners();

    try {
      final result = await _adminService.getReports(
        status: status,
        limit: 20,
        lastDocument: loadMore ? _lastReportDocument : null,
      );

      if (result.success) {
        if (loadMore) {
          _reports.addAll(result.reports);
        } else {
          _reports = result.reports;
        }
        
        _lastReportDocument = result.lastDocument;
        _hasMoreReports = result.hasMore;
        _reportsError = null;
      } else {
        _reportsError = result.error ?? 'Failed to load reports';
      }
    } catch (e) {
      _reportsError = 'Error loading reports: ${e.toString()}';
    } finally {
      _isReportsLoading = false;
      notifyListeners();
    }
  }

  /// Resolve report
  Future<bool> resolveReport(String reportId, String action, {String? notes}) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _adminService.resolveReport(
        reportId: reportId,
        action: action,
        notes: notes,
      );

      if (result.success) {
        // Update report in local list
        final reportIndex = _reports.indexWhere((r) => r.id == reportId);
        if (reportIndex != -1) {
          _reports.removeAt(reportIndex);
        }

        // Track admin action
        await _analyticsService.trackEvent(
          AnalyticsEvent.userInteraction,
          properties: {
            'action': 'admin_resolve_report',
            'report_id': reportId,
            'resolution': action,
          },
        );

        // Refresh stats
        await loadDashboardStats();
        
        notifyListeners();
        return true;
      } else {
        _setError(result.error ?? 'Failed to resolve report');
        return false;
      }
    } catch (e) {
      _setError('Error resolving report: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Send broadcast notification
  Future<bool> sendBroadcast({
    required String title,
    required String message,
    List<String>? targetUserIds,
    bool? premiumOnly,
    bool? verifiedOnly,
  }) async {
    _isBroadcastLoading = true;
    _broadcastError = null;
    notifyListeners();

    try {
      final result = await _adminService.sendBroadcast(
        title: title,
        message: message,
        targetUserIds: targetUserIds,
        premiumOnly: premiumOnly,
        verifiedOnly: verifiedOnly,
      );

      if (result.success) {
        // Track admin action
        await _analyticsService.trackEvent(
          AnalyticsEvent.userInteraction,
          properties: {
            'action': 'admin_send_broadcast',
            'title': title,
            'premium_only': premiumOnly ?? false,
            'verified_only': verifiedOnly ?? false,
          },
        );

        // Refresh broadcast history
        await loadBroadcastHistory(refresh: true);
        
        return true;
      } else {
        _broadcastError = result.error ?? 'Failed to send broadcast';
        return false;
      }
    } catch (e) {
      _broadcastError = 'Error sending broadcast: ${e.toString()}';
      return false;
    } finally {
      _isBroadcastLoading = false;
      notifyListeners();
    }
  }

  /// Load broadcast history
  Future<void> loadBroadcastHistory({
    bool refresh = false,
    bool loadMore = false,
  }) async {
    if (loadMore && !_hasMoreBroadcasts) return;

    try {
      final result = await _adminService.getBroadcastHistory(
        limit: 20,
        lastDocument: loadMore ? _lastBroadcastDocument : null,
      );

      if (result.success) {
        if (refresh || !loadMore) {
          _broadcastHistory = result.broadcasts;
        } else {
          _broadcastHistory.addAll(result.broadcasts);
        }
        
        _lastBroadcastDocument = result.lastDocument;
        _hasMoreBroadcasts = result.hasMore;
      }
    } catch (e) {
      debugPrint('Error loading broadcast history: $e');
    }

    notifyListeners();
  }

  /// Load admin activity logs
  Future<void> loadAdminLogs({
    bool refresh = false,
    bool loadMore = false,
  }) async {
    if (loadMore && !_hasMoreLogs) return;

    try {
      final result = await _adminService.getAdminLog(
        limit: 50,
        lastDocument: loadMore ? _lastLogDocument : null,
      );

      if (result.success) {
        if (refresh || !loadMore) {
          _adminLogs = result.logs;
        } else {
          _adminLogs.addAll(result.logs);
        }
        
        _lastLogDocument = result.lastDocument;
        _hasMoreLogs = result.hasMore;
      }
    } catch (e) {
      debugPrint('Error loading admin logs: $e');
    }

    notifyListeners();
  }

  /// Get user by ID from loaded users
  UserModel? getUserById(String userId) {
    try {
      return _users.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  /// Refresh all data
  Future<void> refreshAll() async {
    await Future.wait([
      loadDashboardStats(),
      loadUsers(refresh: true),
      loadReports(refresh: true),
      loadBroadcastHistory(refresh: true),
    ]);
  }

  /// Helper methods for loading states
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
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
    _error = null;
    _userError = null;
    _statsError = null;
    _reportsError = null;
    _broadcastError = null;
  }

  /// Clear all data (useful for logout)
  void clear() {
    _isLoading = false;
    _isUsersLoading = false;
    _isStatsLoading = false;
    _isReportsLoading = false;
    _isBroadcastLoading = false;

    _users.clear();
    _dashboardStats = null;
    _reports.clear();
    _broadcastHistory.clear();
    _adminLogs.clear();

    _lastUserDocument = null;
    _lastReportDocument = null;
    _lastBroadcastDocument = null;
    _lastLogDocument = null;

    _hasMoreUsers = false;
    _hasMoreReports = false;
    _hasMoreBroadcasts = false;
    _hasMoreLogs = false;

    _userSearchQuery = '';
    _subscriptionFilter = null;
    _blockedFilter = null;
    _verifiedFilter = null;
    _sortBy = AdminSortBy.newest;

    _clearError();
    _isAdmin = false;

    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}