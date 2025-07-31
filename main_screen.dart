// screens/main/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_state_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/subscription_provider.dart';
import '../discovery/discovery_screen.dart';
import '../conversations/conversations_screen.dart';
import '../profile/my_profile_screen.dart';
import '../subscription/subscription_plans_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = [
    const DiscoveryScreen(),
    const ConversationsScreen(),
    const SubscriptionPlansScreen(),
    const MyProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<AuthStateProvider, UserProvider, ConversationProvider, SubscriptionProvider>(
      builder: (context, auth, user, conversation, subscription, child) {
        // Show loading if still initializing
        if (auth.isInitializing) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Redirect to auth if not authenticated
        if (!auth.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/auth');
          });
          return const SizedBox.shrink();
        }

        return Scaffold(
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: _screens,
          ),
          bottomNavigationBar: _buildBottomNavigationBar(conversation, subscription),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(
    ConversationProvider conversation,
    SubscriptionProvider subscription,
  ) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      onTap: _onTabTapped,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.explore),
          label: 'Discover',
        ),
        BottomNavigationBarItem(
          icon: _buildMessagesIcon(conversation.totalUnreadCount),
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: _buildPremiumIcon(subscription.isPremium),
          label: 'Premium',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  Widget _buildMessagesIcon(int unreadCount) {
    if (unreadCount > 0) {
      return Stack(
        children: [
          const Icon(Icons.chat_bubble_outline),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }
    return const Icon(Icons.chat_bubble_outline);
  }

  Widget _buildPremiumIcon(bool isPremium) {
    if (isPremium) {
      return const Icon(
        Icons.star,
        color: Colors.amber,
      );
    }
    return const Icon(Icons.star_border);
  }
}