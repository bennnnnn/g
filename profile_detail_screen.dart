import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../models/enums.dart';
import '../../services/analytics_service.dart';
import '../../services/location_service.dart';
import '../../services/validation_service.dart';
import '../../services/cache_service.dart';

class ProfileDetailScreen extends StatefulWidget {
  final UserModel user;
  final Function(UserModel)? onMessageTap;

  const ProfileDetailScreen({
    Key? key,
    required this.user,
    this.onMessageTap,
  }) : super(key: key);

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen>
    with TickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();
  final LocationService _locationService = LocationService();
  final ValidationService _validationService = ValidationService();
  final CacheService _cacheService = CacheService();

  late PageController _pageController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  int _currentPhotoIndex = 0;
  bool _isImageLoading = false;
  bool _showFullBio = false;

  @override
  void initState() {
    super.initState();
    _setupControllers();
    _setupAnimations();
    _trackProfileView();
    _cacheProfileData();
  }

  void _setupControllers() {
    _pageController = PageController();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));

    _fadeController.forward();
    _scaleController.forward();
  }

  Future<void> _trackProfileView() async {
    await _analyticsService.trackProfileEvent(
      event: ProfileAnalyticsEvent.profileViewed,
      targetUserId: widget.user.id,
    );
  }

  Future<void> _cacheProfileData() async {
    try {
      await _cacheService.cacheUser(widget.user);
    } catch (e) {
      debugPrint('Error caching profile data: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onPhotoChanged(int index) {
    setState(() {
      _currentPhotoIndex = index;
    });
    HapticFeedback.selectionClick();
  }

  void _previousPhoto() {
    if (_currentPhotoIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPhoto() {
    if (_currentPhotoIndex < widget.user.profilePhotos.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleBio() {
    setState(() {
      _showFullBio = !_showFullBio;
    });
    
    _analyticsService.trackUserInteraction(
      'bio_expanded',
      'profile_detail_screen',
      properties: {'user_id': widget.user.id},
    );
  }

  Future<void> _handleLike() async {
    await _analyticsService.trackUserInteraction(
      'profile_liked',
      'profile_detail_screen',
      properties: {'target_user_id': widget.user.id},
    );

    HapticFeedback.mediumImpact();
    _scaleController.reverse().then((_) {
      _scaleController.forward();
    });

    _showActionFeedback('Liked ${widget.user.name}!', Colors.pink);
  }

  Future<void> _handleSuperLike() async {
    await _analyticsService.trackUserInteraction(
      'profile_super_liked',
      'profile_detail_screen',
      properties: {'target_user_id': widget.user.id},
    );

    HapticFeedback.heavyImpact();
    _showActionFeedback('Super Liked ${widget.user.name}!', Colors.blue);
  }

  Future<void> _handlePass() async {
    await _analyticsService.trackUserInteraction(
      'profile_passed',
      'profile_detail_screen',
      properties: {'target_user_id': widget.user.id},
    );

    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  Future<void> _handleMessage() async {
    if (widget.onMessageTap != null) {
      await _analyticsService.trackUserInteraction(
        'message_button_tapped',
        'profile_detail_screen',
        properties: {'target_user_id': widget.user.id},
      );
      
      widget.onMessageTap!(widget.user);
    }
  }

  void _showActionFeedback(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReportOption('Inappropriate photos', 'inappropriate_photos'),
            _buildReportOption('Fake profile', 'fake_profile'),
            _buildReportOption('Harassment', 'harassment'),
            _buildReportOption('Spam', 'spam'),
            _buildReportOption('Other', 'other'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption(String reason, String reasonCode) {
    return ListTile(
      title: Text(reason),
      onTap: () async {
        Navigator.pop(context);
        
        await _analyticsService.trackUserInteraction(
          'profile_reported',
          'profile_detail_screen',
          properties: {
            'target_user_id': widget.user.id,
            'reason': reasonCode,
          },
        );
        
        _showActionFeedback(
          'Report submitted. Thank you for keeping our community safe.',
          Colors.green,
        );
      },
    );
  }

  void _showPhotoViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PhotoViewerScreen(
          photos: widget.user.profilePhotos,
          initialIndex: _currentPhotoIndex,
          userName: widget.user.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            children: [
              // Photo section
              Expanded(
                flex: 3,
                child: _buildPhotoSection(),
              ),
              
              // Profile info section
              Expanded(
                flex: 2,
                child: _buildProfileInfoSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.more_vert,
              color: Colors.white,
            ),
          ),
          onPressed: _showReportDialog,
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Stack(
      children: [
        // Photo PageView
        GestureDetector(
          onTap: _showPhotoViewer,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPhotoChanged,
            itemCount: widget.user.profilePhotos.length,
            itemBuilder: (context, index) {
              return Container(
                width: double.infinity,
                child: Image.network(
                  widget.user.profilePhotos[index],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    
                    return Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFE91E63),
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPhotoError();
                  },
                ),
              );
            },
          ),
        ),
        
        // Photo indicators
        if (widget.user.profilePhotos.length > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 20,
            right: 20,
            child: Row(
              children: widget.user.profilePhotos.asMap().entries.map((entry) {
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(
                      right: entry.key < widget.user.profilePhotos.length - 1 ? 4 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: entry.key == _currentPhotoIndex 
                          ? Colors.white 
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        
        // Tap areas for photo navigation
        if (widget.user.profilePhotos.length > 1) ...[
          // Left tap area
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.3,
            child: GestureDetector(
              onTap: _previousPhoto,
              child: Container(color: Colors.transparent),
            ),
          ),
          
          // Right tap area
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.3,
            child: GestureDetector(
              onTap: _nextPhoto,
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
        
        // Online status indicator
        if (_isUserOnline())
          Positioned(
            top: MediaQuery.of(context).padding.top + 100,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    color: Colors.white,
                    size: 8,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Online',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoError() {
    return Container(
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Photo unavailable',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name, age, and badges
            _buildNameSection(),
            
            const SizedBox(height: 12),
            
            // Location and distance
            _buildLocationSection(),
            
            const SizedBox(height: 20),
            
            // Bio section
            if (widget.user.bio != null && widget.user.bio!.isNotEmpty)
              _buildBioSection(),
            
            // Basic info section
            _buildBasicInfoSection(),
            
            const SizedBox(height: 24),
            
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameSection() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${widget.user.name}, ${widget.user.age}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        if (widget.user.isVerified) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
        if (widget.user.isPremium) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.amber, Colors.orange],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'PREMIUM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationSection() {
    final distance = _getDistanceText();
    final locationText = distance ?? widget.user.city ?? 'Location unknown';
    
    return Row(
      children: [
        Icon(
          Icons.location_on,
          color: Colors.grey[600],
          size: 16,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            locationText,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
        if (_isUserOnline())
          Container(
            margin: const EdgeInsets.only(left: 8),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  Widget _buildBioSection() {
    final bio = widget.user.bio!;
    final shouldShowMore = bio.length > 150;
    final displayText = _showFullBio || !shouldShowMore 
        ? bio 
        : '${bio.substring(0, 150)}...';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          displayText,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
        if (shouldShowMore) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _toggleBio,
            child: Text(
              _showFullBio ? 'Show less' : 'Show more',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFE91E63),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Basic Info',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        
        if (widget.user.gender != null)
          _buildInfoItem(
            icon: Icons.person,
            label: 'Gender',
            value: _getGenderString(widget.user.gender!),
          ),
        
        _buildInfoItem(
          icon: Icons.cake,
          label: 'Age',
          value: '${widget.user.age} years old',
        ),
        
        if (widget.user.city != null)
          _buildInfoItem(
            icon: Icons.location_on,
            label: 'Location',
            value: widget.user.city!,
          ),
        
        _buildInfoItem(
          icon: Icons.schedule,
          label: 'Joined',
          value: _formatJoinDate(widget.user.createdAt),
        ),
        
        if (widget.user.lastActiveAt != null)
          _buildInfoItem(
            icon: Icons.access_time,
            label: 'Last active',
            value: _formatLastActive(widget.user.lastActiveAt!),
          ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Pass button
        _buildActionButton(
          icon: Icons.close,
          color: Colors.grey[400]!,
          size: 60,
          onTap: _handlePass,
        ),
        
        // Message button (if callback provided)
        if (widget.onMessageTap != null)
          _buildActionButton(
            icon: Icons.chat_bubble,
            color: const Color(0xFFE91E63),
            size: 50,
            onTap: _handleMessage,
          ),
        
        // Super like button
        _buildActionButton(
          icon: Icons.star,
          color: Colors.blue,
          size: 50,
          onTap: _handleSuperLike,
        ),
        
        // Like button
        _buildActionButton(
          icon: Icons.favorite,
          color: Colors.pink,
          size: 60,
          onTap: _handleLike,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.4,
        ),
      ),
    );
  }

  String? _getDistanceText() {
    if (widget.user.latitude == null || widget.user.longitude == null) {
      return null;
    }
    
    final distance = _locationService.getDistanceToUser(
      userLatitude: widget.user.latitude!,
      userLongitude: widget.user.longitude!,
    );
    
    if (distance == null) return null;
    return _locationService.formatDistance(distance);
  }

  bool _isUserOnline() {
    if (widget.user.lastActiveAt == null) return false;
    final now = DateTime.now();
    final lastActive = widget.user.lastActiveAt!;
    return now.difference(lastActive).inMinutes < 15;
  }

  String _getGenderString(Gender gender) {
    switch (gender) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
    }
  }

  String _formatJoinDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
  }

  String _formatLastActive(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

// Full-screen photo viewer
class _PhotoViewerScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final String userName;

  const _PhotoViewerScreen({
    required this.photos,
    required this.initialIndex,
    required this.userName,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.userName}\'s Photos',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          Center(
            child: Text(
              '${_currentIndex + 1} / ${widget.photos.length}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                widget.photos[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 64,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}