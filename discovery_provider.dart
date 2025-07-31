// providers/discovery_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../models/user_search_filter_model.dart';
import '../providers/auth_state_provider.dart';
import '../providers/user_provider.dart';

class DiscoveryProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  
  // Discovery state
  List<UserModel> _discoveredUsers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreUsers = true;
  String? _error;
  DocumentSnapshot? _lastDocument;
  
  // Filter state
  UserSearchFilter _activeFilters = const UserSearchFilter();
  bool _isFiltersVisible = false;
  Map<String, List<String>> _availableFilterOptions = {
    'countries': [],
    'cities': [],
    'religions': [],
    'educations': [],
  };
  
  // Current user context
  UserModel? _currentUser;
  
  // UI state
  int _currentUserIndex = 0;
  bool _isSwipeMode = true;
  
  // Stats
  int _totalUsersViewed = 0;
  int _usersViewedToday = 0;

  // Getters
  List<UserModel> get discoveredUsers => List.unmodifiable(_discoveredUsers);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreUsers => _hasMoreUsers;
  String? get error => _error;
  
  UserSearchFilter get activeFilters => _activeFilters;
  bool get isFiltersVisible => _isFiltersVisible;
  Map<String, List<String>> get availableFilterOptions => Map.unmodifiable(_availableFilterOptions);
  bool get hasActiveFilters => _activeFilters.hasActiveFilters;
  int get activeFilterCount => _activeFilters.activeFilterCount;
  
  UserModel? get currentUser => _currentUser;
  int get currentUserIndex => _currentUserIndex;
  bool get isSwipeMode => _isSwipeMode;
  bool get hasUsersToShow => _discoveredUsers.isNotEmpty;
  UserModel? get currentDisplayUser => currentUserIndex < _discoveredUsers.length ? _discoveredUsers[currentUserIndex] : null;
  
  int get totalUsersViewed => _totalUsersViewed;
  int get usersViewedToday => _usersViewedToday;

  /// Update auth state provider dependency
  void updateAuth(AuthStateProvider authStateProvider) {
    if (authStateProvider.isAuthenticated && authStateProvider.userModel != null) {
      updateCurrentUser(authStateProvider.userModel);
      if (_discoveredUsers.isEmpty && !_isLoading) {
        initialize(currentUser: authStateProvider.userModel);
      }
    } else if (!authStateProvider.isAuthenticated) {
      updateCurrentUser(null);
      reset();
    }
  }

  /// Update user provider dependency
  void updateUser(UserProvider userProvider) {
    updateCurrentUser(userProvider.currentUser);
  }

  /// Update current user
  void updateCurrentUser(UserModel? user) {
    if (_currentUser != user) {
      _currentUser = user;
      notifyListeners();
    }
  }

  /// Initialize discovery
  Future<void> initialize({UserModel? currentUser}) async {
    _currentUser = currentUser;
    await loadAvailableFilterOptions();
    await loadUsers();
  }

  /// Load users for discovery (DELEGATE TO SERVICE)
  Future<void> loadUsers({bool refresh = false}) async {
    if (refresh) {
      _discoveredUsers.clear();
      _lastDocument = null;
      _hasMoreUsers = true;
      _currentUserIndex = 0;
    }

    _isLoading = refresh;
    _isLoadingMore = !refresh;
    _error = null;
    notifyListeners();

    try {
      // DELEGATE TO USER SERVICE - NO BUSINESS LOGIC HERE
      final result = await _userService.searchUsers(
        country: _activeFilters.country,
        city: _activeFilters.city,
        religion: _activeFilters.religion,
        education: _activeFilters.education,
        minAge: _activeFilters.minAge,
        maxAge: _activeFilters.maxAge,
        gender: _activeFilters.gender,
        interestedIn: _activeFilters.interestedIn,
        maxDistance: _activeFilters.maxDistance,
        verifiedOnly: _activeFilters.verifiedOnly,
        recentlyActiveOnly: _activeFilters.recentlyActiveOnly,
        photoVerifiedOnly: _activeFilters.hasPhotosOnly,
        limit: 20,
        lastDocument: _lastDocument,
      );

      if (result.success) {
        if (refresh) {
          _discoveredUsers = result.users;
        } else {
          _discoveredUsers.addAll(result.users);
        }
        
        _lastDocument = result.lastDocument;
        _hasMoreUsers = result.hasMore;
      } else {
        _error = result.error ?? 'Failed to load users';
      }
    } catch (e) {
      _error = 'Failed to load users';
      debugPrint('Error loading users: $e');
    }

    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  /// Load more users
  Future<void> loadMoreUsers() async {
    if (!_hasMoreUsers || _isLoadingMore || _isLoading) return;
    await loadUsers(refresh: false);
  }

  /// Apply filters
  Future<void> applyFilters(UserSearchFilter filters) async {
    _activeFilters = filters;
    await loadUsers(refresh: true);
  }

  /// Clear all filters
  Future<void> clearFilters() async {
    _activeFilters = const UserSearchFilter();
    await loadUsers(refresh: true);
  }

  /// Toggle filters visibility
  void toggleFiltersVisibility() {
    _isFiltersVisible = !_isFiltersVisible;
    notifyListeners();
  }

  /// Hide filters
  void hideFilters() {
    _isFiltersVisible = false;
    notifyListeners();
  }

  /// Show filters
  void showFilters() {
    _isFiltersVisible = true;
    notifyListeners();
  }

  /// Toggle view mode
  void toggleViewMode() {
    _isSwipeMode = !_isSwipeMode;
    notifyListeners();
  }

  /// Set view mode
  void setViewMode(bool isSwipeMode) {
    _isSwipeMode = isSwipeMode;
    notifyListeners();
  }

  /// Move to next user
  void nextUser() {
    if (_currentUserIndex < _discoveredUsers.length - 1) {
      _currentUserIndex++;
      _incrementViewCount();
      notifyListeners();
      
      // Load more users if getting close to the end
      if (_currentUserIndex >= _discoveredUsers.length - 3) {
        loadMoreUsers();
      }
    }
  }

  /// Move to previous user
  void previousUser() {
    if (_currentUserIndex > 0) {
      _currentUserIndex--;
      notifyListeners();
    }
  }

  /// Go to specific user index
  void goToUser(int index) {
    if (index >= 0 && index < _discoveredUsers.length) {
      _currentUserIndex = index;
      _incrementViewCount();
      notifyListeners();
    }
  }

  /// Handle user swipe action
  void onUserSwiped(String userId, bool isLike) {
    if (_currentUserIndex < _discoveredUsers.length) {
      final swipedUser = _discoveredUsers[_currentUserIndex];
      if (swipedUser.id == userId) {
        nextUser();
      }
    }
    debugPrint('User ${isLike ? 'liked' : 'passed'}: $userId');
  }

  /// Handle user tap
  void onUserTapped(String userId) {
    // DELEGATE TO SERVICE
    _userService.incrementProfileView(userId);
    _incrementViewCount();
    debugPrint('User profile viewed: $userId');
  }

  /// Increment view count (UI STATE ONLY)
  void _incrementViewCount() {
    _totalUsersViewed++;
    _usersViewedToday++;
    notifyListeners();
  }

  /// Reset daily view count
  void resetDailyViewCount() {
    _usersViewedToday = 0;
    notifyListeners();
  }

  /// Load available filter options
  Future<void> loadAvailableFilterOptions() async {
    try {
      // STATIC DATA FOR UI - NO SERVICE CALL NEEDED
      _availableFilterOptions = {
        'countries': [
          'United States', 'Canada', 'United Kingdom', 'Australia', 
          'Germany', 'France', 'Italy', 'Spain', 'Brazil', 'Mexico',
          'India', 'Japan', 'South Korea', 'Thailand', 'Singapore'
        ],
        'cities': [
          'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix',
          'London', 'Manchester', 'Birmingham', 'Toronto', 'Vancouver',
          'Sydney', 'Melbourne', 'Berlin', 'Munich', 'Paris',
          'Rome', 'Milan', 'Madrid', 'Barcelona', 'Tokyo'
        ],
        'religions': [
          'Christian', 'Catholic', 'Protestant', 'Jewish', 'Muslim',
          'Hindu', 'Buddhist', 'Sikh', 'Agnostic', 'Atheist',
          'Spiritual', 'Other', 'Prefer not to say'
        ],
        'educations': [
          'High School', 'Some College', 'Bachelor\'s Degree',
          'Master\'s Degree', 'PhD', 'Trade School', 'Professional School',
          'Associate Degree', 'Some High School', 'Other'
        ],
      };
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading filter options: $e');
    }
  }

  /// Quick filter methods (DELEGATE TO SERVICE)
  Future<void> getVerifiedUsers() async {
    final verifiedFilter = _activeFilters.copyWith(verifiedOnly: true);
    await applyFilters(verifiedFilter);
  }

  Future<void> getRecentlyActiveUsers() async {
    final recentFilter = _activeFilters.copyWith(recentlyActiveOnly: true);
    await applyFilters(recentFilter);
  }

  Future<void> getUsersWithPhotos() async {
    final photoFilter = _activeFilters.copyWith(hasPhotosOnly: true);
    await applyFilters(photoFilter);
  }

  Future<void> getPremiumUsers() async {
    final premiumFilter = _activeFilters.copyWith(premiumOnly: true);
    await applyFilters(premiumFilter);
  }

  Future<void> getUsersInSameCity() async {
    if (_currentUser?.city != null) {
      final cityFilter = _activeFilters.copyWith(city: _currentUser!.city);
      await applyFilters(cityFilter);
    }
  }

  Future<void> getUsersInSameCountry() async {
    if (_currentUser?.country != null) {
      final countryFilter = _activeFilters.copyWith(country: _currentUser!.country);
      await applyFilters(countryFilter);
    }
  }

  /// Search users by name/bio
  Future<void> searchUsers(String query) async {
    final searchFilter = _activeFilters.copyWith(searchQuery: query);
    await applyFilters(searchFilter);
  }

  /// Clear search query
  Future<void> clearSearch() async {
    final clearedFilter = _activeFilters.copyWith(searchQuery: '');
    await applyFilters(clearedFilter);
  }

  /// Refresh discovery
  Future<void> refresh() async {
    await loadUsers(refresh: true);
  }

  /// UI State Management Methods
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check if user is in current discovery list
  bool isUserInDiscovery(String userId) {
    return _discoveredUsers.any((user) => user.id == userId);
  }

  /// Remove user from discovery
  void removeUserFromDiscovery(String userId) {
    _discoveredUsers.removeWhere((user) => user.id == userId);
    
    if (_currentUserIndex >= _discoveredUsers.length && _discoveredUsers.isNotEmpty) {
      _currentUserIndex = _discoveredUsers.length - 1;
    }
    
    notifyListeners();
  }

  /// Get discovery statistics (UI STATE ONLY)
  Map<String, dynamic> getDiscoveryStats() {
    return {
      'totalUsersLoaded': _discoveredUsers.length,
      'activeFiltersCount': _activeFilters.activeFilterCount,
      'totalUsersViewed': _totalUsersViewed,
      'usersViewedToday': _usersViewedToday,
      'hasMoreUsers': _hasMoreUsers,
      'currentIndex': _currentUserIndex,
    };
  }

  /// Reset discovery state
  void reset() {
    _discoveredUsers.clear();
    _lastDocument = null;
    _hasMoreUsers = true;
    _currentUserIndex = 0;
    _activeFilters = const UserSearchFilter();
    _isFiltersVisible = false;
    _error = null;
    _totalUsersViewed = 0;
    _usersViewedToday = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _discoveredUsers.clear();
    _availableFilterOptions.clear();
    super.dispose();
  }
}