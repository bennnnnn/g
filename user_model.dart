import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'enums.dart';

class UserModel {
  final String id;
  final String phoneNumber;
  final String? email;
  final String? name;
  final int? age;
  final String? bio;
  final List<String> photos;
  final String? country;  // For country filtering
  final String? city;     // For city filtering
  final String? religion; // Religion field
  final String? education; // Education field
  final double? latitude;
  final double? longitude;
  final String? gender;
  final String? interestedIn;
  final bool isVerified;
  final bool isPhotoVerified;  // Photo verification
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastActiveAt;  // For activity tracking
  final DateTime? lastSeen;     // Different from lastActiveAt
  final Map<String, dynamic>? preferences;
  
  // BUSINESS RULE FIELDS
  final Map<String, int> userMessageCounts;    // Track messages per user (userId -> count)
  final List<String> dailyUsersMessaged;       // Users messaged today
  final DateTime? lastMessageResetAt;          // When daily limits were reset
  final SubscriptionPlan subscriptionPlan;
  final DateTime? subscriptionExpiresAt;
  
  // SAFETY & MODERATION
  final bool isBlocked;           // If user is blocked by admin
  final bool isPaused;            // Profile visibility control
  final List<String> blockedUsers; // Users this user has blocked
  final List<String> reportedUsers; // Users this user has reported
  
  // ADMIN & ROLES
  final bool isAdmin;             // Admin access control
  final String role;              // User role (user, admin, moderator, superAdmin)
  final List<String> permissions; // Granular permissions
  final DateTime? adminSince;     // When user became admin
  final String? adminNotes;       // Admin notes about user
  
  // ANALYTICS & GIFTS
  final int profileViews;         // Profile view count
  final int giftsReceived;        // Total gifts received
  final int giftsSent;           // Total gifts sent
  final double totalGiftValue;    // Total value of gifts received
  
  // PREMIUM FEATURES
  final bool hasProfileBoost;     // Profile boost status
  final DateTime? profileBoostExpiresAt; // When boost expires

  UserModel({
    required this.id,
    required this.phoneNumber,
    this.email,
    this.name,
    this.age,
    this.bio,
    this.photos = const [],
    this.country,
    this.city,
    this.religion,
    this.education,
    this.latitude,
    this.longitude,
    this.gender,
    this.interestedIn,
    this.isVerified = false,
    this.isPhotoVerified = false,
    required this.createdAt,
    required this.updatedAt,
    required this.lastActiveAt,
    this.lastSeen,
    this.preferences,
    this.userMessageCounts = const {},
    this.dailyUsersMessaged = const [],
    this.lastMessageResetAt,
    this.subscriptionPlan = SubscriptionPlan.free,
    this.subscriptionExpiresAt,
    this.isBlocked = false,
    this.isPaused = false,
    this.blockedUsers = const [],
    this.reportedUsers = const [],
    this.isAdmin = false,
    this.role = 'user',
    this.permissions = const [],
    this.adminSince,
    this.adminNotes,
    this.profileViews = 0,
    this.giftsReceived = 0,
    this.giftsSent = 0,
    this.totalGiftValue = 0.0,
    this.hasProfileBoost = false,
    this.profileBoostExpiresAt,
  });

  // BUSINESS LOGIC METHODS

  // Check if user is premium (has active subscription)
  bool get isPremium {
    if (subscriptionPlan == SubscriptionPlan.free) return false;
    if (subscriptionExpiresAt == null) return false;
    return DateTime.now().isBefore(subscriptionExpiresAt!);
  }

  // Check if daily limits need to be reset
  bool get needsDailyReset {
    final lastReset = lastMessageResetAt ?? createdAt;
    final now = DateTime.now().toUtc();
    final lastResetDate = DateTime(lastReset.year, lastReset.month, lastReset.day);
    final todayDate = DateTime(now.year, now.month, now.day);
    
    return todayDate.isAfter(lastResetDate);
  }

  // Check if user can message new user today
  bool get canMessageNewUserToday {
    if (isPremium) return true;
    if (needsDailyReset) return true; // Will be reset, so can message
    return dailyUsersMessaged.length < 2; // Free users: 2 users per day
  }

  // Check if user can message specific user
  bool canMessageUser(String userId, {bool isConversationPremium = false}) {
    if (isPremium) return true; // Premium users: unlimited
    if (needsDailyReset) return true; // Will be reset
    if (isConversationPremium) return true; // Can reply in premium conversations
    
    final messageCount = userMessageCounts[userId] ?? 0;
    if (messageCount >= 3) return false; // 3 message limit per user
    
    if (!dailyUsersMessaged.contains(userId)) {
      return dailyUsersMessaged.length < 2; // 2 user limit per day
    }
    
    return true; // Can message existing user within limits
  }

  // Get remaining messages for specific user
  int getRemainingMessagesForUser(String userId) {
    if (isPremium) return -1; // Unlimited
    final messageCount = userMessageCounts[userId] ?? 0;
    return 3 - messageCount; // 3 messages per user limit
  }

  // Get remaining new users can message today
  int getRemainingNewUsersToday() {
    if (isPremium) return -1; // Unlimited
    if (needsDailyReset) return 2; // Will reset to 2
    return 2 - dailyUsersMessaged.length;
  }

  // ADMIN & PERMISSION CHECKS

  // Check if user has admin access
  bool get hasAdminAccess => isAdmin || role == 'admin' || role == 'superAdmin';

  // Check if user can moderate content
  bool get canModerate => hasAdminAccess || role == 'moderator' || permissions.contains('moderate');

  // Check if user can view analytics
  bool get canViewAnalytics => hasAdminAccess || permissions.contains('view_analytics');

  // Check if user can manage users
  bool get canManageUsers => hasAdminAccess || permissions.contains('manage_users');

  // Check if user can send broadcasts
  bool get canSendBroadcasts => hasAdminAccess || permissions.contains('send_broadcasts');

  // Check if user can manage gifts
  bool get canManageGifts => hasAdminAccess || permissions.contains('manage_gifts');

  // Check if user can export data
  bool get canExportData => role == 'superAdmin' || permissions.contains('export_data');

  // Check specific permission
  bool hasPermission(String permission) {
    return hasAdminAccess || permissions.contains(permission);
  }

  // Get user role display name
  String get roleDisplayName {
    switch (role) {
      case 'user':
        return 'User';
      case 'moderator':
        return 'Moderator';
      case 'admin':
        return 'Admin';
      case 'superAdmin':
        return 'Super Admin';
      default:
        return 'User';
    }
  }

  // Get role color for UI
  Color get roleColor {
    switch (role) {
      case 'user':
        return Colors.grey;
      case 'moderator':
        return Colors.blue;
      case 'admin':
        return Colors.orange;
      case 'superAdmin':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Check if user can receive messages
  bool get canReceiveMessages => !isBlocked && !isPaused;

  // Check if user is recently active (within 7 days)
  bool get isRecentlyActive {
    final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));
    return (lastSeen ?? lastActiveAt).isAfter(sevenDaysAgo);
  }

  // Check if profile is complete
  bool get isProfileComplete {
    return name != null && 
           age != null && 
           gender != null && 
           interestedIn != null &&
           photos.isNotEmpty;
  }

  // Get missing required fields
  List<String> get missingRequiredFields {
    List<String> missing = [];
    if (name == null) missing.add('name');
    if (age == null) missing.add('age');
    if (gender == null) missing.add('gender');
    if (interestedIn == null) missing.add('interestedIn');
    if (photos.isEmpty) missing.add('photos');
    return missing;
  }

  // Calculate distance from another user using Haversine formula
  double? distanceFrom(UserModel otherUser) {
    if (latitude == null || longitude == null || 
        otherUser.latitude == null || otherUser.longitude == null) {
      return null;
    }
    
    // Haversine formula implementation
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double lat1Rad = latitude! * (pi / 180);
    double lat2Rad = otherUser.latitude! * (pi / 180);
    double deltaLatRad = (otherUser.latitude! - latitude!) * (pi / 180);
    double deltaLonRad = (otherUser.longitude! - longitude!) * (pi / 180);
    
    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLonRad / 2) * sin(deltaLonRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  // Check if user matches filter criteria
  bool matchesFilters({
    String? countryFilter,
    String? cityFilter,
    String? religionFilter,
    String? educationFilter,
    int? minAge,
    int? maxAge,
    String? genderFilter,
    double? maxDistance,
    bool? verifiedOnly,
    bool? recentlyActiveOnly,
    UserModel? currentUser, // Need current user to calculate distance
  }) {
    if (countryFilter != null && country != countryFilter) return false;
    if (cityFilter != null && city != cityFilter) return false;
    if (religionFilter != null && religion != religionFilter) return false;
    if (educationFilter != null && education != educationFilter) return false;
    if (minAge != null && (age == null || age! < minAge)) return false;
    if (maxAge != null && (age == null || age! > maxAge)) return false;
    if (genderFilter != null && gender != genderFilter) return false;
    if (verifiedOnly == true && !isVerified) return false;
    if (recentlyActiveOnly == true && !isRecentlyActive) return false;
    
    // Distance filtering
    if (maxDistance != null && currentUser != null) {
      final distance = currentUser.distanceFrom(this);
      if (distance == null || distance > maxDistance) return false;
    }
    
    return true;
  }

  // Get subscription status description
  String get subscriptionStatusDescription {
    if (!isPremium) return 'Free User';
    
    final daysLeft = subscriptionExpiresAt!.difference(DateTime.now()).inDays;
    final hoursLeft = subscriptionExpiresAt!.difference(DateTime.now()).inHours;
    
    if (daysLeft > 0) {
      return '${subscriptionPlan.displayName} - $daysLeft day${daysLeft == 1 ? '' : 's'} left';
    } else if (hoursLeft > 0) {
      return '${subscriptionPlan.displayName} - $hoursLeft hour${hoursLeft == 1 ? '' : 's'} left';
    } else {
      return '${subscriptionPlan.displayName} - Expires soon';
    }
  }

  // Convert from Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      id: doc.id,
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'],
      name: data['name'],
      age: data['age'],
      bio: data['bio'],
      photos: List<String>.from(data['photos'] ?? []),
      country: data['country'],
      city: data['city'],
      religion: data['religion'],
      education: data['education'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      gender: data['gender'],
      interestedIn: data['interestedIn'],
      isVerified: data['isVerified'] ?? false,
      isPhotoVerified: data['isPhotoVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate() ?? 
                    (data['createdAt'] as Timestamp).toDate(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      preferences: data['preferences'],
      userMessageCounts: Map<String, int>.from(data['userMessageCounts'] ?? {}),
      dailyUsersMessaged: List<String>.from(data['dailyUsersMessaged'] ?? []),
      lastMessageResetAt: (data['lastMessageResetAt'] as Timestamp?)?.toDate(),
      subscriptionPlan: SubscriptionPlan.values.firstWhere(
        (e) => e.toString() == 'SubscriptionPlan.${data['subscriptionPlan']}',
        orElse: () => SubscriptionPlan.free,
      ),
      subscriptionExpiresAt: data['subscriptionExpiresAt'] != null
          ? (data['subscriptionExpiresAt'] as Timestamp).toDate()
          : null,
      isBlocked: data['isBlocked'] ?? false,
      isPaused: data['isPaused'] ?? false,
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      reportedUsers: List<String>.from(data['reportedUsers'] ?? []),
      isAdmin: data['isAdmin'] ?? false,
      role: data['role'] ?? 'user',
      permissions: List<String>.from(data['permissions'] ?? []),
      adminSince: data['adminSince'] != null
          ? (data['adminSince'] as Timestamp).toDate()
          : null,
      adminNotes: data['adminNotes'],
      profileViews: data['profileViews'] ?? 0,
      giftsReceived: data['giftsReceived'] ?? 0,
      giftsSent: data['giftsSent'] ?? 0,
      totalGiftValue: (data['totalGiftValue'] ?? 0.0).toDouble(),
      hasProfileBoost: data['hasProfileBoost'] ?? false,
      profileBoostExpiresAt: data['profileBoostExpiresAt'] != null
          ? (data['profileBoostExpiresAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'phoneNumber': phoneNumber,
      'email': email,
      'name': name,
      'age': age,
      'bio': bio,
      'photos': photos,
      'country': country,
      'city': city,
      'religion': religion,
      'education': education,
      'latitude': latitude,
      'longitude': longitude,
      'gender': gender,
      'interestedIn': interestedIn,
      'isVerified': isVerified,
      'isPhotoVerified': isPhotoVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'preferences': preferences,
      'userMessageCounts': userMessageCounts,
      'dailyUsersMessaged': dailyUsersMessaged,
      'lastMessageResetAt': lastMessageResetAt != null 
          ? Timestamp.fromDate(lastMessageResetAt!) 
          : null,
      'subscriptionPlan': subscriptionPlan.toString().split('.').last,
      'subscriptionExpiresAt': subscriptionExpiresAt != null
          ? Timestamp.fromDate(subscriptionExpiresAt!)
          : null,
      'isBlocked': isBlocked,
      'isPaused': isPaused,
      'blockedUsers': blockedUsers,
      'reportedUsers': reportedUsers,
      'isAdmin': isAdmin,
      'role': role,
      'permissions': permissions,
      'adminSince': adminSince != null ? Timestamp.fromDate(adminSince!) : null,
      'adminNotes': adminNotes,
      'profileViews': profileViews,
      'giftsReceived': giftsReceived,
      'giftsSent': giftsSent,
      'totalGiftValue': totalGiftValue,
      'hasProfileBoost': hasProfileBoost,
      'profileBoostExpiresAt': profileBoostExpiresAt != null
          ? Timestamp.fromDate(profileBoostExpiresAt!)
          : null,
    };
  }

  UserModel copyWith({
    String? id,
    String? phoneNumber,
    String? email,
    String? name,
    int? age,
    String? bio,
    List<String>? photos,
    String? country,
    String? city,
    String? religion,
    String? education,
    double? latitude,
    double? longitude,
    String? gender,
    String? interestedIn,
    bool? isVerified,
    bool? isPhotoVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActiveAt,
    DateTime? lastSeen,
    Map<String, dynamic>? preferences,
    Map<String, int>? userMessageCounts,
    List<String>? dailyUsersMessaged,
    DateTime? lastMessageResetAt,
    SubscriptionPlan? subscriptionPlan,
    DateTime? subscriptionExpiresAt,
    bool? isBlocked,
    bool? isPaused,
    List<String>? blockedUsers,
    List<String>? reportedUsers,
    bool? isAdmin,
    String? role,
    List<String>? permissions,
    DateTime? adminSince,
    String? adminNotes,
    int? profileViews,
    int? giftsReceived,
    int? giftsSent,
    double? totalGiftValue,
    bool? hasProfileBoost,
    DateTime? profileBoostExpiresAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      name: name ?? this.name,
      age: age ?? this.age,
      bio: bio ?? this.bio,
      photos: photos ?? this.photos,
      country: country ?? this.country,
      city: city ?? this.city,
      religion: religion ?? this.religion,
      education: education ?? this.education,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      isVerified: isVerified ?? this.isVerified,
      isPhotoVerified: isPhotoVerified ?? this.isPhotoVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      lastSeen: lastSeen ?? this.lastSeen,
      preferences: preferences ?? this.preferences,
      userMessageCounts: userMessageCounts ?? this.userMessageCounts,
      dailyUsersMessaged: dailyUsersMessaged ?? this.dailyUsersMessaged,
      lastMessageResetAt: lastMessageResetAt ?? this.lastMessageResetAt,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      isBlocked: isBlocked ?? this.isBlocked,
      isPaused: isPaused ?? this.isPaused,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      reportedUsers: reportedUsers ?? this.reportedUsers,
      isAdmin: isAdmin ?? this.isAdmin,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      adminSince: adminSince ?? this.adminSince,
      adminNotes: adminNotes ?? this.adminNotes,
      profileViews: profileViews ?? this.profileViews,
      giftsReceived: giftsReceived ?? this.giftsReceived,
      giftsSent: giftsSent ?? this.giftsSent,
      totalGiftValue: totalGiftValue ?? this.totalGiftValue,
      hasProfileBoost: hasProfileBoost ?? this.hasProfileBoost,
      profileBoostExpiresAt: profileBoostExpiresAt ?? this.profileBoostExpiresAt,
    );
  }
// Validate phone number format
bool get isValidPhoneNumber {
  return phoneNumber.isNotEmpty && phoneNumber.length >= 10;
}

// Check if user can be contacted
bool canBeContactedBy(String otherUserId) {
  return !blockedUsers.contains(otherUserId) && 
         !isBlocked && 
         !isPaused;
}
  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, phoneNumber: $phoneNumber, isPremium: $isPremium, role: $role)';
  }
}