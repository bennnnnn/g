// providers/auth_state_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthStateProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  // State variables
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;
  
  // OTP specific state
  String? _verificationId;
  int _otpTimeoutSeconds = 0;
  bool _isOtpSent = false;
  bool _canResendOtp = true;
  int _otpAttempts = 0;
  static const int maxOtpAttempts = 3;
  
  // Constructor
  AuthStateProvider() {
    _initializeAuthListener();
  }

  // Getters
  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isPremium => _userModel?.isPremium ?? false;
  bool get isProfileComplete => _userModel?.isProfileComplete ?? false;
  int get profileCompletionPercentage {
    if (_userModel == null) return 0;
    final required = 5; // name, age, gender, interestedIn, photos
    final completed = _userModel!.missingRequiredFields.length;
    return ((required - completed) / required * 100).round();
  }
  List<String> get missingRequiredFields => _userModel?.missingRequiredFields ?? [];
  
  // OTP related getters
  String? get verificationId => _verificationId;
  int get otpTimeoutSeconds => _otpTimeoutSeconds;
  bool get isOtpSent => _isOtpSent;
  bool get canResendOtp => _canResendOtp;
  int get otpAttempts => _otpAttempts;
  bool get hasMaxOtpAttempts => _otpAttempts >= maxOtpAttempts;
  
  // Business logic getters (delegate to UserModel)
  bool get canMessageNewUserToday => _userModel?.canMessageNewUserToday ?? false;
  int get remainingNewUsersToday => _userModel?.getRemainingNewUsersToday() ?? 0;
  String get subscriptionStatusDescription => _userModel?.subscriptionStatusDescription ?? 'Not available';
  bool get needsDailyReset => _userModel?.needsDailyReset ?? false;

  // Initialize auth state listener
  void _initializeAuthListener() {
    _authService.authStateChanges.listen((User? user) async {
      _user = user;
      _error = null;
      
      if (user != null) {
        await _loadUserModel();
        await _checkAndResetDailyLimits();
      } else {
        _userModel = null;
      }
      
      notifyListeners();
    });
  }

  // Load user model data
  Future<void> _loadUserModel() async {
    try {
      _userModel = await _authService.getCurrentUserData();
    } catch (e) {
      debugPrint('Error loading user model: $e');
      _error = 'Failed to load user data';
    }
  }

  // Check and reset daily limits
  Future<void> _checkAndResetDailyLimits() async {
    try {
      await _authService.checkAndResetDailyLimits();
      // Reload user model to get updated limits
      await _loadUserModel();
    } catch (e) {
      debugPrint('Error checking daily limits: $e');
    }
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error state
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear OTP state
  void _clearOtpState() {
    _verificationId = null;
    _otpTimeoutSeconds = 0;
    _isOtpSent = false;
    _canResendOtp = true;
    _otpAttempts = 0;
  }

  // Start OTP countdown timer
  void _startOtpTimer() {
    _otpTimeoutSeconds = 60;
    _canResendOtp = false;
    notifyListeners();

    // Countdown timer
    _otpCountdown();
  }

  void _otpCountdown() {
    if (_otpTimeoutSeconds > 0) {
      Future.delayed(Duration(seconds: 1), () {
        _otpTimeoutSeconds--;
        if (_otpTimeoutSeconds == 0) {
          _canResendOtp = true;
        }
        notifyListeners();
        if (_otpTimeoutSeconds > 0) {
          _otpCountdown();
        }
      });
    }
  }

  // Send OTP
  Future<bool> sendOTP(String phoneNumber) async {
    if (_isLoading) return false;
    
    _setLoading(true);
    _setError(null);
    
    try {
      final result = await _authService.sendOTP(
        phoneNumber: phoneNumber,
        onCodeSent: (String verificationId) {
          _verificationId = verificationId;
          _isOtpSent = true;
          _startOtpTimer();
          notifyListeners();
        },
        onError: (String error) {
          _setError(error);
        },
      );

      if (result.success) {
        return true;
      } else {
        _setError(result.error ?? 'Failed to send OTP');
        return false;
      }
    } catch (e) {
      _setError('Failed to send OTP. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Verify OTP
  Future<bool> verifyOTP(String otp) async {
    if (_isLoading || _verificationId == null) return false;
    
    _setLoading(true);
    _setError(null);
    _otpAttempts++;
    
    try {
      final result = await _authService.verifyOTP(
        verificationId: _verificationId!,
        otp: otp,
      );

      if (result.success) {
        _clearOtpState();
        return true;
      } else {
        _setError(result.error ?? 'Invalid verification code');
        
        // Check if max attempts reached
        if (_otpAttempts >= maxOtpAttempts) {
          _setError('Maximum OTP attempts reached. Please request a new code.');
          _clearOtpState();
        }
        
        return false;
      }
    } catch (e) {
      _setError('Verification failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Resend OTP
  Future<bool> resendOTP(String phoneNumber) async {
    if (!_canResendOtp || _isLoading) return false;
    
    // Reset OTP attempts when resending
    _otpAttempts = 0;
    return await sendOTP(phoneNumber);
  }

  // Sign out
  Future<bool> signOut() async {
    if (_isLoading) return false;
    
    _setLoading(true);
    _setError(null);
    
    try {
      final result = await _authService.signOut();
      
      if (result.success) {
        _clearOtpState();
        return true;
      } else {
        _setError(result.error ?? 'Failed to sign out');
        return false;
      }
    } catch (e) {
      _setError('Sign out failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete account
  Future<bool> deleteAccount() async {
    if (_isLoading) return false;
    
    _setLoading(true);
    _setError(null);
    
    try {
      final result = await _authService.deleteAccount();
      
      if (result.success) {
        _clearOtpState();
        return true;
      } else {
        _setError(result.error ?? 'Failed to delete account');
        return false;
      }
    } catch (e) {
      _setError('Account deletion failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Refresh user model (call after updating user data)
  Future<void> refreshUserModel() async {
    if (_user != null) {
      await _loadUserModel();
      notifyListeners();
    }
  }

  // Check if session is valid
  Future<bool> isSessionValid() async {
    try {
      return await _authService.isSessionValid();
    } catch (e) {
      debugPrint('Session validation error: $e');
      return false;
    }
  }

  // Refresh session
  Future<bool> refreshSession() async {
    if (_isLoading) return false;
    
    try {
      final result = await _authService.refreshSession();
      
      if (result.success) {
        await _loadUserModel();
        return true;
      } else {
        _setError(result.error ?? 'Failed to refresh session');
        return false;
      }
    } catch (e) {
      _setError('Session refresh failed');
      return false;
    }
  }

  // Business logic methods (delegate to UserModel)
  
  // Check if user can message another user
  bool canMessageUser(String userId, {bool isConversationPremium = false}) {
    return _userModel?.canMessageUser(userId, isConversationPremium: isConversationPremium) ?? false;
  }

  // Get remaining messages for specific user
  int getRemainingMessagesForUser(String userId) {
    return _userModel?.getRemainingMessagesForUser(userId) ?? 0;
  }

  // Check if user has admin access
  bool get hasAdminAccess => _userModel?.hasAdminAccess ?? false;

  // Check if user can moderate content
  bool get canModerate => _userModel?.canModerate ?? false;

  // Check specific permission
  bool hasPermission(String permission) {
    return _userModel?.hasPermission(permission) ?? false;
  }

  // Get user role display name
  String get roleDisplayName => _userModel?.roleDisplayName ?? 'User';

  // Check if user can receive messages
  bool get canReceiveMessages => _userModel?.canReceiveMessages ?? true;

  // Check if user is recently active
  bool get isRecentlyActive => _userModel?.isRecentlyActive ?? false;

  // Get auth status
  AuthStatus getAuthStatus() {
    return _authService.getAuthStatus();
  }

  // Get distance from another user
  double? distanceFromUser(UserModel otherUser) {
    return _userModel?.distanceFrom(otherUser);
  }

  // Check if user can be contacted by another user
  bool canBeContactedBy(String otherUserId) {
    return _userModel?.canBeContactedBy(otherUserId) ?? true;
  }

  // Re-authenticate user
  Future<bool> reauthenticateUser({
    required String phoneNumber,
    required String verificationId,
    required String otp,
  }) async {
    if (_isLoading) return false;
    
    _setLoading(true);
    _setError(null);
    
    try {
      final result = await _authService.reauthenticateUser(
        phoneNumber: phoneNumber,
        verificationId: verificationId,
        otp: otp,
      );

      if (result.success) {
        return true;
      } else {
        _setError(result.error ?? 'Reauthentication failed');
        return false;
      }
    } catch (e) {
      _setError('Reauthentication failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update phone number
  Future<bool> updatePhoneNumber({
    required String newPhoneNumber,
    required String verificationId,
    required String otp,
  }) async {
    if (_isLoading) return false;
    
    _setLoading(true);
    _setError(null);
    
    try {
      final result = await _authService.updatePhoneNumber(
        newPhoneNumber: newPhoneNumber,
        verificationId: verificationId,
        otp: otp,
      );

      if (result.success) {
        await refreshUserModel();
        return true;
      } else {
        _setError(result.error ?? 'Failed to update phone number');
        return false;
      }
    } catch (e) {
      _setError('Phone number update failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    // Clean up any timers or listeners if needed
    super.dispose();
  }
}