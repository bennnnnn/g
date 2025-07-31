
// screens/auth/phone_input_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_state_provider.dart';
import '../../providers/validation_provider.dart';
import '../../services/analytics_service.dart';
import 'otp_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> 
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  String _selectedCountryCode = '+1';
  String _selectedCountryFlag = '🇺🇸';
  
  final Map<String, Map<String, String>> _countryCodes = {
    '+1': {'name': 'United States', 'flag': '🇺🇸'},
    '+44': {'name': 'United Kingdom', 'flag': '🇬🇧'},
    '+49': {'name': 'Germany', 'flag': '🇩🇪'},
    '+33': {'name': 'France', 'flag': '🇫🇷'},
    '+39': {'name': 'Italy', 'flag': '🇮🇹'},
    '+34': {'name': 'Spain', 'flag': '🇪🇸'},
    // ignore: equal_keys_in_map
    '+1': {'name': 'Canada', 'flag': '🇨🇦'},
    '+61': {'name': 'Australia', 'flag': '🇦🇺'},
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    ));
    
    _animationController.forward();
    _trackScreenView();
  }

  void _trackScreenView() {
    context.read<AnalyticsService>().trackScreenView('phone_input_screen');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _selectCountry() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildCountrySelector(),
    );
  }

  Widget _buildCountrySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Country',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _countryCodes.length,
              itemBuilder: (context, index) {
                final code = _countryCodes.keys.elementAt(index);
                final country = _countryCodes[code]!;
                
                return ListTile(
                  leading: Text(
                    country['flag']!,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(country['name']!),
                  trailing: Text(
                    code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedCountryCode = code;
                      _selectedCountryFlag = country['flag']!;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    final validationProvider = context.read<ValidationProvider>();
    final fullPhoneNumber = '$_selectedCountryCode${_phoneController.text}';
    
    if (!validationProvider.validatePhoneNumber(fullPhoneNumber)) {
      return;
    }

    final authProvider = context.read<AuthStateProvider>();
    
    context.read<AnalyticsService>().trackUserInteraction(
      'send_otp_attempted',
      'phone_input_screen',
      properties: {
        'country_code': _selectedCountryCode,
        'phone_length': _phoneController.text.length,
      },
    );

    final success = await authProvider.sendOTP(fullPhoneNumber);
    
    if (success && mounted) {
      context.read<AnalyticsService>().trackUserInteraction(
        'send_otp_success',
        'phone_input_screen',
      );
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OTPVerificationScreen(
            phoneNumber: fullPhoneNumber,
          ),
        ),
      );
    }
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
                          'Enter Your\nPhone Number',
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
                          'We\'ll send you a verification code to confirm your number',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),
                        
                        const SizedBox(height: 60),
                        
                        // Phone input form
                        Form(
                          key: _formKey,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Country selector and phone input
                                Row(
                                  children: [
                                    // Country selector
                                    GestureDetector(
                                      onTap: _selectCountry,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _selectedCountryFlag,
                                              style: const TextStyle(fontSize: 20),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _selectedCountryCode,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.arrow_drop_down,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 12),
                                    
                                    // Phone number input
                                    Expanded(
                                      child: Consumer<ValidationProvider>(
                                        builder: (context, validator, child) {
                                          return TextFormField(
                                            controller: _phoneController,
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              LengthLimitingTextInputFormatter(10),
                                            ],
                                            decoration: InputDecoration(
                                              hintText: 'Phone number',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: Colors.grey[300]!,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: Colors.grey[300]!,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE91E63),
                                                  width: 2,
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Colors.red,
                                                ),
                                              ),
                                              contentPadding: const EdgeInsets.all(16),
                                              errorText: validator.getError('phone'),
                                            ),
                                            onChanged: (value) {
                                              validator.clearError('phone');
                                            },
                                            validator: (value) {
                                              final fullNumber = '$_selectedCountryCode$value';
                                              if (!validator.validatePhoneNumber(fullNumber)) {
                                                return validator.getError('phone');
                                              }
                                              return null;
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Send OTP button
                                Consumer<AuthStateProvider>(
                                  builder: (context, authProvider, child) {
                                    return SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: authProvider.isOtpSent ? null : _sendOTP,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE91E63),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(28),
                                          ),
                                          elevation: 8,
                                          shadowColor: const Color(0xFFE91E63).withOpacity(0.3),
                                        ),
                                        child: authProvider.isSendingOTP
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
                                                'Send Verification Code',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    );
                                  },
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
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Help text
                        Center(
                          child: Text(
                            'By providing your phone number, you agree to receive SMS messages for verification purposes.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
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
