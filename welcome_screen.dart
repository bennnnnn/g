// screens/auth/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/analytics_service.dart';
import 'phone_input_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _currentPage = 0;

  final List<WelcomePageData> _pages = [
    WelcomePageData(
      title: "Find Your Perfect Match",
      subtitle: "Discover meaningful connections with people who share your interests and values",
      image: "assets/images/welcome_1.png",
      color: const Color(0xFFE91E63),
    ),
    WelcomePageData(
      title: "Connect & Chat",
      subtitle: "Start conversations instantly. Send messages, photos, and gifts to make lasting impressions",
      image: "assets/images/welcome_2.png", 
      color: const Color(0xFF9C27B0),
    ),
    WelcomePageData(
      title: "Premium Experience",
      subtitle: "Unlock unlimited messaging, advanced filters, and exclusive features with our premium plans",
      image: "assets/images/welcome_3.png",
      color: const Color(0xFF673AB7),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _trackScreenView();
  }

  void _trackScreenView() {
    context.read<AnalyticsService>().trackScreenView('welcome_screen');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToPhoneInput();
    }
  }

  void _navigateToPhoneInput() {
    context.read<AnalyticsService>().trackUserInteraction(
      'get_started_tapped',
      'welcome_screen',
    );
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const PhoneInputScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _pages[_currentPage].color.withOpacity(0.8),
              _pages[_currentPage].color.withOpacity(0.6),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextButton(
                    onPressed: _navigateToPhoneInput,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Page view
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildWelcomePage(_pages[index]);
                    },
                  ),
                ),
              ),
              
              // Page indicators
              _buildPageIndicators(),
              
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Get Started Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pages[_currentPage].color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 8,
                          shadowColor: _pages[_currentPage].color.withOpacity(0.3),
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Terms and Privacy
                    Text.rich(
                      TextSpan(
                        text: 'By continuing, you agree to our ',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: _pages[_currentPage].color,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: _pages[_currentPage].color,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage(WelcomePageData page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration placeholder
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: page.color.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              _getIconForPage(_currentPage),
              size: 120,
              color: page.color,
            ),
          ),
          
          const SizedBox(height: 48),
          
          // Title
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Subtitle
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getIconForPage(int index) {
    switch (index) {
      case 0:
        return Icons.favorite;
      case 1:
        return Icons.chat_bubble;
      case 2:
        return Icons.star;
      default:
        return Icons.favorite;
    }
  }

  Widget _buildPageIndicators() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _pages.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index 
                  ? Colors.white 
                  : Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomePageData {
  final String title;
  final String subtitle;
  final String image;
  final Color color;

  WelcomePageData({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.color,
  });
}
   
 

 