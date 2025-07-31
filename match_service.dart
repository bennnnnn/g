import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/user_model.dart';
import 'user_service.dart';
import 'validation_service.dart';
import 'cache_service.dart';

class MatchService {
  static final MatchService _instance = MatchService._internal();
  factory MatchService() => _instance;
  MatchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final ValidationService _validationService = ValidationService();
  final CacheService _cacheService = CacheService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Discover users with comprehensive filtering
  Future<DiscoveryResult> discoverUsers({
    // Location filters
    String? country,
    String? city,
    double? maxDistance, // in kilometers
    bool useLocation = true,
    
    // Demographics
    int? minAge,
    int? maxAge,
    String? gender,
    String? interestedIn,
    String? religion,
    String? education,
    
    // Quality filters
    bool? verifiedOnly,
    bool? photoVerifiedOnly,
    bool? recentlyActiveOnly,
    bool? profileCompleteOnly,
    
    // Pagination
    int limit = 20,
    DocumentSnapshot? lastDocument,
    
    // Sorting
    DiscoverySortType sortBy = DiscoverySortType.lastActive,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return DiscoveryResult.error('No user signed in');
      }

      // Get current user for filtering
      final currentUserResult = await _userService.getCurrentUser();
      if (!currentUserResult.success || currentUserResult.user == null) {
        return DiscoveryResult.error('Failed to get current user data');
      }

      final currentUser = currentUserResult.user!;

      // Validate search filters
      final filterValidation = _validationService.validateSearchFilters(
        minAge: minAge,
        maxAge: maxAge,
        maxDistance: maxDistance,
      );

      if (!filterValidation.isValid) {
        return DiscoveryResult.error(filterValidation.error!);
      }

      // Try cache first (only for first page with common filters)
      if (lastDocument == null) {
        final cacheKey = _buildCacheKey(
          country: country,
          city: city,
          minAge: minAge,
          maxAge: maxAge,
          gender: gender,
          sortBy: sortBy,
        );
        
        final cachedUsers = await _getCachedDiscoveryUsers(cacheKey);
        if (cachedUsers != null && cachedUsers.isNotEmpty) {
          final filteredUsers = await _applyClientSideFilters(
            users: cachedUsers,
            currentUser: currentUser,
            maxDistance: maxDistance,
            useLocation: useLocation,
            verifiedOnly: verifiedOnly,
            photoVerifiedOnly: photoVerifiedOnly,
            recentlyActiveOnly: recentlyActiveOnly,
            profileCompleteOnly: profileCompleteOnly,
            limit: limit,
          );
          
          if (filteredUsers.isNotEmpty) {
            debugPrint('Discovery users loaded from cache: ${filteredUsers.length}');
            return DiscoveryResult.success(
              users: filteredUsers,
              hasMore: cachedUsers.length > limit,
              fromCache: true,
            );
          }
        }
      }

      // Build Firestore query
      final queryResult = await _buildDiscoveryQuery(
        currentUser: currentUser,
        country: country,
        city: city,
        minAge: minAge,
        maxAge: maxAge,
        gender: gender,
        interestedIn: interestedIn,
        religion: religion,
        education: education,
        verifiedOnly: verifiedOnly,
        photoVerifiedOnly: photoVerifiedOnly,
        recentlyActiveOnly: recentlyActiveOnly,
        sortBy: sortBy,
        limit: limit * 2, // Get more to account for client-side filtering
        lastDocument: lastDocument,
      );

      if (!queryResult.success) {
        return DiscoveryResult.error(queryResult.error!);
      }

      final firestoreUsers = queryResult.users;

      // Apply client-side filters (distance, blocking, etc.)
      final filteredUsers = await _applyClientSideFilters(
        users: firestoreUsers,
        currentUser: currentUser,
        maxDistance: maxDistance,
        useLocation: useLocation,
        verifiedOnly: verifiedOnly,
        photoVerifiedOnly: photoVerifiedOnly,
        recentlyActiveOnly: recentlyActiveOnly,
        profileCompleteOnly: profileCompleteOnly,
        limit: limit,
      );

      // Cache results (only first page)
      if (lastDocument == null && filteredUsers.isNotEmpty) {
        final cacheKey = _buildCacheKey(
          country: country,
          city: city,
          minAge: minAge,
          maxAge: maxAge,
          gender: gender,
          sortBy: sortBy,
        );
        await _cacheDiscoveryUsers(cacheKey, filteredUsers);
      }

      debugPrint('Discovery completed: ${filteredUsers.length} users found');
      return DiscoveryResult.success(
        users: filteredUsers,
        lastDocument: queryResult.lastDocument,
        hasMore: queryResult.hasMore && filteredUsers.length == limit,
        fromCache: false,
      );
    } catch (e) {
      debugPrint('Error in user discovery: $e');
      return DiscoveryResult.error('Failed to discover users');
    }
  }

  /// Get users near current location
  Future<DiscoveryResult> getNearbyUsers({
    double radiusKm = 50.0,
    int limit = 20,
    DiscoverySortType sortBy = DiscoverySortType.distance,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return DiscoveryResult.error('No user signed in');
      }

      // Get current user location
      final currentUserResult = await _userService.getCurrentUser();
      if (!currentUserResult.success || currentUserResult.user == null) {
        return DiscoveryResult.error('Failed to get current user data');
      }

      final currentUser = currentUserResult.user!;
      
      if (currentUser.latitude == null || currentUser.longitude == null) {
        return DiscoveryResult.error('Location not available. Please enable location services.');
      }

      // Discover users with distance filter
      return await discoverUsers(
        maxDistance: radiusKm,
        useLocation: true,
        limit: limit,
        sortBy: sortBy,
        recentlyActiveOnly: true, // Only show recently active nearby users
      );
    } catch (e) {
      debugPrint('Error getting nearby users: $e');
      return DiscoveryResult.error('Failed to get nearby users');
    }
  }

  /// Get users in specific city/country
  Future<DiscoveryResult> getUsersByLocation({
    String? country,
    String? city,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    return await discoverUsers(
      country: country,
      city: city,
      useLocation: false,
      limit: limit,
      lastDocument: lastDocument,
      sortBy: DiscoverySortType.lastActive,
    );
  }

  /// Get recently active users
  Future<DiscoveryResult> getRecentlyActiveUsers({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    return await discoverUsers(
      recentlyActiveOnly: true,
      limit: limit,
      lastDocument: lastDocument,
      sortBy: DiscoverySortType.lastActive,
    );
  }

  /// Get verified users only
  Future<DiscoveryResult> getVerifiedUsers({
    bool photoVerified = false,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    return await discoverUsers(
      verifiedOnly: true,
      photoVerifiedOnly: photoVerified,
      limit: limit,
      lastDocument: lastDocument,
      sortBy: DiscoverySortType.lastActive,
    );
  }

  /// Get new users (recently joined)
  Future<DiscoveryResult> getNewUsers({
    int daysBack = 7,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return DiscoveryResult.error('No user signed in');
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));
      
      Query query = _firestore
          .collection('users')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .where('isBlocked', isEqualTo: false)
          .where('isPaused', isEqualTo: false);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final querySnapshot = await query.get();
      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => user.id != userId) // Exclude current user
          .toList();

      // Cache new users
      for (final user in users) {
        await _cacheService.cacheUser(user);
      }

      debugPrint('New users loaded: ${users.length}');
      return DiscoveryResult.success(
        users: users,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error getting new users: $e');
      return DiscoveryResult.error('Failed to get new users');
    }
  }

  /// Search users by name or bio
  Future<DiscoveryResult> searchUsers({
    required String query,
    int limit = 20,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return DiscoveryResult.error('No user signed in');
      }

      if (query.trim().isEmpty) {
        return DiscoveryResult.error('Search query cannot be empty');
      }

      // Get current user for filtering
      final currentUserResult = await _userService.getCurrentUser();
      if (!currentUserResult.success || currentUserResult.user == null) {
        return DiscoveryResult.error('Failed to get current user data');
      }

      final currentUser = currentUserResult.user!;

      // Firestore doesn't support full-text search natively
      // In production, you'd use Algolia, Elasticsearch, or similar
      // For now, we'll search by name prefix
      
      final searchTerm = query.trim().toLowerCase();
      
      // Search by name (case insensitive prefix search)
      final nameQuery = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: searchTerm)
          .where('name', isLessThan: '${searchTerm}z')
          .where('isBlocked', isEqualTo: false)
          .where('isPaused', isEqualTo: false)
          .limit(limit)
          .get();

      var users = nameQuery.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => 
              user.id != userId && 
              !currentUser.blockedUsers.contains(user.id) &&
              !user.blockedUsers.contains(userId))
          .toList();

      // If not enough results, try broader search
      if (users.length < limit) {
        // This is a simplified approach - in production use proper search service
        final broadQuery = await _firestore
            .collection('users')
            .where('isBlocked', isEqualTo: false)
            .where('isPaused', isEqualTo: false)
            .limit(100) // Get more to filter client-side
            .get();

        final additionalUsers = broadQuery.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .where((user) => 
                user.id != userId &&
                !users.any((u) => u.id == user.id) && // Not already included
                (user.name?.toLowerCase().contains(searchTerm) == true ||
                 user.bio?.toLowerCase().contains(searchTerm) == true) &&
                !currentUser.blockedUsers.contains(user.id) &&
                !user.blockedUsers.contains(userId))
            .take(limit - users.length)
            .toList();

        users.addAll(additionalUsers);
      }

      // Cache found users
      for (final user in users) {
        await _cacheService.cacheUser(user);
      }

      debugPrint('User search completed: ${users.length} results for "$query"');
      return DiscoveryResult.success(users: users);
    } catch (e) {
      debugPrint('Error searching users: $e');
      return DiscoveryResult.error('Failed to search users');
    }
  }

  /// Get discovery suggestions based on user preferences
  Future<DiscoveryResult> getDiscoverySuggestions({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final currentUserResult = await _userService.getCurrentUser();
      if (!currentUserResult.success || currentUserResult.user == null) {
        return DiscoveryResult.error('Failed to get current user data');
      }

      final currentUser = currentUserResult.user!;

      // Build smart filters based on user profile
      final suggestions = await discoverUsers(
        // Match by interested in
        gender: currentUser.interestedIn,
        
        // Prefer same city/country
        country: currentUser.country,
        city: currentUser.city,
        
        // Age range (±5 years from user's age)
        minAge: currentUser.age != null ? (currentUser.age! - 5).clamp(18, 100) : null,
        maxAge: currentUser.age != null ? (currentUser.age! + 5).clamp(18, 100) : null,
        
        // Prefer verified and active users
        verifiedOnly: true,
        recentlyActiveOnly: true,
        
        // Distance filter if location available
        maxDistance: currentUser.latitude != null ? 100.0 : null,
        useLocation: currentUser.latitude != null,
        
        limit: limit,
        lastDocument: lastDocument,
        sortBy: DiscoverySortType.compatibility,
      );

      return suggestions;
    } catch (e) {
      debugPrint('Error getting discovery suggestions: $e');
      return DiscoveryResult.error('Failed to get suggestions');
    }
  }

  /// Calculate compatibility score between users
  double calculateCompatibility(UserModel user1, UserModel user2) {
    double score = 0.0;
    int factors = 0;

    // Age compatibility (closer ages = higher score)
    if (user1.age != null && user2.age != null) {
      final ageDiff = (user1.age! - user2.age!).abs();
      score += (10 - ageDiff.clamp(0, 10)) / 10.0;
      factors++;
    }

    // Location compatibility
    if (user1.country == user2.country) {
      score += 1.0;
      factors++;
      
      if (user1.city == user2.city) {
        score += 1.0;
        factors++;
      }
    }

    // Religion compatibility
    if (user1.religion != null && user2.religion != null) {
      score += user1.religion == user2.religion ? 1.0 : 0.0;
      factors++;
    }

    // Education compatibility
    if (user1.education != null && user2.education != null) {
      score += user1.education == user2.education ? 1.0 : 0.0;
      factors++;
    }

    // Both have photos
    if (user1.photos.any((p) => p.isNotEmpty) && user2.photos.any((p) => p.isNotEmpty)) {
      score += 1.0;
      factors++;
    }

    // Both verified
    if (user1.isVerified && user2.isVerified) {
      score += 1.0;
      factors++;
    }

    return factors > 0 ? score / factors : 0.0;
  }

  /// Get compatibility analysis between current user and target user
  Future<CompatibilityResult> getCompatibilityAnalysis(String targetUserId) async {
    try {
      final currentUserResult = await _userService.getCurrentUser();
      if (!currentUserResult.success || currentUserResult.user == null) {
        return CompatibilityResult.error('Failed to get current user data');
      }

      final targetUserResult = await _userService.getUserById(targetUserId);
      if (!targetUserResult.success || targetUserResult.user == null) {
        return CompatibilityResult.error('Failed to get target user data');
      }

      final currentUser = currentUserResult.user!;
      final targetUser = targetUserResult.user!;

      final score = calculateCompatibility(currentUser, targetUser);
      
      // Calculate distance if both have location
      double? distance;
      if (currentUser.latitude != null && currentUser.longitude != null &&
          targetUser.latitude != null && targetUser.longitude != null) {
        distance = Geolocator.distanceBetween(
          currentUser.latitude!,
          currentUser.longitude!,
          targetUser.latitude!,
          targetUser.longitude!,
        ) / 1000; // Convert to kilometers
      }

      // Generate compatibility factors
      final factors = <String>[];
      
      if (currentUser.country == targetUser.country) {
        factors.add('Same country');
      }
      if (currentUser.city == targetUser.city) {
        factors.add('Same city');
      }
      if (currentUser.religion == targetUser.religion && currentUser.religion != null) {
        factors.add('Same religion');
      }
      if (currentUser.education == targetUser.education && currentUser.education != null) {
        factors.add('Same education level');
      }
      if (currentUser.age != null && targetUser.age != null) {
        final ageDiff = (currentUser.age! - targetUser.age!).abs();
        if (ageDiff <= 3) {
          factors.add('Similar age');
        }
      }

      final analysis = CompatibilityAnalysis(
        score: score,
        percentage: (score * 100).round(),
        distance: distance,
        compatibilityFactors: factors,
        recommendation: _getCompatibilityRecommendation(score),
      );

      return CompatibilityResult.success(analysis);
    } catch (e) {
      debugPrint('Error getting compatibility analysis: $e');
      return CompatibilityResult.error('Failed to analyze compatibility');
    }
  }

  /// Get user statistics for discovery
  Future<DiscoveryStatsResult> getDiscoveryStats() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return DiscoveryStatsResult.error('No user signed in');
      }

      final currentUserResult = await _userService.getCurrentUser();
      if (!currentUserResult.success || currentUserResult.user == null) {
        return DiscoveryStatsResult.error('Failed to get current user data');
      }

      final currentUser = currentUserResult.user!;

      // Get total users available for discovery
      final totalUsersQuery = await _firestore
          .collection('users')
          .where('isBlocked', isEqualTo: false)
          .where('isPaused', isEqualTo: false)
          .get();

      final totalUsers = totalUsersQuery.docs.length - 1; // Exclude current user

      // Get nearby users count (if location available)
      int nearbyUsers = 0;
      if (currentUser.latitude != null && currentUser.longitude != null) {
        // This is simplified - in production, use geohash or similar for efficient geo queries
        final nearbyResult = await getNearbyUsers(radiusKm: 50.0, limit: 100);
        nearbyUsers = nearbyResult.success ? nearbyResult.users.length : 0;
      }

      // Get users in same city
      int sameCityUsers = 0;
      if (currentUser.city != null) {
        final sameCityQuery = await _firestore
            .collection('users')
            .where('city', isEqualTo: currentUser.city)
            .where('isBlocked', isEqualTo: false)
            .where('isPaused', isEqualTo: false)
            .get();
        sameCityUsers = sameCityQuery.docs.length - 1;
      }

      // Get recently active users
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final activeUsersQuery = await _firestore
          .collection('users')
          .where('lastActiveAt', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .where('isBlocked', isEqualTo: false)
          .where('isPaused', isEqualTo: false)
          .get();
      final activeUsers = activeUsersQuery.docs.length - 1;

      final stats = DiscoveryStats(
        totalUsers: totalUsers,
        nearbyUsers: nearbyUsers,
        sameCityUsers: sameCityUsers,
        recentlyActiveUsers: activeUsers,
        hasLocation: currentUser.latitude != null && currentUser.longitude != null,
      );

      return DiscoveryStatsResult.success(stats);
    } catch (e) {
      debugPrint('Error getting discovery stats: $e');
      return DiscoveryStatsResult.error('Failed to get discovery statistics');
    }
  }

  /// Build Firestore query for discovery
  Future<QueryResult> _buildDiscoveryQuery({
    required UserModel currentUser,
    String? country,
    String? city,
    int? minAge,
    int? maxAge,
    String? gender,
    String? interestedIn,
    String? religion,
    String? education,
    bool? verifiedOnly,
    bool? photoVerifiedOnly,
    bool? recentlyActiveOnly,
    required DiscoverySortType sortBy,
    required int limit,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore.collection('users');

      // Exclude current user, blocked users, and paused profiles
      query = query.where('isBlocked', isEqualTo: false);
      query = query.where('isPaused', isEqualTo: false);

      // Apply filters
      if (country != null && country.isNotEmpty) {
        query = query.where('country', isEqualTo: country);
      }

      if (city != null && city.isNotEmpty) {
        query = query.where('city', isEqualTo: city);
      }

      if (minAge != null) {
        query = query.where('age', isGreaterThanOrEqualTo: minAge);
      }

      if (maxAge != null) {
        query = query.where('age', isLessThanOrEqualTo: maxAge);
      }

      if (gender != null && gender.isNotEmpty) {
        query = query.where('gender', isEqualTo: gender);
      }

      if (religion != null && religion.isNotEmpty) {
        query = query.where('religion', isEqualTo: religion);
      }

      if (education != null && education.isNotEmpty) {
        query = query.where('education', isEqualTo: education);
      }

      if (verifiedOnly == true) {
        query = query.where('isVerified', isEqualTo: true);
      }

      if (photoVerifiedOnly == true) {
        query = query.where('isPhotoVerified', isEqualTo: true);
      }

      if (recentlyActiveOnly == true) {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        query = query.where('lastActiveAt', isGreaterThan: Timestamp.fromDate(sevenDaysAgo));
      }

      // Add sorting
      switch (sortBy) {
        case DiscoverySortType.lastActive:
          query = query.orderBy('lastActiveAt', descending: true);
          break;
        case DiscoverySortType.newest:
          query = query.orderBy('createdAt', descending: true);
          break;
        case DiscoverySortType.age:
          query = query.orderBy('age', descending: false);
          break;
        case DiscoverySortType.distance:
        case DiscoverySortType.compatibility:
          // These require client-side sorting
          query = query.orderBy('lastActiveAt', descending: true);
          break;
      }

      // Add pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => user.id != currentUser.id) // Exclude current user
          .toList();

      return QueryResult.success(
        users: users,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error building discovery query: $e');
      return QueryResult.error('Failed to build query');
    }
  }

  /// Apply client-side filters (for complex logic Firestore can't handle)
  Future<List<UserModel>> _applyClientSideFilters({
    required List<UserModel> users,
    required UserModel currentUser,
    double? maxDistance,
    bool useLocation = true,
    bool? verifiedOnly,
    bool? photoVerifiedOnly,
    bool? recentlyActiveOnly,
    bool? profileCompleteOnly,
    required int limit,
  }) async {
    var filteredUsers = users;

    // Remove blocked users
    filteredUsers = filteredUsers.where((user) =>
        !currentUser.blockedUsers.contains(user.id) &&
        !user.blockedUsers.contains(currentUser.id)).toList();

    // Distance filter
    if (useLocation && maxDistance != null && 
        currentUser.latitude != null && currentUser.longitude != null) {
      filteredUsers = filteredUsers.where((user) {
        if (user.latitude == null || user.longitude == null) return false;
        
        final distance = Geolocator.distanceBetween(
          currentUser.latitude!,
          currentUser.longitude!,
          user.latitude!,
          user.longitude!,
        ) / 1000; // Convert to kilometers
        
        return distance <= maxDistance;
      }).toList();
    }

    // Profile complete filter
    if (profileCompleteOnly == true) {
      filteredUsers = filteredUsers.where((user) => user.isProfileComplete).toList();
    }

    // Sort by compatibility if requested
    if (filteredUsers.isNotEmpty) {
      filteredUsers = (filteredUsers.map((user) {
        final compatibility = calculateCompatibility(currentUser, user);
        return UserWithScore(user: user, score: compatibility);
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score))).cast<UserModel>();
      
      filteredUsers = filteredUsers.map((userWithScore) => userWithScore).toList();
    }

    return filteredUsers.take(limit).toList();
  }

  /// Cache discovery users
  Future<void> _cacheDiscoveryUsers(String cacheKey, List<UserModel> users) async {
    try {
      // Cache individual users
      for (final user in users) {
        await _cacheService.cacheUser(user);
      }
      
      // Cache the discovery result (user IDs only)
      final userIds = users.map((u) => u.id).toList();
      await _cacheService.cacheString(
        'discovery_$cacheKey',
        userIds.join(','),
        expiry: const Duration(minutes: 30),
      );
    } catch (e) {
      debugPrint('Error caching discovery users: $e');
    }
  }

  /// Get cached discovery users
  Future<List<UserModel>?> _getCachedDiscoveryUsers(String cacheKey) async {
    try {
      final cachedIds = _cacheService.getCachedString('discovery_$cacheKey');
      if (cachedIds == null || cachedIds.isEmpty) return null;

      final userIds = cachedIds.split(',');
      final users = <UserModel>[];

      for (final userId in userIds) {
        final user = _cacheService.getCachedUser(userId);
        if (user != null) {
          users.add(user);
        }
      }

      return users.isNotEmpty ? users : null;
    } catch (e) {
      debugPrint('Error getting cached discovery users: $e');
      return null;
    }
  }

  /// Build cache key for discovery filters
  String _buildCacheKey({
    String? country,
    String? city,
    int? minAge,
    int? maxAge,
    String? gender,
    required DiscoverySortType sortBy,
  }) {
    final parts = [
      country ?? 'any',
      city ?? 'any',
      minAge?.toString() ?? 'any',
      maxAge?.toString() ?? 'any',
      gender ?? 'any',
      sortBy.toString().split('.').last,
    ];
    return parts.join('_');
  }

  /// Get compatibility recommendation text
  String _getCompatibilityRecommendation(double score) {
    if (score >= 0.8) {
      return 'Excellent match! You have a lot in common.';
    } else if (score >= 0.6) {
      return 'Great match! You share several important traits.';
    } else if (score >= 0.4) {
      return 'Good match! You have some things in common.';
    } else if (score >= 0.2) {
      return 'Moderate match. You might find interesting differences.';
    } else {
      return 'Different backgrounds could lead to interesting conversations.';
    }
  }

  /// Clear discovery cache
  Future<void> clearDiscoveryCache() async {
    try {
      // Clear discovery-specific caches
      // In a full implementation, you'd track all discovery cache keys
      debugPrint('Discovery cache cleared');
    } catch (e) {
      debugPrint('Error clearing discovery cache: $e');
    }
  }

  /// Dispose service
  void dispose() {
    debugPrint('MatchService disposed');
  }
}

/// Discovery sort types
enum DiscoverySortType {
  lastActive,
  newest,
  age,
  distance,
  compatibility,
}

/// User with compatibility score helper class
class UserWithScore {
  final UserModel user;
  final double score;

  UserWithScore({required this.user, required this.score});
}

/// Discovery operation result
class DiscoveryResult {
  final bool success;
  final List<UserModel> users;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final bool fromCache;
  final String? error;

  const DiscoveryResult._({
    required this.success,
    this.users = const [],
    this.lastDocument,
    this.hasMore = false,
    this.fromCache = false,
    this.error,
  });

  factory DiscoveryResult.success({
    required List<UserModel> users,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
    bool fromCache = false,
  }) {
    return DiscoveryResult._(
      success: true,
      users: users,
      lastDocument: lastDocument,
      hasMore: hasMore,
      fromCache: fromCache,
    );
  }

  factory DiscoveryResult.error(String error) {
    return DiscoveryResult._(success: false, error: error);
  }
}

/// Query result helper class
class QueryResult {
  final bool success;
  final List<UserModel> users;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? error;

  const QueryResult._({
    required this.success,
    this.users = const [],
    this.lastDocument,
    this.hasMore = false,
    this.error,
  });

  factory QueryResult.success({
    required List<UserModel> users,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
  }) {
    return QueryResult._(
      success: true,
      users: users,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  factory QueryResult.error(String error) {
    return QueryResult._(success: false, error: error);
  }
}

/// Compatibility analysis data
class CompatibilityAnalysis {
  final double score;
  final int percentage;
  final double? distance;
  final List<String> compatibilityFactors;
  final String recommendation;

  CompatibilityAnalysis({
    required this.score,
    required this.percentage,
    this.distance,
    required this.compatibilityFactors,
    required this.recommendation,
  });

  String get formattedDistance {
    if (distance == null) return 'Distance unknown';
    if (distance! < 1) {
      return '${(distance! * 1000).round()}m away';
    } else if (distance! < 10) {
      return '${distance!.toStringAsFixed(1)}km away';
    } else {
      return '${distance!.round()}km away';
    }
  }

  String get compatibilityLevel {
    if (percentage >= 80) return 'Excellent';
    if (percentage >= 60) return 'Great';
    if (percentage >= 40) return 'Good';
    if (percentage >= 20) return 'Moderate';
    return 'Different';
  }

  Color get compatibilityColor {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.lightGreen;
    if (percentage >= 40) return Colors.orange;
    if (percentage >= 20) return Colors.deepOrange;
    return Colors.red;
  }
}

/// Compatibility result
class CompatibilityResult {
  final bool success;
  final CompatibilityAnalysis? analysis;
  final String? error;

  const CompatibilityResult._({
    required this.success,
    this.analysis,
    this.error,
  });

  factory CompatibilityResult.success(CompatibilityAnalysis analysis) {
    return CompatibilityResult._(success: true, analysis: analysis);
  }

  factory CompatibilityResult.error(String error) {
    return CompatibilityResult._(success: false, error: error);
  }
}

/// Discovery statistics
class DiscoveryStats {
  final int totalUsers;
  final int nearbyUsers;
  final int sameCityUsers;
  final int recentlyActiveUsers;
  final bool hasLocation;

  DiscoveryStats({
    required this.totalUsers,
    required this.nearbyUsers,
    required this.sameCityUsers,
    required this.recentlyActiveUsers,
    required this.hasLocation,
  });

  String get formattedTotalUsers {
    if (totalUsers > 1000000) {
      return '${(totalUsers / 1000000).toStringAsFixed(1)}M users';
    } else if (totalUsers > 1000) {
      return '${(totalUsers / 1000).toStringAsFixed(1)}K users';
    } else {
      return '$totalUsers users';
    }
  }

  String get locationStatus {
    return hasLocation ? 'Location enabled' : 'Enable location for nearby matches';
  }

  double get nearbyPercentage {
    return totalUsers > 0 ? (nearbyUsers / totalUsers) * 100 : 0.0;
  }

  double get activePercentage {
    return totalUsers > 0 ? (recentlyActiveUsers / totalUsers) * 100 : 0.0;
  }
}

/// Discovery statistics result
class DiscoveryStatsResult {
  final bool success;
  final DiscoveryStats? stats;
  final String? error;

  const DiscoveryStatsResult._({
    required this.success,
    this.stats,
    this.error,
  });

  factory DiscoveryStatsResult.success(DiscoveryStats stats) {
    return DiscoveryStatsResult._(success: true, stats: stats);
  }

  factory DiscoveryStatsResult.error(String error) {
    return DiscoveryStatsResult._(success: false, error: error);
  }
}