// providers/user_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enums.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  
  // User data state
  UserModel? _currentUser;
  final Map<String, UserModel> _userCache = {};
  
  // UI state
  bool _isLoading = false;
  bool _isUpdatingProfile = false;
  bool _isUploadingPhoto = false;
  bool _isUpdatingLocation = false;
  String? _error;
  
  // Profile completion state
  int _profileCompletionPercentage = 0;
  List<String> _missingFields = [];
  bool _isProfileComplete = false;
  
  // Photo upload state
  final Map<int, double> _photoUploadProgress = {};
  final Map<int, String?> _photoUploadErrors = {};
  
  // Location state
  double? _latitude;
  double? _longitude;
  String? _country;
  String? _city;
  
  // Search state
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  bool _hasMoreResults = false;
  DocumentSnapshot? _lastDocument;
  Map<String, dynamic> _currentFilters = {};

  // Getters
  UserModel? get currentUser => _currentUser;
  Map<String, UserModel> get userCache => Map.unmodifiable(_userCache);
  bool get isLoading => _isLoading;
  bool get isUpdatingProfile => _isUpdatingProfile;
  bool get isUploadingPhoto => _isUploadingPhoto;
  bool get isUpdatingLocation => _isUpdatingLocation;
  String? get error => _error;
  
  // Profile completion getters
  int get profileCompletionPercentage => _profileCompletionPercentage;
  List<String> get missingFields => List.unmodifiable(_missingFields);
  bool get isProfileComplete => _isProfileComplete;
  
  // Photo upload getters
  Map<int, double> get photoUploadProgress => Map.unmodifiable(_photoUploadProgress);
  Map<int, String?> get photoUploadErrors => Map.unmodifiable(_photoUploadErrors);
  
  // Location getters
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get country => _country;
  String? get city => _city;
  String get locationString => _city != null && _country != null 
      ? '$_city, $_country' 
      : _country ?? 'Location not set';
  
  // Search getters
  List<UserModel> get searchResults => List.unmodifiable(_searchResults);
  bool get isSearching => _isSearching;
  bool get hasMoreResults => _hasMoreResults;
  Map<String, dynamic> get currentFilters => Map.unmodifiable(_currentFilters);

  /// Update current user (for AppProviders integration)
  void updateCurrentUser(UserModel? user) {
    if (_currentUser != user) {
      _currentUser = user;
      if (user != null) {
        _userCache[user.id] = user;
        _updateProfileCompletion();
        _updateLocationFromUser();
      } else {
        // Clear user-specific data when user is null (logout)
        _clearUserData();
      }
      notifyListeners();
    }
  }

  /// Clear user-specific data on logout
  void _clearUserData() {
    _profileCompletionPercentage = 0;
    _missingFields.clear();
    _isProfileComplete = false;
    _photoUploadProgress.clear();
    _photoUploadErrors.clear();
    _latitude = null;
    _longitude = null;
    _country = null;
    _city = null;
    _searchResults.clear();
    _currentFilters.clear();
    _error = null;
  }

  /// Load current user data
  Future<void> loadCurrentUser() async {
    _setLoading(true);

    try {
      final result = await _userService.getCurrentUser();
      
      if (result.success && result.user != null) {
        updateCurrentUser(result.user!); // Use the new method
        _error = null;
      } else {
        _error = result.error ?? 'Failed to load user';
      }
    } catch (e) {
      _error = 'Failed to load user data';
      debugPrint('Error loading current user: $e');
    }

    _setLoading(false);
  }

  /// Get user by ID (with caching)
  Future<UserModel?> getUserById(String userId) async {
    try {
      // Check cache first
      if (_userCache.containsKey(userId)) {
        return _userCache[userId];
      }

      // Load from service
      final result = await _userService.getUserById(userId);
      
      if (result.success && result.user != null) {
        _userCache[userId] = result.user!;
        return result.user!;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    int? age,
    String? bio,
    String? gender,
    String? interestedIn,
    String? religion,
    String? education,
  }) async {
    if (_currentUser == null) return false;

    _isUpdatingProfile = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _userService.updateBasicProfile(
        name: name,
        age: age,
        bio: bio,
        gender: gender,
        interestedIn: interestedIn,
        religion: religion,
        education: education,
      );

      if (result.success && result.user != null) {
        updateCurrentUser(result.user!);
        _isUpdatingProfile = false;
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Failed to update profile';
        _isUpdatingProfile = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to update profile';
      _isUpdatingProfile = false;
      notifyListeners();
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  /// Upload profile photo
  Future<bool> uploadProfilePhoto(File imageFile, int photoIndex) async {
    if (_currentUser == null) return false;

    _isUploadingPhoto = true;
    _photoUploadProgress[photoIndex] = 0.0;
    _photoUploadErrors.remove(photoIndex);
    notifyListeners();

    try {
      final result = await _userService.uploadProfilePhoto(
        userId: _currentUser!.id,
        imageFile: imageFile,
        photoIndex: photoIndex,
      );

      if (result.success) {
        // Refresh current user to get updated photos
        await loadCurrentUser();
        _photoUploadProgress[photoIndex] = 1.0;
        _isUploadingPhoto = false;
        notifyListeners();
        return true;
      } else {
        _photoUploadErrors[photoIndex] = result.error ?? 'Upload failed';
        _isUploadingPhoto = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _photoUploadErrors[photoIndex] = 'Upload failed';
      _isUploadingPhoto = false;
      notifyListeners();
      debugPrint('Error uploading photo: $e');
      return false;
    }
  }

  /// Delete profile photo
  Future<bool> deleteProfilePhoto(int photoIndex) async {
    if (_currentUser == null) return false;

    _setLoading(true);

    try {
      final result = await _userService.deleteProfilePhoto(_currentUser!.id, photoIndex);
      
      if (result.success && result.user != null) {
        updateCurrentUser(result.user!);
        _setLoading(false);
        return true;
      } else {
        _error = result.error ?? 'Failed to delete photo';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _error = 'Failed to delete photo';
      _setLoading(false);
      debugPrint('Error deleting photo: $e');
      return false;
    }
  }

  /// Update user location
  Future<bool> updateLocation({bool forceUpdate = false}) async {
    _isUpdatingLocation = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _userService.updateUserLocation(forceUpdate: forceUpdate);
      
      if (result.success) {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _country = result.country;
        _city = result.city;
        
        // Refresh current user to get updated location
        await loadCurrentUser();
        _isUpdatingLocation = false;
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Failed to get location';
        _isUpdatingLocation = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to update location';
      _isUpdatingLocation = false;
      notifyListeners();
      debugPrint('Error updating location: $e');
      return false;
    }
  }

  /// Search users with filters
  Future<void> searchUsers({
    String? country,
    String? city,
    String? religion,
    String? education,
    int? minAge,
    int? maxAge,
    String? gender,
    String? interestedIn,
    double? maxDistance,
    bool? verifiedOnly,
    bool? recentlyActiveOnly,
    bool? photoVerifiedOnly,
    bool clearPrevious = true,
    int limit = 20,
  }) async {
    if (clearPrevious) {
      _searchResults.clear();
      _lastDocument = null;
      _currentFilters = {
        'country': country,
        'city': city,
        'religion': religion,
        'education': education,
        'minAge': minAge,
        'maxAge': maxAge,
        'gender': gender,
        'interestedIn': interestedIn,
        'maxDistance': maxDistance,
        'verifiedOnly': verifiedOnly,
        'recentlyActiveOnly': recentlyActiveOnly,
        'photoVerifiedOnly': photoVerifiedOnly,
      };
    }

    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _userService.searchUsers(
        country: country,
        city: city,
        religion: religion,
        education: education,
        minAge: minAge,
        maxAge: maxAge,
        gender: gender,
        interestedIn: interestedIn,
        maxDistance: maxDistance,
        verifiedOnly: verifiedOnly,
        recentlyActiveOnly: recentlyActiveOnly,
        photoVerifiedOnly: photoVerifiedOnly,
        limit: limit,
        lastDocument: _lastDocument,
      );

      if (result.success) {
        if (clearPrevious) {
          _searchResults = result.users;
        } else {
          _searchResults.addAll(result.users);
        }
        
        _lastDocument = result.lastDocument;
        _hasMoreResults = result.hasMore;
        
        // Cache the users
        for (final user in result.users) {
          _userCache[user.id] = user;
        }
      } else {
        _error = result.error ?? 'Search failed';
      }
    } catch (e) {
      _error = 'Search failed';
      debugPrint('Error searching users: $e');
    }

    _isSearching = false;
    notifyListeners();
  }

  /// Load more search results
  Future<void> loadMoreSearchResults() async {
    if (!_hasMoreResults || _isSearching) return;

    await searchUsers(
      country: _currentFilters['country'],
      city: _currentFilters['city'],
      religion: _currentFilters['religion'],
      education: _currentFilters['education'],
      minAge: _currentFilters['minAge'],
      maxAge: _currentFilters['maxAge'],
      gender: _currentFilters['gender'],
      interestedIn: _currentFilters['interestedIn'],
      maxDistance: _currentFilters['maxDistance'],
      verifiedOnly: _currentFilters['verifiedOnly'],
      recentlyActiveOnly: _currentFilters['recentlyActiveOnly'],
      photoVerifiedOnly: _currentFilters['photoVerifiedOnly'],
      clearPrevious: false,
    );
  }

  /// Block user
  Future<bool> blockUser(String userIdToBlock) async {
    _setLoading(true);

    try {
      final result = await _userService.blockUser(userIdToBlock);
      
      if (result.success && result.user != null) {
        updateCurrentUser(result.user!);
        
        // Remove blocked user from search results
        _searchResults.removeWhere((user) => user.id == userIdToBlock);
        
        _setLoading(false);
        return true;
      } else {
        _error = result.error ?? 'Failed to block user';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _error = 'Failed to block user';
      _setLoading(false);
      debugPrint('Error blocking user: $e');
      return false;
    }
  }

  /// Unblock user
  Future<bool> unblockUser(String userIdToUnblock) async {
    _setLoading(true);

    try {
      final result = await _userService.unblockUser(userIdToUnblock);
      
      if (result.success && result.user != null) {
        updateCurrentUser(result.user!);
        _setLoading(false);
        return true;
      } else {
        _error = result.error ?? 'Failed to unblock user';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _error = 'Failed to unblock user';
      _setLoading(false);
      debugPrint('Error unblocking user: $e');
      return false;
    }
  }

  /// Report user
  Future<bool> reportUser(String userIdToReport, String reason) async {
    _setLoading(true);

    try {
      final result = await _userService.reportUser(userIdToReport, reason);
      
      if (result.success && result.user != null) {
        updateCurrentUser(result.user!);
        
        // Remove reported user from search results
        _searchResults.removeWhere((user) => user.id == userIdToReport);
        
        _setLoading(false);
        return true;
      } else {
        _error = result.error ?? 'Failed to report user';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _error = 'Failed to report user';
      _setLoading(false);
      debugPrint('Error reporting user: $e');
      return false;
    }
  }

  /// Toggle profile pause
  Future<bool> toggleProfilePause(bool isPaused) async {
    _setLoading(true);

    try {
      final result = await _userService.toggleProfilePause(isPaused);
      
      if (result.success && result.user != null) {
        updateCurrentUser(result.user!);
        _setLoading(false);
        return true;
      } else {
        _error = result.error ?? 'Failed to update profile visibility';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _error = 'Failed to update profile visibility';
      _setLoading(false);
      debugPrint('Error toggling profile pause: $e');
      return false;
    }
  }

  /// Increment profile view
  Future<void> incrementProfileView(String viewedUserId) async {
    try {
      await _userService.incrementProfileView(viewedUserId);
      
      // Update cached user if we have it
      if (_userCache.containsKey(viewedUserId)) {
        final user = _userCache[viewedUserId]!;
        _userCache[viewedUserId] = user.copyWith(
          profileViews: user.profileViews + 1,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error incrementing profile view: $e');
    }
  }

  /// Get blocked users
  Future<void> loadBlockedUsers() async {
    try {
      final result = await _userService.getBlockedUsers();
      
      if (result.success) {
        // Cache the blocked users
        for (final user in result.users) {
          _userCache[user.id] = user;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
    }
  }

  /// Check if user is blocked
  Future<bool> isUserBlocked(String userId) async {
    try {
      return await _userService.isUserBlocked(userId);
    } catch (e) {
      debugPrint('Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Get profile completion data
  Future<void> updateProfileCompletion() async {
    try {
      final result = await _userService.getProfileCompletion();
      
      if (result.success) {
        _profileCompletionPercentage = result.percentage;
        _missingFields = result.missingFields;
        _isProfileComplete = result.isComplete;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating profile completion: $e');
    }
  }

  /// Update location from current user data
  Future<void> _updateLocationFromUser() async {
    if (_currentUser != null) {
      _latitude = _currentUser!.latitude;
      _longitude = _currentUser!.longitude;
      _country = _currentUser!.country;
      _city = _currentUser!.city;
    }
  }

  /// Update profile completion privately
  Future<void> _updateProfileCompletion() async {
    await updateProfileCompletion();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
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

  /// Clear search results
  void clearSearchResults() {
    _searchResults.clear();
    _lastDocument = null;
    _hasMoreResults = false;
    _currentFilters.clear();
    notifyListeners();
  }

  /// Clear photo upload errors
  void clearPhotoUploadError(int photoIndex) {
    _photoUploadErrors.remove(photoIndex);
    notifyListeners();
  }

  /// Clear all photo upload errors
  void clearAllPhotoUploadErrors() {
    _photoUploadErrors.clear();
    notifyListeners();
  }

  /// Refresh user cache
  Future<void> refreshUserCache() async {
    _userCache.clear();
    await loadCurrentUser();
  }

  /// Get cached user or load if not in cache
  Future<UserModel?> getCachedOrLoadUser(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    return await getUserById(userId);
  }

  // BUSINESS LOGIC HELPERS

  /// Check if user can message another user
  bool canMessageUser(String userId, {bool isConversationPremium = false}) {
    return _currentUser?.canMessageUser(userId, isConversationPremium: isConversationPremium) ?? false;
  }

  /// Get remaining messages for specific user
  int getRemainingMessagesForUser(String userId) {
    return _currentUser?.getRemainingMessagesForUser(userId) ?? 0;
  }

  /// Get remaining new users can message today
  int get remainingNewUsersToday {
    return _currentUser?.getRemainingNewUsersToday() ?? 0;
  }

  /// Check if user is premium
  bool get isPremium {
    return _currentUser?.isPremium ?? false;
  }

  /// Get subscription status description
  String get subscriptionStatusDescription {
    if (_currentUser == null) return 'Free User';
    
    if (!_currentUser!.isPremium) {
      return 'Free Plan - Limited messaging';
    }
    
    final plan = _currentUser!.subscriptionPlan;
    final expiresAt = _currentUser!.subscriptionExpiresAt;
    
    if (expiresAt != null) {
      final daysLeft = expiresAt.difference(DateTime.now()).inDays;
      final hoursLeft = expiresAt.difference(DateTime.now()).inHours;
      
      if (daysLeft > 0) {
        return '${plan.displayName} - $daysLeft day${daysLeft == 1 ? '' : 's'} left';
      } else if (hoursLeft > 0) {
        return '${plan.displayName} - $hoursLeft hour${hoursLeft == 1 ? '' : 's'} left';
      } else {
        return '${plan.displayName} - Expires soon';
      }
    }
    
    return '${plan.displayName} - Active';
  }

  /// Check if user has admin access
  bool get hasAdminAccess {
    return _currentUser?.hasAdminAccess ?? false;
  }

  /// Get user role
  String get userRole {
    return _currentUser?.role ?? 'user';
  }

  /// Check if profile is paused
  bool get isProfilePaused {
    return _currentUser?.isPaused ?? false;
  }

  /// Check if user is verified
  bool get isVerified {
    return _currentUser?.isVerified ?? false;
  }

  /// Check if user is photo verified
  bool get isPhotoVerified {
    return _currentUser?.isPhotoVerified ?? false;
  }

  /// Get total profile views
  int get totalProfileViews {
    return _currentUser?.profileViews ?? 0;
  }

  /// Get gifts received count
  int get giftsReceived {
    return _currentUser?.giftsReceived ?? 0;
  }

  /// Get gifts sent count
  int get giftsSent {
    return _currentUser?.giftsSent ?? 0;
  }

  /// Get total gift value received
  double get totalGiftValue {
    return _currentUser?.totalGiftValue ?? 0.0;
  }

  /// Check if user has profile boost
  bool get hasProfileBoost {
    return _currentUser?.hasProfileBoost ?? false;
  }

  /// Get profile boost expiry
  DateTime? get profileBoostExpiresAt {
    return _currentUser?.profileBoostExpiresAt;
  }

  /// Check if user is recently active
  bool get isRecentlyActive {
    return _currentUser?.isRecentlyActive ?? false;
  }

  /// Calculate distance from current user to another user
  double? distanceFromUser(UserModel otherUser) {
    return _currentUser?.distanceFrom(otherUser);
  }

  @override
  void dispose() {
    _userCache.clear();
    super.dispose();
  }
}