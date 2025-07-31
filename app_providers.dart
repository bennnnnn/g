//lib/providers/app_providers.dart
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../providers/theme_provider.dart';
import '../providers/admin_provider.dart';
import '../providers/validation_provider.dart';
import '../providers/cache_provider.dart';
import '../providers/auth_state_provider.dart';
import '../providers/user_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/discovery_provider.dart';
import '../providers/message_provider.dart';

class AppProviders {
  static List<SingleChildWidget> get providers => [
    // Theme Provider (Independent)
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
    ),
    
    // Validation Provider (Independent utility)
    ChangeNotifierProvider(
      create: (_) => ValidationProvider(),
    ),
    
    // Cache Provider (Independent utility)
    ChangeNotifierProvider(
      create: (_) => CacheProvider()..initialize(),
    ),
    
    // Auth State Provider (Core - other providers depend on this)
    ChangeNotifierProvider(
      create: (_) => AuthStateProvider(),
    ),
    
    // User Provider (depends on auth)
    ChangeNotifierProxyProvider<AuthStateProvider, UserProvider>(
      create: (_) => UserProvider(),
      update: (_, auth, previous) {
        final provider = previous ?? UserProvider();
        if (auth.isAuthenticated && auth.userModel != null) {
          provider.updateCurrentUser(auth.userModel);
          if (provider.currentUser == null) {
            provider.loadCurrentUser();
          }
        } else if (!auth.isAuthenticated) {
          provider.updateCurrentUser(null);
        }
        return provider;
      },
    ),
    
    // Subscription Provider (depends on auth)
    ChangeNotifierProxyProvider<AuthStateProvider, SubscriptionProvider>(
      create: (_) => SubscriptionProvider(),
      update: (_, auth, previous) {
        final provider = previous ?? SubscriptionProvider();
        provider.updateAuth(auth);
        return provider;
      },
    ),
    
    // Discovery Provider (depends on auth and user)
    ChangeNotifierProxyProvider2<AuthStateProvider, UserProvider, DiscoveryProvider>(
      create: (_) => DiscoveryProvider(),
      update: (_, auth, user, previous) {
        final provider = previous ?? DiscoveryProvider();
        provider.updateAuth(auth);
        provider.updateUser(user);
        return provider;
      },
    ),
    
    // Conversation Provider (depends on auth and user)
    ChangeNotifierProxyProvider2<AuthStateProvider, UserProvider, ConversationProvider>(
      create: (_) => ConversationProvider(),
      update: (_, auth, user, previous) {
        final provider = previous ?? ConversationProvider();
        provider.updateAuth(auth);
        provider.updateUser(user);
        return provider;
      },
    ),
    
    // Message Provider (depends on user)
    ChangeNotifierProxyProvider<UserProvider, MessageProvider>(
      create: (_) => MessageProvider(),
      update: (_, user, previous) {
        final provider = previous ?? MessageProvider();
        provider.updateCurrentUser(user.currentUser);
        return provider;
      },
    ),
    
    // Admin Provider (depends on auth)
    ChangeNotifierProxyProvider<AuthStateProvider, AdminProvider>(
      create: (_) => AdminProvider(),
      update: (_, auth, previous) {
        final provider = previous ?? AdminProvider();
        if (auth.isAuthenticated && auth.hasAdminAccess) {
          provider.initialize();
        } else {
          provider.clear();
        }
        return provider;
      },
    ),
  ];
}