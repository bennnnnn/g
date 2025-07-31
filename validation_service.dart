class ValidationService {
  static final ValidationService _instance = ValidationService._internal();
  factory ValidationService() => _instance;
  ValidationService._internal();

  // PHONE NUMBER VALIDATION

  /// Validate phone number
  ValidationResult validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return ValidationResult.error('Phone number is required');
    }

    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    
    // Check length (10-15 digits)
    if (digitsOnly.length < 10) {
      return ValidationResult.error('Phone number too short');
    }
    
    if (digitsOnly.length > 15) {
      return ValidationResult.error('Phone number too long');
    }

    // Basic format validation
    if (!RegExp(r'^\d{10,15}$').hasMatch(digitsOnly)) {
      return ValidationResult.error('Invalid phone number format');
    }

    return ValidationResult.success();
  }

  /// Format phone number for display
  String formatPhoneNumber(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length == 10) {
      // US format: (XXX) XXX-XXXX
      return '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    }
    
    return phone; // Return as-is if not standard US format
  }

  /// Normalize phone number for storage
  String normalizePhoneNumber(String phone) {
    String digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    
    // Add country code if missing (assume US +1)
    if (digitsOnly.length == 10) {
      digitsOnly = '1$digitsOnly';
    }
    
    return '+$digitsOnly';
  }

  // OTP VALIDATION

  /// Validate OTP code
  ValidationResult validateOTP(String? otp) {
    if (otp == null || otp.isEmpty) {
      return ValidationResult.error('Verification code is required');
    }

    if (otp.length != 6) {
      return ValidationResult.error('Verification code must be 6 digits');
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      return ValidationResult.error('Verification code must contain only numbers');
    }

    return ValidationResult.success();
  }

  // USER PROFILE VALIDATION

  /// Validate user name
  ValidationResult validateName(String? name) {
    if (name == null || name.isEmpty) {
      return ValidationResult.error('Name is required');
    }

    if (name.trim().length < 2) {
      return ValidationResult.error('Name must be at least 2 characters');
    }

    if (name.trim().length > 30) {
      return ValidationResult.error('Name must be less than 30 characters');
    }

    // Check for invalid characters
    if (!RegExp(r"^[\p{L}\s'\-\.]+$", unicode: true).hasMatch(name.trim())) {
  return ValidationResult.error('Name contains invalid characters');
}

    return ValidationResult.success();
  }

  /// Validate age
  ValidationResult validateAge(int? age) {
    if (age == null) {
      return ValidationResult.error('Age is required');
    }

    if (age < 18) {
      return ValidationResult.error('You must be at least 18 years old');
    }

    if (age > 100) {
      return ValidationResult.error('Please enter a valid age');
    }

    return ValidationResult.success();
  }

  /// Validate bio
  ValidationResult validateBio(String? bio) {
    if (bio == null || bio.isEmpty) {
      return ValidationResult.success(); // Bio is optional
    }

    if (bio.length > 500) {
      return ValidationResult.error('Bio must be less than 500 characters');
    }

    // Check for inappropriate content (basic)
    if (_containsInappropriateContent(bio)) {
      return ValidationResult.error('Bio contains inappropriate content');
    }

    return ValidationResult.success();
  }

  /// Validate gender
  ValidationResult validateGender(String? gender) {
    if (gender == null || gender.isEmpty) {
      return ValidationResult.error('Please select your gender');
    }

    final validGenders = ['Male', 'Female', 'Non-binary', 'Other'];
    if (!validGenders.contains(gender)) {
      return ValidationResult.error('Please select a valid gender option');
    }

    return ValidationResult.success();
  }

  // MESSAGE VALIDATION

  /// Validate message content
  ValidationResult validateMessage(String? message) {
    if (message == null || message.isEmpty) {
      return ValidationResult.error('Message cannot be empty');
    }

    if (message.trim().isEmpty) {
      return ValidationResult.error('Message cannot be empty');
    }

    if (message.length > 1000) {
      return ValidationResult.error('Message too long (max 1000 characters)');
    }

    // Check for spam patterns
    if (_isSpamMessage(message)) {
      return ValidationResult.error('Message contains spam content');
    }

    // Check for inappropriate content
    if (_containsInappropriateContent(message)) {
      return ValidationResult.error('Message contains inappropriate content');
    }

    return ValidationResult.success();
  }

  /// Enhanced message validation with spam detection
  ValidationResult validateMessageWithSpamCheck(String? message) {
    // First do basic validation
    final basicValidation = validateMessage(message);
    if (!basicValidation.isValid) {
      return basicValidation;
    }

    final msg = message!.trim();

    // Additional spam checks
    if (_isRepeatedText(msg)) {
      return ValidationResult.error('Message contains too much repeated text');
    }

    if (_containsPhoneNumber(msg)) {
      return ValidationResult.error('Please don\'t share phone numbers in messages');
    }

    if (_containsEmail(msg)) {
      return ValidationResult.error('Please don\'t share email addresses in messages');
    }

    return ValidationResult.success();
  }

  // MOBILE PAYMENT VALIDATION

  /// Validate mobile payment (in-app purchases)
  ValidationResult validateMobilePayment({
    required String? productId,
    required double? amount,
    String? recipientId,
    String? platform,
  }) {
    // Basic validation
    if (productId == null || productId.isEmpty) {
      return ValidationResult.error('Invalid product selection');
    }

    if (amount == null || amount <= 0) {
      return ValidationResult.error('Invalid payment amount');
    }

    // Mobile app specific validation - reasonable limits for mobile payments
    if (amount > 99.99) {
      return ValidationResult.error('Payment amount too high for mobile app purchases');
    }

    if (amount < 0.99) {
      return ValidationResult.error('Payment amount too low (minimum \$0.99)');
    }

    // Validate product ID format for mobile stores
    if (!_isValidMobileProductId(productId)) {
      return ValidationResult.error('Invalid product identifier format');
    }

    // Validate platform if provided
    if (platform != null && !_isValidMobilePlatform(platform)) {
      return ValidationResult.error('Invalid payment platform');
    }

    // For gift purchases, validate recipient
    if (recipientId != null) {
      if (recipientId.isEmpty || recipientId.length < 10) {
        return ValidationResult.error('Invalid recipient');
      }
    }

    // Validate amount precision (mobile stores use 2 decimal places)
    if (_hasInvalidPrecision(amount)) {
      return ValidationResult.error('Invalid amount precision (use 2 decimal places)');
    }

    return ValidationResult.success();
  }

  // BUSINESS RULES VALIDATION

  /// Check if user can message another user (free user limits)
  ValidationResult validateMessageLimits({
    required bool isUserPremium,
    required bool isConversationPremium,
    required int currentDailyUsers,
    required int messagesWithUser,
  }) {
    // Premium users have no limits
    if (isUserPremium || isConversationPremium) {
      return ValidationResult.success();
    }

    // Check daily user limit (2 users per day)
    if (currentDailyUsers >= 2 && messagesWithUser == 0) {
      return ValidationResult.error(
        'Daily limit reached. You can message 2 users per day. Upgrade for unlimited messaging.'
      );
    }

    // Check messages per user limit (3 messages per user)
    if (messagesWithUser >= 3) {
      return ValidationResult.error(
        'Message limit reached with this user (3 messages). Upgrade for unlimited messaging.'
      );
    }

    return ValidationResult.success();
  }

  /// Validate subscription plan selection
  ValidationResult validateSubscriptionPlan(String? plan) {
    if (plan == null || plan.isEmpty) {
      return ValidationResult.error('Please select a subscription plan');
    }

    final validPlans = ['daily', 'weekly', 'monthly'];
    if (!validPlans.contains(plan.toLowerCase())) {
      return ValidationResult.error('Invalid subscription plan');
    }

    return ValidationResult.success();
  }

  /// Validate gift selection
  ValidationResult validateGiftPurchase({
    required String? giftId,
    required String? recipientId,
    required double? amount,
  }) {
    if (giftId == null || giftId.isEmpty) {
      return ValidationResult.error('Please select a gift');
    }

    if (recipientId == null || recipientId.isEmpty) {
      return ValidationResult.error('Invalid recipient');
    }

    if (amount == null || amount <= 0) {
      return ValidationResult.error('Invalid gift amount');
    }

    if (amount > 100) {
      return ValidationResult.error('Gift amount too high');
    }

    return ValidationResult.success();
  }

  // LOCATION VALIDATION

  /// Validate location coordinates
  ValidationResult validateLocation({
    required double? latitude,
    required double? longitude,
  }) {
    if (latitude == null || longitude == null) {
      return ValidationResult.error('Invalid location coordinates');
    }

    if (latitude < -90 || latitude > 90) {
      return ValidationResult.error('Invalid latitude');
    }

    if (longitude < -180 || longitude > 180) {
      return ValidationResult.error('Invalid longitude');
    }

    return ValidationResult.success();
  }

  // FILE VALIDATION

  /// Validate photo file
  ValidationResult validatePhotoFile({
    required String? filePath,
    required int? fileSizeBytes,
  }) {
    if (filePath == null || filePath.isEmpty) {
      return ValidationResult.error('No file selected');
    }

    // Check file extension
    final validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
    final fileExtension = filePath.toLowerCase().substring(filePath.lastIndexOf('.'));
    
    if (!validExtensions.contains(fileExtension)) {
      return ValidationResult.error('Invalid file format. Use JPG, PNG, or WebP');
    }

    // Check file size (5MB limit)
    if (fileSizeBytes != null && fileSizeBytes > 5 * 1024 * 1024) {
      return ValidationResult.error('File too large. Maximum size is 5MB');
    }

    return ValidationResult.success();
  }

  // SEARCH VALIDATION

  /// Validate search filters
  ValidationResult validateSearchFilters({
    int? minAge,
    int? maxAge,
    double? maxDistance,
  }) {
    if (minAge != null && maxAge != null) {
      if (minAge > maxAge) {
        return ValidationResult.error('Minimum age cannot be greater than maximum age');
      }
      
      if (minAge < 18) {
        return ValidationResult.error('Minimum age must be 18 or older');
      }
      
      if (maxAge > 100) {
        return ValidationResult.error('Maximum age cannot exceed 100');
      }
    }

    if (maxDistance != null) {
      if (maxDistance < 1) {
        return ValidationResult.error('Distance must be at least 1 km');
      }
      
      if (maxDistance > 500) {
        return ValidationResult.error('Distance cannot exceed 500 km');
      }
    }

    return ValidationResult.success();
  }

  // HELPER METHODS

  /// Check for inappropriate content (basic implementation)
  bool _containsInappropriateContent(String text) {
    final inappropriateWords = [
      // Add inappropriate words here
      'spam', 'scam', 'fake', 'nude', 'sex', 'porn'
      // In production, use a comprehensive content filter
    ];

    final lowerText = text.toLowerCase();
    return inappropriateWords.any((word) => lowerText.contains(word));
  }

  /// Check for spam patterns
  bool _isSpamMessage(String message) {
    // Check for repeated characters
    if (RegExp(r'(.)\1{4,}').hasMatch(message)) {
      return true;
    }

    // Check for excessive capitalization
    final upperCaseCount = message.replaceAll(RegExp(r'[^A-Z]'), '').length;
    if (upperCaseCount > message.length * 0.7 && message.length > 10) {
      return true;
    }

    // Check for URLs
    if (RegExp(r'http[s]?://|www\.').hasMatch(message)) {
      return true;
    }

    // Check for phone numbers in messages
    if (RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b').hasMatch(message)) {
      return true;
    }

    return false;
  }

  /// Check for repeated text patterns
  bool _isRepeatedText(String text) {
    // Check for same character repeated more than 5 times
    if (RegExp(r'(.)\1{5,}').hasMatch(text)) {
      return true;
    }

    // Check for same word repeated more than 3 times
    final words = text.toLowerCase().split(' ');
    final wordCounts = <String, int>{};
    for (final word in words) {
      if (word.length > 2) {
        wordCounts[word] = (wordCounts[word] ?? 0) + 1;
        if (wordCounts[word]! > 3) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check for phone numbers
  bool _containsPhoneNumber(String text) {
    return RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b').hasMatch(text) ||
           RegExp(r'\b\+\d{1,3}[-.]?\d{3,4}[-.]?\d{3,4}[-.]?\d{3,4}\b').hasMatch(text);
  }

  /// Check for email addresses
  bool _containsEmail(String text) {
    return RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b').hasMatch(text);
  }

  /// Validate if product ID follows mobile store conventions
  bool _isValidMobileProductId(String productId) {
    // Product IDs should be lowercase with underscores, 3-100 characters
    if (productId.length < 3 || productId.length > 100) {
      return false;
    }

    // Should contain only lowercase letters, numbers, underscores, and dots
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(productId)) {
      return false;
    }

    // Should not start or end with underscore or dot
    if (productId.startsWith('_') || productId.endsWith('_') ||
        productId.startsWith('.') || productId.endsWith('.')) {
      return false;
    }

    // Should not contain consecutive underscores or dots
    if (productId.contains('__') || productId.contains('..')) {
      return false;
    }

    return true;
  }

  /// Validate mobile platform
  bool _isValidMobilePlatform(String platform) {
    const validPlatforms = ['app_store', 'google_play', 'AppStore', 'GooglePlay'];
    return validPlatforms.contains(platform);
  }

  /// Check if amount has invalid precision for mobile payments
  bool _hasInvalidPrecision(double amount) {
    // Convert to string and check decimal places
    final amountString = amount.toStringAsFixed(10);
    final decimalIndex = amountString.indexOf('.');
    
    if (decimalIndex == -1) {
      return false; // No decimal places is fine
    }
    
    // Check if there are more than 2 significant decimal places
    final decimalPart = amountString.substring(decimalIndex + 1);
    final significantDecimals = decimalPart.replaceAll(RegExp(r'0+$'), '');
    
    return significantDecimals.length > 2;
  }

  /// Validate multiple fields at once
  List<String> validateProfileData({
    String? name,
    int? age,
    String? gender,
    String? interestedIn,
    String? bio,
  }) {
    final errors = <String>[];

    final nameResult = validateName(name);
    if (!nameResult.isValid) errors.add(nameResult.error!);

    final ageResult = validateAge(age);
    if (!ageResult.isValid) errors.add(ageResult.error!);

    final genderResult = validateGender(gender);
    if (!genderResult.isValid) errors.add(genderResult.error!);

    final interestedInResult = validateGender(interestedIn); // Same validation
    if (!interestedInResult.isValid) errors.add('Interested in: ${interestedInResult.error!}');

    final bioResult = validateBio(bio);
    if (!bioResult.isValid) errors.add(bioResult.error!);

    return errors;
  }
}

/// Validation result wrapper
class ValidationResult {
  final bool isValid;
  final String? error;

  const ValidationResult._({
    required this.isValid,
    this.error,
  });

  factory ValidationResult.success() {
    return const ValidationResult._(isValid: true);
  }

  factory ValidationResult.error(String error) {
    return ValidationResult._(isValid: false, error: error);
  }
}