import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import '../../models/user_model.dart';
import '../../models/enums.dart';
import 'validation_service.dart';
import 'cache_service.dart';
import 'media_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ValidationService _validationService = ValidationService();
  final CacheService _cacheService = CacheService();
  final MediaService _mediaService = MediaService();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get user by ID (with caching)
  Future<UserResult> getUserById(String userId) async {
    try {
      // Try cache first
      final cachedUser = _cacheService.getCachedUser(userId);
      if (cachedUser != null) {
        debugPrint('User loaded from cache: $userId');
        return UserResult.success(cachedUser);
      }

      // Get from Firestore
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) {
        return UserResult.error('User not found');
      }

      final user = UserModel.fromFirestore(doc);
      
      // Cache the user
      await _cacheService.cacheUser(user);
      
      debugPrint('User loaded from Firestore and cached: $userId');
      return UserResult.success(user);
    } catch (e) {
      debugPrint('Error getting user: $e');
      return UserResult.error('Failed to load user data');
    }
  }

  /// Get current user data
  Future<UserResult> getCurrentUser() async {
    final userId = currentUserId;
    if (userId == null) {
      return UserResult.error('No user signed in');
    }
    return getUserById(userId);
  }

  /// Update user profile (with validation and caching)
  Future<UserResult> updateUser(UserModel user) async {
    try {
      // Validate profile data
      final errors = _validationService.validateProfileData(
        name: user.name,
        age: user.age,
        gender: user.gender,
        interestedIn: user.interestedIn,
        bio: user.bio,
      );

      if (errors.isNotEmpty) {
        return UserResult.error(errors.first);
      }

      final updatedUser = user.copyWith(
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.id).update(
        updatedUser.toFirestore()
      );

      // Update cache
      await _cacheService.cacheUser(updatedUser);

      debugPrint('User updated and cached: ${user.id}');
      return UserResult.success(updatedUser);
    } catch (e) {
      debugPrint('Error updating user: $e');
      return UserResult.error('Failed to update profile');
    }
  }

  /// Update specific user fields
  Future<UserResult> updateUserFields(String userId, Map<String, dynamic> fields) async {
    try {
      fields['updatedAt'] = Timestamp.fromDate(DateTime.now());
      
      await _firestore.collection('users').doc(userId).update(fields);
      
      // Clear cache to force reload with updated data
      await _cacheService.removeCachedUser(userId);
      
      // Return updated user
      return getUserById(userId);
    } catch (e) {
      debugPrint('Error updating user fields: $e');
      return UserResult.error('Failed to update profile');
    }
  }

  /// Upload profile photo (with media processing)
  Future<PhotoUploadResult> uploadProfilePhoto({
    required String userId,
    required File imageFile,
    required int photoIndex, // 0-5 for the 6 photo slots
  }) async {
    try {
      // Validate photo index
      if (photoIndex < 0 || photoIndex > 5) {
        return PhotoUploadResult.error('Invalid photo index');
      }

      // Validate image file
      final validation = _mediaService.validateImageFile(imageFile);
      if (!validation.isValid) {
        return PhotoUploadResult.error(validation.error!);
      }

      // Process and upload image
      final uploadResult = await _mediaService.uploadImage(
        imageFile: imageFile,
        userId: userId,
        folder: 'profile',
        fileName: 'photo_$photoIndex',
      );

      if (!uploadResult.success) {
        return PhotoUploadResult.error(uploadResult.error!);
      }

      // Update user's photos array in Firestore
      final userResult = await getCurrentUser();
      if (!userResult.success || userResult.user == null) {
        return PhotoUploadResult.error('Failed to get user data');
      }

      final user = userResult.user!;
      final photos = List<String>.from(user.photos);
      
      // Ensure photos list has 6 slots
      while (photos.length < 6) {
        photos.add('');
      }
      
      photos[photoIndex] = uploadResult.downloadUrl!;

      // Update user in Firestore
      final updateResult = await updateUserFields(userId, {'photos': photos});
      if (!updateResult.success) {
        return PhotoUploadResult.error('Failed to update user photos');
      }

      debugPrint('Photo uploaded and user updated: $userId, index: $photoIndex');
      return PhotoUploadResult.success(
        downloadUrl: uploadResult.downloadUrl!,
        thumbnailUrl: uploadResult.thumbnailUrl,
        photoIndex: photoIndex,
        fileSize: uploadResult.fileSize!,
        compressionRatio: uploadResult.compressionRatio,
      );
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      return PhotoUploadResult.error('Failed to upload photo');
    }
  }

  /// Delete profile photo
  Future<UserResult> deleteProfilePhoto(String userId, int photoIndex) async {
    try {
      // Get current user
      final userResult = await getUserById(userId);
      if (!userResult.success || userResult.user == null) {
        return UserResult.error('User not found');
      }

      final user = userResult.user!;
      final photos = List<String>.from(user.photos);

      if (photoIndex < 0 || photoIndex >= photos.length || photos[photoIndex].isEmpty) {
        return UserResult.error('Invalid photo index');
      }

      // Delete from Firebase Storage
      final photoUrl = photos[photoIndex];
      await _mediaService.deleteImage(photoUrl);

      // Update photos array
      photos[photoIndex] = '';
      
      // Update user in Firestore
      final updateResult = await updateUserFields(userId, {'photos': photos});
      
      debugPrint('Photo deleted: $userId, index: $photoIndex');
      return updateResult;
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      return UserResult.error('Failed to delete photo');
    }
  }

  /// Get user location and update profile
  Future<LocationResult> updateUserLocation({bool forceUpdate = false}) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return LocationResult.error('No user signed in');
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.error('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.error('Location permission permanently denied');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Validate coordinates
      final coordValidation = _validationService.validateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!coordValidation.isValid) {
        return LocationResult.error(coordValidation.error!);
      }

      // Reverse geocode to get address
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final placemark = placemarks.first;
      final country = placemark.country ?? '';
      final city = placemark.locality ?? placemark.administrativeArea ?? '';

      // Update user location in Firestore
      await updateUserFields(userId, {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'country': country,
        'city': city,
      });

      debugPrint('Location updated: $userId - $city, $country');
      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        country: country,
        city: city,
      );
    } catch (e) {
      debugPrint('Error updating location: $e');
      return LocationResult.error('Failed to get location');
    }
  }

  /// Search users with filters (with caching for performance)
  Future<UsersResult> searchUsers({
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
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      // Validate search filters
      final filterValidation = _validationService.validateSearchFilters(
        minAge: minAge,
        maxAge: maxAge,
        maxDistance: maxDistance,
      );

      if (!filterValidation.isValid) {
        return UsersResult.error(filterValidation.error!);
      }

      Query query = _firestore.collection('users');

      // Apply filters
      if (country != null && country.isNotEmpty) {
        query = query.where('country', isEqualTo: country);
      }

      if (city != null && city.isNotEmpty) {
        query = query.where('city', isEqualTo: city);
      }

      if (religion != null && religion.isNotEmpty) {
        query = query.where('religion', isEqualTo: religion);
      }

      if (education != null && education.isNotEmpty) {
        query = query.where('education', isEqualTo: education);
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

      // Exclude current user and blocked users
      final currentUser = await getCurrentUser();
      if (currentUser.success && currentUser.user != null) {
        final user = currentUser.user!;
        
        // Exclude blocked users (if we have a blockedUsers list)
        if (user.blockedUsers.isNotEmpty) {
          // Firestore whereNotIn supports up to 10 items
          final blockedToExclude = user.blockedUsers.take(10).toList();
          query = query.where(FieldPath.documentId, whereNotIn: blockedToExclude);
        }
      }

      // Exclude blocked and paused users
      query = query.where('isBlocked', isEqualTo: false);
      query = query.where('isPaused', isEqualTo: false);

      // Add pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      // Order and limit
      query = query.orderBy('lastActiveAt', descending: true).limit(limit);

      final querySnapshot = await query.get();
      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => user.id != currentUserId) // Filter out current user
          .toList();

      // Apply distance filter if needed (client-side due to Firestore limitations)
      List<UserModel> filteredUsers = users;
      if (maxDistance != null && currentUser.success && currentUser.user != null) {
        final currentUserData = currentUser.user!;
        if (currentUserData.latitude != null && currentUserData.longitude != null) {
          filteredUsers = users.where((user) {
            if (user.latitude == null || user.longitude == null) return false;
            
            final distance = Geolocator.distanceBetween(
              currentUserData.latitude!,
              currentUserData.longitude!,
              user.latitude!,
              user.longitude!,
            ) / 1000; // Convert to kilometers
            
            return distance <= maxDistance;
          }).toList();
        }
      }

      // Apply interested in filter (match current user's gender with other user's interested in)
      if (interestedIn != null && interestedIn.isNotEmpty && currentUser.success) {
        final currentUserData = currentUser.user!;
        filteredUsers = filteredUsers.where((user) {
          // Check if this user is interested in current user's gender
          return user.interestedIn == currentUserData.gender &&
                 currentUserData.interestedIn == user.gender;
        }).toList();
      }

      // Cache users for better performance
      for (final user in filteredUsers) {
        await _cacheService.cacheUser(user);
      }

      debugPrint('Search completed: ${filteredUsers.length} users found');
      return UsersResult.success(
        users: filteredUsers,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == limit,
      );
    } catch (e) {
      debugPrint('Error searching users: $e');
      return UsersResult.error('Failed to search users');
    }
  }

  /// Get users by IDs (for conversations, etc.)
  Future<UsersResult> getUsersByIds(List<String> userIds) async {
    try {
      if (userIds.isEmpty) {
        return UsersResult.success(users: [], hasMore: false);
      }

      // Try to get as many as possible from cache first
      final cachedUsers = <UserModel>[];
      final uncachedIds = <String>[];

      for (final userId in userIds) {
        final cachedUser = _cacheService.getCachedUser(userId);
        if (cachedUser != null) {
          cachedUsers.add(cachedUser);
        } else {
          uncachedIds.add(userId);
        }
      }

      // Get remaining users from Firestore
      final firestoreUsers = <UserModel>[];
      if (uncachedIds.isNotEmpty) {
        // Firestore 'in' queries are limited to 10 items
        final chunks = <List<String>>[];
        for (int i = 0; i < uncachedIds.length; i += 10) {
          chunks.add(uncachedIds.skip(i).take(10).toList());
        }
        
        for (final chunk in chunks) {
          final querySnapshot = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          
          final users = querySnapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();
          
          firestoreUsers.addAll(users);
          
          // Cache the fetched users
          for (final user in users) {
            await _cacheService.cacheUser(user);
          }
        }
      }

      final allUsers = [...cachedUsers, ...firestoreUsers];
      debugPrint('Users fetched: ${cachedUsers.length} from cache, ${firestoreUsers.length} from Firestore');
      
      return UsersResult.success(users: allUsers, hasMore: false);
    } catch (e) {
      debugPrint('Error getting users by IDs: $e');
      return UsersResult.error('Failed to get users');
    }
  }

  /// Block user
  Future<UserResult> blockUser(String userIdToBlock) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return UserResult.error('No user signed in');
      }

      if (userId == userIdToBlock) {
        return UserResult.error('Cannot block yourself');
      }

      final userResult = await getCurrentUser();
      if (!userResult.success || userResult.user == null) {
        return UserResult.error('Failed to get user data');
      }

      final user = userResult.user!;
      final blockedUsers = List<String>.from(user.blockedUsers);
      
      if (!blockedUsers.contains(userIdToBlock)) {
        blockedUsers.add(userIdToBlock);
        
        await updateUserFields(userId, {'blockedUsers': blockedUsers});
        debugPrint('User blocked: $userIdToBlock');
      }

      return getUserById(userId);
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return UserResult.error('Failed to block user');
    }
  }

  /// Unblock user
  Future<UserResult> unblockUser(String userIdToUnblock) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return UserResult.error('No user signed in');
      }

      final userResult = await getCurrentUser();
      if (!userResult.success || userResult.user == null) {
        return UserResult.error('Failed to get user data');
      }

      final user = userResult.user!;
      final blockedUsers = List<String>.from(user.blockedUsers);
      
      if (blockedUsers.remove(userIdToUnblock)) {
        await updateUserFields(userId, {'blockedUsers': blockedUsers});
        debugPrint('User unblocked: $userIdToUnblock');
      }

      return getUserById(userId);
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      return UserResult.error('Failed to unblock user');
    }
  }

  /// Report user
  Future<UserResult> reportUser(String userIdToReport, String reason) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return UserResult.error('No user signed in');
      }

      if (userId == userIdToReport) {
        return UserResult.error('Cannot report yourself');
      }

      // Validate reason
      if (reason.trim().isEmpty) {
        return UserResult.error('Please provide a reason for reporting');
      }

      // Add to user's reported list
      final userResult = await getCurrentUser();
      if (!userResult.success || userResult.user == null) {
        return UserResult.error('Failed to get user data');
      }

      final user = userResult.user!;
      final reportedUsers = List<String>.from(user.reportedUsers);
      
      if (!reportedUsers.contains(userIdToReport)) {
        reportedUsers.add(userIdToReport);
        await updateUserFields(userId, {'reportedUsers': reportedUsers});
      }

      // Create a report document for admin review
      await _firestore.collection('reports').add({
        'reporterId': userId,
        'reportedUserId': userIdToReport,
        'reason': reason,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'type': 'user_report',
      });

      debugPrint('User reported: $userIdToReport');
      return getUserById(userId);
    } catch (e) {
      debugPrint('Error reporting user: $e');
      return UserResult.error('Failed to report user');
    }
  }

  /// Update profile view count
  Future<void> incrementProfileView(String viewedUserId) async {
    try {
      final userId = currentUserId;
      if (userId == null || userId == viewedUserId) return;

      await _firestore.collection('users').doc(viewedUserId).update({
        'profileViews': FieldValue.increment(1),
      });

      // Remove from cache to get updated data next time
      await _cacheService.removeCachedUser(viewedUserId);
      
      debugPrint('Profile view incremented: $viewedUserId');
    } catch (e) {
      debugPrint('Error incrementing profile view: $e');
    }
  }

  /// Reset daily message limits (called by scheduled function)
  Future<UserResult> resetDailyLimits() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return UserResult.error('No user signed in');
      }

      await updateUserFields(userId, {
        'dailyUsersMessaged': [],
        'userMessageCounts': {},
        'lastMessageResetAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('Daily limits reset: $userId');
      return getCurrentUser();
    } catch (e) {
      debugPrint('Error resetting daily limits: $e');
      return UserResult.error('Failed to reset daily limits');
    }
  }

  /// Update message count for user (when sending a message)
  Future<UserResult> updateMessageCount(String targetUserId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return UserResult.error('No user signed in');
      }

      final userResult = await getCurrentUser();
      if (!userResult.success || userResult.user == null) {
        return UserResult.error('Failed to get user data');
      }

      final user = userResult.user!;
      
      // Check if daily reset is needed first
      if (user.needsDailyReset) {
        await resetDailyLimits();
        // Get updated user data after reset
        final updatedUserResult = await getCurrentUser();
        if (!updatedUserResult.success || updatedUserResult.user == null) {
          return UserResult.error('Failed to get updated user data');
        }
        final updatedUser = updatedUserResult.user!;
        
        // Update with fresh data
        final userMessageCounts = Map<String, int>.from(updatedUser.userMessageCounts);
        final dailyUsersMessaged = List<String>.from(updatedUser.dailyUsersMessaged);
        
        userMessageCounts[targetUserId] = 1;
        if (!dailyUsersMessaged.contains(targetUserId)) {
          dailyUsersMessaged.add(targetUserId);
        }

        return await updateUserFields(userId, {
          'userMessageCounts': userMessageCounts,
          'dailyUsersMessaged': dailyUsersMessaged,
        });
      } else {
        // Normal message count update
        final userMessageCounts = Map<String, int>.from(user.userMessageCounts);
        final dailyUsersMessaged = List<String>.from(user.dailyUsersMessaged);
        
        userMessageCounts[targetUserId] = (userMessageCounts[targetUserId] ?? 0) + 1;
        if (!dailyUsersMessaged.contains(targetUserId)) {
          dailyUsersMessaged.add(targetUserId);
        }

        return await updateUserFields(userId, {
          'userMessageCounts': userMessageCounts,
          'dailyUsersMessaged': dailyUsersMessaged,
        });
      }
    } catch (e) {
      debugPrint('Error updating message count: $e');
      return UserResult.error('Failed to update message count');
    }
  }

  /// Update subscription plan
  Future<UserResult> updateSubscription({
    required SubscriptionPlan plan,
    required DateTime expiresAt,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return UserResult.error('No user signed in');
      }

      await updateUserFields(userId, {
        'subscriptionPlan': plan.toString().split('.').last,
        'subscriptionExpiresAt': Timestamp.fromDate(expiresAt),
      });

      debugPrint('Subscription updated: $userId, plan: $plan');
      return getCurrentUser();
    } catch (e) {
      debugPrint('Error updating subscription: $e');
      return UserResult.error('Failed to update subscription');
    }
  }

  /// Cancel subscription (set to free)
  Future<UserResult> cancelSubscription() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return UserResult.error('No user signed in');
      }

      await updateUserFields(userId, {
        'subscriptionPlan': SubscriptionPlan.free.toString().split('.').last,
        'subscriptionExpiresAt': null,
      });

      debugPrint('Subscription cancelled: $userId');
      return getCurrentUser();
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      return UserResult.error('Failed to cancel subscription');
    }
  }

  /// Update gift statistics
  Future<UserResult> updateGiftStats({
    required String userId,
    required bool isSending, // true for sender, false for receiver
    required double giftValue,
  }) async {
    try {
      if (isSending) {
        await _firestore.collection('users').doc(userId).update({
          'giftsSent': FieldValue.increment(1),
        });
      } else {
        await _firestore.collection('users').doc(userId).update({
          'giftsReceived': FieldValue.increment(1),
          'totalGiftValue': FieldValue.increment(giftValue),
        });
      }

      // Remove from cache to get updated stats
      await _cacheService.removeCachedUser(userId);
      
      debugPrint('Gift stats updated: $userId, sending: $isSending, value: $giftValue');
      return getUserById(userId);
    } catch (e) {
      debugPrint('Error updating gift stats: $e');
      return UserResult.error('Failed to update gift statistics');
    }
  }

  /// Update profile boost
  Future<UserResult> activateProfileBoost({
    required Duration duration,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return UserResult.error('No user signed in');
      }

      final expiresAt = DateTime.now().add(duration);

      await updateUserFields(userId, {
        'hasProfileBoost': true,
        'profileBoostExpiresAt': Timestamp.fromDate(expiresAt),
      });

      debugPrint('Profile boost activated: $userId, duration: $duration');
      return getCurrentUser();
    } catch (e) {
      debugPrint('Error activating profile boost: $e');
      return UserResult.error('Failed to activate profile boost');
    }
  }

  /// Get blocked users list
  Future<UsersResult> getBlockedUsers() async {
    try {
      final userResult = await getCurrentUser();
      if (!userResult.success || userResult.user == null) {
        return UsersResult.error('Failed to get user data');
      }

      final user = userResult.user!;
      if (user.blockedUsers.isEmpty) {
        return UsersResult.success(users: [], hasMore: false);
      }

      return getUsersByIds(user.blockedUsers);
    } catch (e) {
      debugPrint('Error getting blocked users: $e');
      return UsersResult.error('Failed to get blocked users');
    }
  }

  /// Check if user is blocked by current user
  Future<bool> isUserBlocked(String userId) async {
    try {
      final userResult = await getCurrentUser();
      if (!userResult.success || userResult.user == null) {
        return false;
      }

      return userResult.user!.blockedUsers.contains(userId);
    } catch (e) {
      debugPrint('Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Pause/unpause profile
  Future<UserResult> toggleProfilePause(bool isPaused) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return UserResult.error('No user signed in');
      }

      await updateUserFields(userId, {'isPaused': isPaused});
      
      debugPrint('Profile pause toggled: $userId, paused: $isPaused');
      return getCurrentUser();
    } catch (e) {
      debugPrint('Error toggling profile pause: $e');
      return UserResult.error('Failed to update profile visibility');
    }
  }

  /// Update user's basic profile info (name, age, bio, etc.)
  Future<UserResult> updateBasicProfile({
    String? name,
    int? age,
    String? bio,
    String? gender,
    String? interestedIn,
    String? religion,
    String? education,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return UserResult.error('No user signed in');
      }

      // Validate inputs
      final errors = _validationService.validateProfileData(
        name: name,
        age: age,
        gender: gender,
        interestedIn: interestedIn,
        bio: bio,
      );

      if (errors.isNotEmpty) {
        return UserResult.error(errors.first);
      }

      // Build update map
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name.trim();
      if (age != null) updates['age'] = age;
      if (bio != null) updates['bio'] = bio.trim();
      if (gender != null) updates['gender'] = gender;
      if (interestedIn != null) updates['interestedIn'] = interestedIn;
      if (religion != null) updates['religion'] = religion;
      if (education != null) updates['education'] = education;

      if (updates.isEmpty) {
        return UserResult.error('No updates provided');
      }

      await updateUserFields(userId, updates);
      
      debugPrint('Basic profile updated: $userId');
      return getCurrentUser();
    } catch (e) {
      debugPrint('Error updating basic profile: $e');
      return UserResult.error('Failed to update profile');
    }
  }

  /// Get user profile completion percentage
  Future<ProfileCompletionResult> getProfileCompletion() async {
    try {
      final userResult = await getCurrentUser();
      if (!userResult.success || userResult.user == null) {
        return ProfileCompletionResult.error('Failed to get user data');
      }

      final user = userResult.user!;
      int completedFields = 0;
      const totalFields = 7; // name, age, gender, interestedIn, photos, bio, location
      final missingFields = <String>[];

      // Check required fields
      if (user.name != null && user.name!.isNotEmpty) {
        completedFields++;
      } else {
        missingFields.add('Name');
      }

      if (user.age != null) {
        completedFields++;
      } else {
        missingFields.add('Age');
      }

      if (user.gender != null && user.gender!.isNotEmpty) {
        completedFields++;
      } else {
        missingFields.add('Gender');
      }

      if (user.interestedIn != null && user.interestedIn!.isNotEmpty) {
        completedFields++;
      } else {
        missingFields.add('Interested in');
      }

      if (user.photos.any((photo) => photo.isNotEmpty)) {
        completedFields++;
      } else {
        missingFields.add('Photos');
      }

      if (user.bio != null && user.bio!.isNotEmpty) {
        completedFields++;
      } else {
        missingFields.add('Bio');
      }

      if (user.country != null && user.country!.isNotEmpty) {
        completedFields++;
      } else {
        missingFields.add('Location');
      }

      final percentage = (completedFields / totalFields * 100).round();
      
      return ProfileCompletionResult.success(
        percentage: percentage,
        completedFields: completedFields,
        totalFields: totalFields,
        missingFields: missingFields,
        isComplete: percentage == 100,
      );
    } catch (e) {
      debugPrint('Error getting profile completion: $e');
      return ProfileCompletionResult.error('Failed to calculate profile completion');
    }
  }

  /// Clear user cache (useful for testing or manual refresh)
  Future<void> clearUserCache([String? specificUserId]) async {
    try {
      if (specificUserId != null) {
        await _cacheService.removeCachedUser(specificUserId);
      } else {
        // Clear all user-related cache
        await _cacheService.clearAllCache();
      }
      debugPrint('User cache cleared');
    } catch (e) {
      debugPrint('Error clearing user cache: $e');
    }
  }
}

/// User operation result wrapper
class UserResult {
  final bool success;
  final UserModel? user;
  final String? error;

  const UserResult._({
    required this.success,
    this.user,
    this.error,
  });

  factory UserResult.success(UserModel user) {
    return UserResult._(success: true, user: user);
  }

  factory UserResult.error(String error) {
    return UserResult._(success: false, error: error);
  }
}

/// Photo upload result wrapper
class PhotoUploadResult {
  final bool success;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final int? photoIndex;
  final int? fileSize;
  final double? compressionRatio;
  final String? error;

  const PhotoUploadResult._({
    required this.success,
    this.downloadUrl,
    this.thumbnailUrl,
    this.photoIndex,
    this.fileSize,
    this.compressionRatio,
    this.error,
  });

  factory PhotoUploadResult.success({
    required String downloadUrl,
    String? thumbnailUrl,
    required int photoIndex,
    required int fileSize,
    double? compressionRatio,
  }) {
    return PhotoUploadResult._(
      success: true,
      downloadUrl: downloadUrl,
      thumbnailUrl: thumbnailUrl,
      photoIndex: photoIndex,
      fileSize: fileSize,
      compressionRatio: compressionRatio,
    );
  }

  factory PhotoUploadResult.error(String error) {
    return PhotoUploadResult._(success: false, error: error);
  }
}

/// Location result wrapper
class LocationResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final String? country;
  final String? city;
  final String? error;

  const LocationResult._({
    required this.success,
    this.latitude,
    this.longitude,
    this.country,
    this.city,
    this.error,
  });

  factory LocationResult.success({
    required double latitude,
    required double longitude,
    required String country,
    required String city,
  }) {
    return LocationResult._(
      success: true,
      latitude: latitude,
      longitude: longitude,
      country: country,
      city: city,
    );
  }

  factory LocationResult.error(String error) {
    return LocationResult._(success: false, error: error);
  }
}

/// Users search result wrapper
class UsersResult {
  final bool success;
  final List<UserModel> users;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? error;

  const UsersResult._({
    required this.success,
    this.users = const [],
    this.lastDocument,
    this.hasMore = false,
    this.error,
  });

  factory UsersResult.success({
    required List<UserModel> users,
    DocumentSnapshot? lastDocument,
    bool hasMore = false,
  }) {
    return UsersResult._(
      success: true,
      users: users,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  factory UsersResult.error(String error) {
    return UsersResult._(success: false, error: error);
  }
}

/// Profile completion result
class ProfileCompletionResult {
  final bool success;
  final int percentage;
  final int completedFields;
  final int totalFields;
  final List<String> missingFields;
  final bool isComplete;
  final String? error;

  const ProfileCompletionResult._({
    required this.success,
    this.percentage = 0,
    this.completedFields = 0,
    this.totalFields = 0,
    this.missingFields = const [],
    this.isComplete = false,
    this.error,
  });

  factory ProfileCompletionResult.success({
    required int percentage,
    required int completedFields,
    required int totalFields,
    required List<String> missingFields,
    required bool isComplete,
  }) {
    return ProfileCompletionResult._(
      success: true,
      percentage: percentage,
      completedFields: completedFields,
      totalFields: totalFields,
      missingFields: missingFields,
      isComplete: isComplete,
    );
  }

  factory ProfileCompletionResult.error(String error) {
    return ProfileCompletionResult._(success: false, error: error);
  }
}