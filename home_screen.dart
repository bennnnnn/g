import 'package:flutter/material.dart';
import '../browse/browse_screen.dart';
import '../matches/matches_screen.dart';
import '../chat/chat_screen.dart';
import '../gifts/gift_store_screen.dart';
import '../settings/settings_screen.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  UserModel? _currentUser;

  final List<Widget> _screens = [
    BrowseScreen(),
    MatchesScreen(),
    GiftStoreScreen(),
    SettingsScreen(),
  ];

  final List<BottomNavigationBarItem> _bottomNavItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.explore),
      activeIcon: Icon(Icons.explore),
      label: 'Discover',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.favorite_border),
      activeIcon: Icon(Icons.favorite),
      label: 'Matches',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.card_giftcard),
      activeIcon: Icon(Icons.card_giftcard),
      label: 'Gifts',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  void _loadCurrentUser() {
    setState(() {
      _currentUser = _authService.currentUser;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.pink,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: _bottomNavItems,
        ),
      ),
      floatingActionButton: _currentIndex == 1 // Show on Matches tab
          ? FloatingActionButton(
              onPressed: () {
                // Navigate to chat list or recent conversation
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      matchId: '', // You'd pass the actual match ID here
                      otherUser: UserModel(
                        id: 'temp',
                        phoneNumber: '',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    ),
                  ),
                );
              },
              backgroundColor: Colors.pink,
              child: const Icon(
                Icons.chat_bubble,
                color: Colors.white,
              ),
            )
          : null,
      floatingActionButtonLocation: _currentIndex == 1 
          ? FloatingActionButtonLocation.endFloat 
          : null,
    );
  }
}