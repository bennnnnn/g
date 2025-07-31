// screens/auth/otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/auth_state_provider.dart';
import '../../providers/validation_provider.dart';
import '../../services/analytics_service.dart';
import 'profile_setup_screen.dart';
import '../main/main_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  late AnimationController _animationController;
  late AnimationController _shakeAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _shakeOffset;
  
  Timer? _resendTimer;
  int _resendSeconds = 60;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startResendTimer();
    _trackScreenView();
    
    // Focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _shakeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _shakeOffset = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _shakeAnimationController,
      curve: Curves.elasticIn,
    ));
    
    _animationController.forward();
  }

  void _trackScreenView() {
    AnalyticsService().trackScreenView('otp_verification_screen');
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendSeconds = 60;
    });
    
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() {
          _resendSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    _animationController.dispose();
    _shakeAnimationController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _onOTPChanged(int index, String value) {
    if (value.length == 1) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyOTP();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String _getOTPCode() {
    return _controllers.map((controller) => controller.text).join();
  }

  void _clearOTP() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _triggerShakeAnimation() {
    _shakeAnimationController.reset();
    _shakeAnimationController.forward();
  }

  Future<void> _verifyOTP() async {
    final otp = _getOTPCode();
    
    if (otp.length != 6) {
      _triggerShakeAnimation();
      return;
    }

    final validationProvider = context.read<ValidationProvider>();
    
    if (!validationProvider.validateOTP(otp)) {
      _triggerShakeAnimation();
      return;
    }

    final authProvider = context.read<AuthStateProvider>();
    
    AnalyticsService().trackUserInteraction(
      'verify_otp_attempted',
      'otp_verification_screen',
      properties: {
        'phone_number': widget.phoneNumber,
      },
    );

    final success = await authProvider.verifyOTP(otp);
    
    if (success && mounted) {
      AnalyticsService().trackUserInteraction(
        'verify_otp_success',
        'otp_verification_screen',
      );
      
      // Check if user is new or existing
      if (authProvider.userModel?.isProfileComplete == true) {
        // Existing user with complete profile
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      } else {
        // New user or incomplete profile
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
        );
      }
    } else {
      // Show error and shake
      _triggerShakeAnimation();
      _clearOTP();
    }
  }

  Future<void> _resendOTP() async {
    if (_resendSeconds > 0) return;

    final authProvider = context.read<AuthStateProvider>();
    
    AnalyticsService().trackUserInteraction(
      'resend_otp_attempted',
      'otp_verification_screen',
    );

    final success = await authProvider.resendOTP(widget.phoneNumber);
    
    if (success) {
      _startResendTimer();
      _clearOTP();
      
      AnalyticsService().trackUserInteraction(
        'resend_otp_success',
        'otp_verification_screen',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification code sent!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  String _formatPhoneNumber(String phoneNumber) {
    // Simple formatting for display
    if (phoneNumber.length > 10) {
      final country = phoneNumber.substring(0, phoneNumber.length - 10);
      final number = phoneNumber.substring(phoneNumber.length - 10);
      final formatted = '${number.substring(0, 3)}-${number.substring(3, 6)}-${number.substring(6)}';
      return '$country $formatted';
    }
    return phoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE91E63),
              Color(0xFFAD1457),
              Color(0xFF880E4F),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back button
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Title
                        const Text(
                          'Enter Verification\nCode',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Subtitle
                        Text(
                          'We sent a 6-digit code to\n${_formatPhoneNumber(widget.phoneNumber)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withAlpha((0.8 * 255).round()),
                            height: 1.4,
                          ),
                        ),
                        
                        const SizedBox(height: 60),
                        
                        // OTP input form
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(25),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // OTP input fields
                              AnimatedBuilder(
                                animation: _shakeOffset,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(_shakeOffset.value, 0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: List.generate(6, (index) {
                                        return Container(
                                          width: 45,
                                          height: 55,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: _controllers[index].text.isNotEmpty
                                                  ? const Color(0xFFE91E63)
                                                  : Colors.grey[300]!,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: TextField(
                                            controller: _controllers[index],
                                            focusNode: _focusNodes[index],
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              LengthLimitingTextInputFormatter(1),
                                            ],
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              counterText: '',
                                            ),
                                            onChanged: (value) => _onOTPChanged(index, value),
                                          ),
                                        );
                                      }),
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 32),
                              
                              // Verify button
                              Consumer<AuthStateProvider>(
                                builder: (context, authProvider, child) {
                                  return SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: authProvider.isVerifyingOTP ? null : _verifyOTP,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE91E63),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(28),
                                        ),
                                        elevation: 8,
                                       shadowColor: const Color(0xFFE91E63).withAlpha(76),
                                      ),
                                      child: authProvider.isVerifyingOTP
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                              ),
                                            )
                                          : const Text(
                                              'Verify Code',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Resend code
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Didn't receive the code? ",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  Consumer<AuthStateProvider>(
                                    builder: (context, authProvider, child) {
                                      return TextButton(
                                        onPressed: (_resendSeconds == 0 && !authProvider.isSendingOTP) 
                                            ? _resendOTP
                                            : null,
                                        child: Text(
                                          _resendSeconds > 0 
                                              ? 'Resend in ${_resendSeconds}s'
                                              : authProvider.isSendingOTP
                                                  ? 'Sending...'
                                                  : 'Resend Code',
                                          style: TextStyle(
                                            color: (_resendSeconds == 0 && !authProvider.isSendingOTP)
                                                ? const Color(0xFFE91E63)
                                                : Colors.grey,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              
                              // Error display
                              Consumer<AuthStateProvider>(
                                builder: (context, authProvider, child) {
                                  if (authProvider.error != null) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.red[200]!,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              color: Colors.red[600],
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                authProvider.error!,
                                                style: TextStyle(
                                                  color: Colors.red[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Help text
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Change phone number',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withAlpha((0.8 * 255).round()),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}