
// screens/auth/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_state_provider.dart';
import '../../services/analytics_service.dart';
import 'welcome_screen.dart';
import 'profile_setup_screen.dart';
import '../main/main_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _trackAppStart();
  }

  void _trackAppStart() {
    context.read<AnalyticsService>().trackEvent(
      AnalyticsEvent.appStart,
      properties: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthStateProvider>(
      builder: (context, authProvider, child) {
        // Show loading while initializing
        if (authProvider.isInitializing) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFE91E63),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // User is not authenticated
        if (!authProvider.isAuthenticated) {
          return const WelcomeScreen();
        }

        // User is authenticated but profile is incomplete
        if (!authProvider.isProfileComplete) {
          return const ProfileSetupScreen();
        }

        // User is authenticated with complete profile
        return const MainScreen();
      },
    );
  }
}