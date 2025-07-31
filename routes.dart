
// lib/config/routes.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_state_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/phone_input_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../main_shell.dart';
import '../screens/discover/discover_screen.dart';
import '../screens/messages/conversations_screen.dart';
import '../screens/messages/chat_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/subscription/subscription_screen.dart';
import '../screens/gifts/gift_store_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    
    // Redirect logic based on auth state
    redirect: (BuildContext context, GoRouterState state) {
      final authProvider = context.read<AuthStateProvider>();
      final bool isLoggedIn = authProvider.isAuthenticated;
      final bool isLoading = authProvider.isLoading;
      final String location = state.location;
      
      // Show splash while loading
      if (isLoading && location != '/splash') {
        return '/splash';
      }
      
      // If not logged in and trying to access protected routes
      if (!isLoggedIn && !_isPublicRoute(location)) {
        return '/welcome';
      }
      
      // If logged in and trying to access auth routes
      if (isLoggedIn && _isAuthRoute(location)) {
        return '/main/discover';
      }
      
      return null; // No redirect needed
    },
    
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Authentication Routes
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      
      GoRoute(
        path: '/phone-input',
        name: 'phone-input',
        builder: (context, state) => const PhoneInputScreen(),
      ),
      
      GoRoute(
        path: '/otp',
        name: 'otp',
        builder: (context, state) {
          final phoneNumber = state.queryParameters['phone'] ?? '';
          final verificationId = state.queryParameters['verificationId'] ?? '';
          return OtpScreen(
            phoneNumber: phoneNumber,
            verificationId: verificationId,
          );
        },
      ),
      
      GoRoute(
        path: '/profile-setup',
        name: 'profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      
      // Main Shell with Bottom Navigation
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          // Discover Tab
          GoRoute(
            path: '/main/discover',
            name: 'discover',
            builder: (context, state) => const DiscoverScreen(),
            routes: [
              // User Profile Detail
              GoRoute(
                path: '/user/:userId',
                name: 'user-profile',
                builder: (context, state) {
                  final userId = state.pathParameters['userId']!;
                  return UserProfileScreen(userId: userId);
                },
              ),
            ],
          ),
          
          // Messages Tab
          GoRoute(
            path: '/main/messages',
            name: 'messages',
            builder: (context, state) => const ConversationsScreen(),
            routes: [
              // Individual Chat
              GoRoute(
                path: '/chat/:conversationId',
                name: 'chat',
                builder: (context, state) {
                  final conversationId = state.pathParameters['conversationId']!;
                  final otherUserName = state.queryParameters['userName'] ?? 'Chat';
                  return ChatScreen(
                    conversationId: conversationId,
                    otherUserName: otherUserName,
                  );
                },
              ),
            ],
          ),
          
          // Profile Tab
          GoRoute(
            path: '/main/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              // Edit Profile
              GoRoute(
                path: '/edit',
                name: 'edit-profile',
                builder: (context, state) => const EditProfileScreen(),
              ),
              
              // Settings
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      
      // Standalone Routes (Outside Bottom Navigation)
      
      // Subscription
      GoRoute(
        path: '/subscription',
        name: 'subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      
      // Gift Store
      GoRoute(
        path: '/gift-store',
        name: 'gift-store',
        builder: (context, state) {
          final recipientUserId = state.queryParameters['recipientId'];
          final conversationId = state.queryParameters['conversationId'];
          return GiftStoreScreen(
            recipientUserId: recipientUserId,
            conversationId: conversationId,
          );
        },
      ),
      
      // Admin Routes (Protected)
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminDashboardScreen(),
        redirect: (context, state) {
          // Check if user is admin
          final authProvider = context.read<AuthStateProvider>();
          if (!authProvider.isAuthenticated) {
            return '/welcome';
          }
          // TODO: Add admin check when we have the provider
          // if (!authProvider.userModel?.isAdmin ?? true) {
          //   return '/main/discover';
          // }
          return null;
        },
      ),
      
      // 404 Error Route
      GoRoute(
        path: '/error',
        name: 'error',
        builder: (context, state) => const ErrorScreen(),
      ),
    ],
    
    // Error handling
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
  
  // Helper methods to determine route types
  static bool _isPublicRoute(String location) {
    const publicRoutes = [
      '/splash',
      '/welcome',
      '/phone-input',
      '/otp',
      '/profile-setup',
      '/error',
    ];
    return publicRoutes.any((route) => location.startsWith(route));
  }
  
  static bool _isAuthRoute(String location) {
    const authRoutes = [
      '/welcome',
      '/phone-input',
      '/otp',
      '/profile-setup',
    ];
    return authRoutes.any((route) => location.startsWith(route));
  }
}

// Extension for easy navigation
extension AppRouterExtension on BuildContext {
  // Navigate to routes
  void goToWelcome() => go('/welcome');
  void goToPhoneInput() => go('/phone-input');
  void goToOtp(String phone, String verificationId) => 
      go('/otp?phone=$phone&verificationId=$verificationId');
  void goToProfileSetup() => go('/profile-setup');
  void goToDiscover() => go('/main/discover');
  void goToMessages() => go('/main/messages');
  void goToProfile() => go('/main/profile');
  void goToSubscription() => go('/subscription');
  void goToGiftStore({String? recipientId, String? conversationId}) {
    String path = '/gift-store';
    List<String> params = [];
    if (recipientId != null) params.add('recipientId=$recipientId');
    if (conversationId != null) params.add('conversationId=$conversationId');
    if (params.isNotEmpty) path += '?${params.join('&')}';
    go(path);
  }
  void goToAdmin() => go('/admin');
  
  // Navigate to specific user profile
  void goToUserProfile(String userId) => go('/main/discover/user/$userId');
  
  // Navigate to chat
  void goToChat(String conversationId, {String? userName}) {
    String path = '/main/messages/chat/$conversationId';
    if (userName != null) path += '?userName=$userName';
    go(path);
  }
  
  // Navigate to settings
  void goToSettings() => go('/main/profile/settings');
  void goToEditProfile() => go('/main/profile/edit');
}

// Error Screen
class ErrorScreen extends StatelessWidget {
  final Exception? error;
  
  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goToDiscover(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Oops! Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? 'An unexpected error occurred',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.goToDiscover(),
                icon: const Icon(Icons.home),
                label: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// User Profile Screen (placeholder)
class UserProfileScreen extends StatelessWidget {
  final String userId;
  
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Center(
        child: Text('User Profile: $userId'),
      ),
    );
  }
}