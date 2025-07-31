
// screens/auth/profile_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_state_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/validation_provider.dart';
import '../../services/analytics_service.dart';
import '../main/main_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> 
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  int _currentStep = 0;
  final int _totalSteps = 4;
  
  // Form controllers
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  
  // Form data
  String? _selectedGender;
  String? _selectedInterestedIn;
  final List<File> _selectedPhotos = [];
  
  final List<String> _genderOptions = ['Male', 'Female', 'Non-binary', 'Other'];
  final List<String> _interests = ['Male', 'Female', 'Everyone'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
    _trackScreenView();
  }

  void _trackScreenView() {
    context.read<AnalyticsService>().trackScreenView('profile_setup_screen');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeProfile();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceedFromCurrentStep() {
    switch (_currentStep) {
      case 0: // Name and Age
        return _nameController.text.trim().isNotEmpty && 
               _ageController.text.isNotEmpty &&
               (int.tryParse(_ageController.text) ?? 0) >= 18;
      case 1: // Gender and Interested In
        return _selectedGender != null && _selectedInterestedIn != null;
      case 2: // Photos
        return _selectedPhotos.isNotEmpty;
      case 3: // Bio
        return true; // Bio is optional
      default:
        return false;
    }
  }

  Future<void> _pickPhoto() async {
    if (_selectedPhotos.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 6 photos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final source = await _showImageSourceDialog();
    
    if (source != null) {
      final image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedPhotos.add(File(image.path));
        });
        
        context.read<AnalyticsService>().trackUserInteraction(
          'photo_added',
          'profile_setup_screen',
          properties: {
            'photo_count': _selectedPhotos.length,
            'source': source.toString(),
          },
        );
      }
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Photo Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
    
    context.read<AnalyticsService>().trackUserInteraction(
      'photo_removed',
      'profile_setup_screen',
      properties: {
        'photo_count': _selectedPhotos.length,
      },
    );
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = context.read<UserProvider>();
    
    context.read<AnalyticsService>().trackUserInteraction(
      'profile_setup_completed',
      'profile_setup_screen',
      properties: {
        'name': _nameController.text.isNotEmpty,
        'age': _ageController.text.isNotEmpty,
        'gender': _selectedGender,
        'interested_in': _selectedInterestedIn,
        'photo_count': _selectedPhotos.length,
        'has_bio': _bioController.text.trim().isNotEmpty,
      },
    );

    // Update basic profile info
    final success = await userProvider.updateProfile(
      name: _nameController.text.trim(),
      age: int.tryParse(_ageController.text),
      bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      gender: _selectedGender,
      interestedIn: _selectedInterestedIn,
    );

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userProvider.error ?? 'Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Upload photos
    for (int i = 0; i < _selectedPhotos.length; i++) {
      await userProvider.uploadProfilePhoto(_selectedPhotos[i], i);
    }

    // Update location
    await userProvider.updateLocation();

    // Navigate to main app
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false,
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
          child: Column(
            children: [
              // Header with progress
              _buildHeader(),
              
              // Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildBasicInfoStep(),
                      _buildGenderStep(),
                      _buildPhotosStep(),
                      _buildBioStep(),
                    ],
                  ),
                ),
              ),
              
              // Bottom buttons
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Progress bar
          Row(
            children: [
              IconButton(
                onPressed: _currentStep > 0 ? _previousStep : () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _totalSteps,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${_currentStep + 1} of $_totalSteps',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Step title
          Text(
            _getStepTitle(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            _getStepSubtitle(),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'What\'s your name?';
      case 1:
        return 'Tell us about yourself';
      case 2:
        return 'Add your photos';
      case 3:
        return 'Write your bio';
      default:
        return '';
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'This will be displayed on your profile';
      case 1:
        return 'Help others find you';
      case 2:
        return 'Show your best self (1-6 photos)';
      case 3:
        return 'Tell others what makes you unique';
      default:
        return '';
    }
  }

  Widget _buildBasicInfoStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
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
              // Name field
              Consumer<ValidationProvider>(
                builder: (context, validator, child) {
                  return TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      hintText: 'Enter your first name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE91E63),
                          width: 2,
                        ),
                      ),
                      errorText: validator.getError('name'),
                    ),
                    onChanged: (value) {
                      validator.clearError('name');
                      setState(() {});
                    },
                    validator: (value) {
                      if (!validator.validateName(value)) {
                        return validator.getError('name');
                      }
                      return null;
                    },
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Age field
              Consumer<ValidationProvider>(
                builder: (context, validator, child) {
                  return TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Age',
                      hintText: 'Enter your age',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE91E63),
                          width: 2,
                        ),
                      ),
                      errorText: validator.getError('age'),
                    ),
                    onChanged: (value) {
                      validator.clearError('age');
                      setState(() {});
                    },
                    validator: (value) {
                      final age = int.tryParse(value ?? '');
                      if (!validator.validateAge(age)) {
                        return validator.getError('age');
                      }
                      return null;
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gender selection
            const Text(
              'I am',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            ...List.generate(_genderOptions.length, (index) {
              final option = _genderOptions[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: _selectedGender,
                  activeColor: const Color(0xFFE91E63),
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
              );
            }),
            
            const SizedBox(height: 32),
            
            // Interested in selection
            const Text(
              'Interested in',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            ...List.generate(_interests.length, (index) {
              final option = _interests[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: _selectedInterestedIn,
                  activeColor: const Color(0xFFE91E63),
                  onChanged: (value) {
                    setState(() {
                      _selectedInterestedIn = value;
                    });
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
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
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  if (index < _selectedPhotos.length) {
                    return _buildPhotoItem(_selectedPhotos[index], index);
                  } else {
                    return _buildAddPhotoButton();
                  }
                },
              ),
            ),
            
            if (_selectedPhotos.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Add at least one photo to continue',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoItem(File photo, int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(photo),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
        if (index == 0)
           Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Text(
                'Main Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: 40,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              'Add Photo',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBioStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
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
            Consumer<ValidationProvider>(
              builder: (context, validator, child) {
                return TextFormField(
                  controller: _bioController,
                  maxLines: 6,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: 'About Me (Optional)',
                    hintText: 'Tell others what makes you unique...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE91E63),
                        width: 2,
                      ),
                    ),
                    alignLabelWithHint: true,
                    errorText: validator.getError('bio'),
                  ),
                  onChanged: (value) {
                    validator.clearError('bio');
                    setState(() {});
                  },
                  validator: (value) {
                    if (!validator.validateBio(value)) {
                      return validator.getError('bio');
                    }
                    return null;
                  },
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Share your interests, hobbies, or what you\'re looking for. This helps others get to know you better!',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Main action button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Consumer2<UserProvider, AuthStateProvider>(
              builder: (context, userProvider, authProvider, child) {
                final isLoading = userProvider.isLoading || 
                                 userProvider.isUpdatingProfile ||
                                 userProvider.isUploadingPhoto;
                
                return ElevatedButton(
                  onPressed: (!_canProceedFromCurrentStep() || isLoading) 
                      ? null 
                      : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFFE91E63).withOpacity(0.3),
                  ),
                  child: isLoading
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
                      : Text(
                          _currentStep == _totalSteps - 1 
                              ? 'Complete Profile' 
                              : 'Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                );
              },
            ),
          ),
          
          // Skip button for optional steps
          if (_currentStep == 3) // Bio step is optional
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton(
                onPressed: _completeProfile,
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          
          // Error display
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              if (userProvider.error != null) {
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
                            userProvider.error!,
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
    );
  }
}