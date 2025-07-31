import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/enums.dart';
import 'validation_service.dart';
import 'cache_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ValidationService _validationService = ValidationService();
  final CacheService _cacheService = CacheService();

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Send OTP to phone number
  Future<AuthResult> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      // Validate phone number first
      final validation = _validationService.validatePhoneNumber(phoneNumber);
      if (!validation.isValid) {
        return AuthResult.error(validation.error!);
      }

      // Normalize phone number
      final normalizedPhone = _validationService.normalizePhoneNumber(phoneNumber);
      
      await _auth.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          try {
            await _signInWithCredential(credential);
          } catch (e) {
            debugPrint('Auto-verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Phone verification failed: ${e.message}');
          onError(_getUserFriendlyError(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('OTP sent to $normalizedPhone');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('OTP auto-retrieval timeout');
        },
      );
      
      return AuthResult.success();
    } catch (e) {
      debugPrint('Send OTP error: $e');
      return AuthResult.error('Failed to send verification code. Please try again.');
    }
  }

  /// Verify OTP and sign in
  Future<AuthResult> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    try {
      // Validate OTP first
      final validation = _validationService.validateOTP(otp);
      if (!validation.isValid) {
        return AuthResult.error(validation.error!);
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      
      return await _signInWithCredential(credential);
    } catch (e) {
      debugPrint('Verify OTP error: $e');
      return AuthResult.error('Invalid verification code. Please try again.');
    }
  }

  /// Sign in with credential
  Future<AuthResult> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user == null) {
        return AuthResult.error('Authentication failed. Please try again.');
      }

      // Check if this is a new user
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      
      if (isNewUser) {
        // Create user document in Firestore
        final userModel = await _createUserDocument(user);
        if (userModel != null) {
          // Cache the new user
          await _cacheService.cacheUser(userModel);
        }
        return AuthResult.success(isNewUser: true, user: userModel);
      } else {
        // Update last active timestamp and get existing user
        final userModel = await _updateLastActiveAndGetUser(user.uid);
        if (userModel != null) {
          // Cache the existing user
          await _cacheService.cacheUser(userModel);
        }
        return AuthResult.success(isNewUser: false, user: userModel);
      }
      
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign in error: ${e.message}');
      return AuthResult.error(_getUserFriendlyError(e));
    } catch (e) {
      debugPrint('Unexpected sign in error: $e');
      return AuthResult.error('Authentication failed. Please try again.');
    }
  }

  /// Create user document in Firestore
  Future<UserModel?> _createUserDocument(User user) async {
    try {
      final now = DateTime.now();
      
      final userModel = UserModel(
        id: user.uid,
        phoneNumber: user.phoneNumber ?? '',
        createdAt: now,
        updatedAt: now,
        lastActiveAt: now,
        isVerified: true, // Phone is verified
        subscriptionPlan: SubscriptionPlan.free,
        // Initialize empty collections
        photos: [],
        blockedUsers: [],
        reportedUsers: [],
        userMessageCounts: {},
        dailyUsersMessaged: [],
      );
      
      await _firestore.collection('users').doc(user.uid).set(
        userModel.toFirestore()
      );
      
      debugPrint('User document created for ${user.uid}');
      return userModel;
    } catch (e) {
      debugPrint('Error creating user document: $e');
      return null;
    }
  }

  /// Check if user exists in Firestore
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking user existence: $e');
      return false;
    }
  }

  /// Update user's last active timestamp and get user data
  Future<UserModel?> _updateLastActiveAndGetUser(String uid) async {
    try {
      final now = DateTime.now();
      
      // Update last active
      await _firestore.collection('users').doc(uid).update({
        'lastActiveAt': Timestamp.fromDate(now),
        'lastSeen': Timestamp.fromDate(now),
      });

      // Get user data
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;

      return UserModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error updating last active: $e');
      return null;
    }
  }

  /// Sign out user
  Future<AuthResult> signOut() async {
    try {
      // Clear cache before signing out
      await _cacheService.clearAllCache();
      
      await _auth.signOut();
      return AuthResult.success();
    } catch (e) {
      debugPrint('Sign out error: $e');
      return AuthResult.error('Failed to sign out. Please try again.');
    }
  }

  /// Delete user account
  Future<AuthResult> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.error('No user signed in');
      }

      // Get user data before deletion
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      // Soft delete - mark as deleted instead of hard delete
      if (userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).update({
          'isDeleted': true,
          'deletedAt': Timestamp.fromDate(DateTime.now()),
          'phoneNumber': 'deleted_${DateTime.now().millisecondsSinceEpoch}',
        });
      }

      // Clear cache
      await _cacheService.clearAllCache();
      
      // Delete Firebase Auth user
      await user.delete();
      
      return AuthResult.success();
    } catch (e) {
      debugPrint('Delete account error: $e');
      return AuthResult.error('Failed to delete account. Please try again.');
    }
  }

  /// Get current user data from cache or Firestore
  Future<UserModel?> getCurrentUserData() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      // Try cache first
      final cachedUser = _cacheService.getCachedUser(user.uid);
      if (cachedUser != null) {
        debugPrint('User loaded from cache');
        return cachedUser;
      }

      // Get from Firestore
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      final userModel = UserModel.fromFirestore(doc);
      
      // Cache for next time
      await _cacheService.cacheUser(userModel);
      
      debugPrint('User loaded from Firestore and cached');
      return userModel;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  /// Check if user needs daily reset and perform it
  Future<void> checkAndResetDailyLimits() async {
    try {
      final userModel = await getCurrentUserData();
      if (userModel == null) return;

      if (userModel.needsDailyReset) {
        await _firestore.collection('users').doc(userModel.id).update({
          'dailyUsersMessaged': [],
          'userMessageCounts': {},
          'lastMessageResetAt': Timestamp.fromDate(DateTime.now()),
        });
        
        // Update cache with reset data
        final updatedUser = userModel.copyWith(
          dailyUsersMessaged: [],
          userMessageCounts: {},
          lastMessageResetAt: DateTime.now(),
        );
        await _cacheService.cacheUser(updatedUser);
        
        debugPrint('Daily limits reset for user ${userModel.id}');
      }
    } catch (e) {
      debugPrint('Error checking/resetting daily limits: $e');
    }
  }

  /// Re-authenticate user (for sensitive operations)
  Future<AuthResult> reauthenticateUser({
    required String phoneNumber,
    required String verificationId,
    required String otp,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.error('No user signed in');
      }

      // Validate inputs
      final phoneValidation = _validationService.validatePhoneNumber(phoneNumber);
      if (!phoneValidation.isValid) {
        return AuthResult.error(phoneValidation.error!);
      }

      final otpValidation = _validationService.validateOTP(otp);
      if (!otpValidation.isValid) {
        return AuthResult.error(otpValidation.error!);
      }

      // Create credential and reauthenticate
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      await user.reauthenticateWithCredential(credential);
      
      return AuthResult.success();
    } catch (e) {
      debugPrint('Reauthentication error: $e');
      return AuthResult.error('Reauthentication failed. Please try again.');
    }
  }

  /// Update phone number (requires reauthentication)
  Future<AuthResult> updatePhoneNumber({
    required String newPhoneNumber,
    required String verificationId,
    required String otp,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.error('No user signed in');
      }

      // Validate new phone number
      final validation = _validationService.validatePhoneNumber(newPhoneNumber);
      if (!validation.isValid) {
        return AuthResult.error(validation.error!);
      }

      // Validate OTP
      final otpValidation = _validationService.validateOTP(otp);
      if (!otpValidation.isValid) {
        return AuthResult.error(otpValidation.error!);
      }

      // Create credential and update
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      await user.updatePhoneNumber(credential);

      // Update in Firestore
      final normalizedPhone = _validationService.normalizePhoneNumber(newPhoneNumber);
      await _firestore.collection('users').doc(user.uid).update({
        'phoneNumber': normalizedPhone,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Clear cache to force reload
      await _cacheService.removeCachedUser(user.uid);

      return AuthResult.success();
    } catch (e) {
      debugPrint('Update phone number error: $e');
      return AuthResult.error('Failed to update phone number. Please try again.');
    }
  }

  /// Convert Firebase auth errors to user-friendly messages
  String _getUserFriendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid phone number.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please check and try again.';
      case 'session-expired':
        return 'Verification session expired. Please request a new code.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      case 'user-mismatch':
        return 'The provided credentials do not match the signed-in user.';
      case 'credential-already-in-use':
        return 'This phone number is already associated with another account.';
      default:
        return e.message ?? 'An authentication error occurred. Please try again.';
    }
  }

  /// Get authentication status info
  AuthStatus getAuthStatus() {
    final user = currentUser;
    
    if (user == null) {
      return AuthStatus(
        isAuthenticated: false,
        userId: null,
        phoneNumber: null,
        isVerified: false,
      );
    }

    return AuthStatus(
      isAuthenticated: true,
      userId: user.uid,
      phoneNumber: user.phoneNumber,
      isVerified: user.phoneNumber != null,
    );
  }

  /// Check if current session is valid
  Future<bool> isSessionValid() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      // Try to get ID token to verify session
      await user.getIdToken(true);
      return true;
    } catch (e) {
      debugPrint('Session validation error: $e');
      return false;
    }
  }

  /// Refresh user session
  Future<AuthResult> refreshSession() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.error('No user signed in');
      }

      // Force token refresh
      await user.getIdToken(true);
      
      // Update last active
      await _updateLastActiveAndGetUser(user.uid);
      
      return AuthResult.success();
    } catch (e) {
      debugPrint('Session refresh error: $e');
      return AuthResult.error('Failed to refresh session');
    }
  }
}

/// Authentication result wrapper
class AuthResult {
  final bool success;
  final String? error;
  final bool isNewUser;
  final UserModel? user;

  const AuthResult._({
    required this.success,
    this.error,
    this.isNewUser = false,
    this.user,
  });

  factory AuthResult.success({bool isNewUser = false, UserModel? user}) {
    return AuthResult._(success: true, isNewUser: isNewUser, user: user);
  }

  factory AuthResult.error(String error) {
    return AuthResult._(success: false, error: error);
  }
}

/// Authentication status info
class AuthStatus {
  final bool isAuthenticated;
  final String? userId;
  final String? phoneNumber;
  final bool isVerified;

  AuthStatus({
    required this.isAuthenticated,
    this.userId,
    this.phoneNumber,
    required this.isVerified,
  });

  @override
  String toString() {
    return 'AuthStatus(authenticated: $isAuthenticated, userId: $userId, verified: $isVerified)';
  }
}