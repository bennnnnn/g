
// providers/validation_provider.dart
import 'package:flutter/material.dart';
import '../services/validation_service.dart';

class ValidationProvider extends ChangeNotifier {
  final ValidationService _validationService = ValidationService();
  
  // Form validation states
  final Map<String, String?> _errors = {};
  final Map<String, bool> _isValidating = {};
  
  Map<String, String?> get errors => Map.unmodifiable(_errors);
  Map<String, bool> get isValidating => Map.unmodifiable(_isValidating);

  /// Clear all validation errors
  void clearAllErrors() {
    _errors.clear();
    _isValidating.clear();
    notifyListeners();
  }

  /// Clear specific field error
  void clearError(String field) {
    _errors.remove(field);
    _isValidating.remove(field);
    notifyListeners();
  }

  /// Set validation state for a field
  void setValidating(String field, bool isValidating) {
    _isValidating[field] = isValidating;
    notifyListeners();
  }

  /// Validate phone number
  bool validatePhoneNumber(String? phone, {String field = 'phone'}) {
    setValidating(field, true);
    
    final result = _validationService.validatePhoneNumber(phone);
    
    if (result.isValid) {
      _errors.remove(field);
    } else {
      _errors[field] = result.error;
    }
    
    setValidating(field, false);
    return result.isValid;
  }

  /// Validate OTP
  bool validateOTP(String? otp, {String field = 'otp'}) {
    setValidating(field, true);
    
    final result = _validationService.validateOTP(otp);
    
    if (result.isValid) {
      _errors.remove(field);
    } else {
      _errors[field] = result.error;
    }
    
    setValidating(field, false);
    return result.isValid;
  }

  /// Validate name
  bool validateName(String? name, {String field = 'name'}) {
    setValidating(field, true);
    
    final result = _validationService.validateName(name);
    
    if (result.isValid) {
      _errors.remove(field);
    } else {
      _errors[field] = result.error;
    }
    
    setValidating(field, false);
    return result.isValid;
  }

  /// Validate age
  bool validateAge(int? age, {String field = 'age'}) {
    setValidating(field, true);
    
    final result = _validationService.validateAge(age);
    
    if (result.isValid) {
      _errors.remove(field);
    } else {
      _errors[field] = result.error;
    }
    
    setValidating(field, false);
    return result.isValid;
  }

  /// Validate bio
  bool validateBio(String? bio, {String field = 'bio'}) {
    setValidating(field, true);
    
    final result = _validationService.validateBio(bio);
    
    if (result.isValid) {
      _errors.remove(field);
    } else {
      _errors[field] = result.error;
    }
    
    setValidating(field, false);
    return result.isValid;
  }

  /// Validate gender
  bool validateGender(String? gender, {String field = 'gender'}) {
    setValidating(field, true);
    
    final result = _validationService.validateGender(gender);
    
    if (result.isValid) {
      _errors.remove(field);
    } else {
      _errors[field] = result.error;
    }
    
    setValidating(field, false);
    return result.isValid;
  }

  /// Validate message
  bool validateMessage(String? message, {String field = 'message'}) {
    setValidating(field, true);
    
    final result = _validationService.validateMessage(message);
    
    if (result.isValid) {
      _errors.remove(field);
    } else {
      _errors[field] = result.error;
    }
    
    setValidating(field, false);
    return result.isValid;
  }

  /// Validate complete profile form
  bool validateProfileData({
    String? name,
    int? age,
    String? gender,
    String? interestedIn,
    String? bio,
  }) {
    clearAllErrors();
    
    bool isValid = true;
    
    if (!validateName(name, field: 'name')) isValid = false;
    if (!validateAge(age, field: 'age')) isValid = false;
    if (!validateGender(gender, field: 'gender')) isValid = false;
    if (!validateGender(interestedIn, field: 'interestedIn')) isValid = false;
    if (!validateBio(bio, field: 'bio')) isValid = false;
    
    return isValid;
  }

  /// Validate message limits for business rules
  bool validateMessageLimits({
    required bool isUserPremium,
    required bool isConversationPremium,
    required int currentDailyUsers,
    required int messagesWithUser,
    String field = 'messageLimits',
  }) {
    setValidating(field, true);
    
    final result = _validationService.validateMessageLimits(
      isUserPremium: isUserPremium,
      isConversationPremium: isConversationPremium,
      currentDailyUsers: currentDailyUsers,
      messagesWithUser: messagesWithUser,
    );
    
    if (result.isValid) {
      _errors.remove(field);
    } else {
      _errors[field] = result.error;
    }
    
    setValidating(field, false);
    return result.isValid;
  }

  /// Format phone number for display
  String formatPhoneNumber(String phone) {
    return _validationService.formatPhoneNumber(phone);
  }

  /// Normalize phone number for storage
  String normalizePhoneNumber(String phone) {
    return _validationService.normalizePhoneNumber(phone);
  }

  /// Get error for specific field
  String? getError(String field) {
    return _errors[field];
  }

  /// Check if field is being validated
  bool isFieldValidating(String field) {
    return _isValidating[field] ?? false;
  }

  /// Check if field has error
  bool hasError(String field) {
    return _errors.containsKey(field);
  }

  /// Check if any field has errors
  bool get hasAnyErrors => _errors.isNotEmpty;

  /// Get all error messages
  List<String> get allErrors => _errors.values.whereType<String>().toList();

  /// Validate email (additional validation method)
  bool validateEmail(String? email, {String field = 'email'}) {
    setValidating(field, true);
    
    if (email == null || email.isEmpty) {
      _errors.remove(field); // Email is optional
      setValidating(field, false);
      return true;
    }
    
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+"$');
    final isValid = emailRegex.hasMatch(email);
    
    if (isValid) {
      _errors.remove(field);
    } else {
      _errors[field] = 'Please enter a valid email address';
    }
    
    setValidating(field, false);
    return isValid;
  }

  /// Validate search query
  bool validateSearchQuery(String? query, {String field = 'search'}) {
    setValidating(field, true);
    
    if (query == null || query.trim().isEmpty) {
      _errors[field] = 'Search query cannot be empty';
      setValidating(field, false);
      return false;
    }
    
    if (query.trim().length < 2) {
      _errors[field] = 'Search query must be at least 2 characters';
      setValidating(field, false);
      return false;
    }
    
    _errors.remove(field);
    setValidating(field, false);
    return true;
  }

  /// Validate password (if needed for admin features)
  bool validatePassword(String? password, {String field = 'password'}) {
    setValidating(field, true);
    
    if (password == null || password.isEmpty) {
      _errors[field] = 'Password is required';
      setValidating(field, false);
      return false;
    }
    
    if (password.length < 8) {
      _errors[field] = 'Password must be at least 8 characters';
      setValidating(field, false);
      return false;
    }
    
    _errors.remove(field);
    setValidating(field, false);
    return true;
  }
}