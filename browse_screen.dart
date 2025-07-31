// screens/browse/browse_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/discovery_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/user_model.dart';
import '../../services/match_service.dart';
import 'user_profile_detail_screen.dart';
import 'filters_screen.dart';
import '../widgets/user_card.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen>
    with AutomaticKeepAliveClientMixin {
  final MatchService _matchService = MatchService();
  late PageController _pageController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialUsers();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialUsers() async {
    final discoveryProvider = context.read<DiscoveryProvider>();
    if (discoveryProvider.discoveredUsers.isEmpty) {
      await discoveryProvider.loadUsers(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      body: Consumer3<DiscoveryProvider, UserProvider, SubscriptionProvider>(
        builder: (context, discovery, user, subscription, child) {
          return SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, discovery),
                Expanded(
                  child: _buildBody(context, discovery, user, subscription),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, DiscoveryProvider discovery) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Discover',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _showFilters(context, discovery),
            icon: Stack(
              children: [
                const Icon(Icons.tune),
                if (discovery.hasActiveFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _toggleViewMode(discovery),
            icon: Icon(
              discovery.isSwipeMode ? Icons.grid_view : Icons.swipe,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DiscoveryProvider discovery,
    UserProvider user,
    SubscriptionProvider subscription,
  ) {
    if (discovery.isLoading && discovery.discoveredUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding amazing people for you...'),
          ],
        ),
      );
    }

    if (discovery.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              discovery.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: discovery.refresh,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (discovery.displayUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or check back later',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: discovery.clearFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      );
    }

    return discovery.isSwipeMode
        ? _buildSwipeMode(context, discovery, user, subscription)
        : _buildGridMode(context, discovery, user, subscription);
  }

  Widget _buildSwipeMode(
    BuildContext context,
    DiscoveryProvider discovery,
    UserProvider user,
    SubscriptionProvider subscription,
  ) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        discovery.goToUser(index);
        
        // Load more users when approaching the end
        if (index >= discovery.displayUsers.length - 2) {
          discovery.loadMoreUsers();
        }
      },
      itemCount: discovery.displayUsers.length,
      itemBuilder: (context, index) {
        final displayUser = discovery.displayUsers[index];
        
        return Padding(
          padding: const EdgeInsets.all(16),
          child: UserCard(
            user: displayUser,
            onTap: () => _viewProfile(context, displayUser),
            onLike: () => _handleLike(discovery, displayUser.id),
            onPass: () => _handlePass(discovery, displayUser.id),
            showActions: true,
            showCompatibility: true,
            currentUser: user.currentUser,
          ),
        );
      },
    );
  }

  Widget _buildGridMode(
    BuildContext context,
    DiscoveryProvider discovery,
    UserProvider user,
    SubscriptionProvider subscription,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          discovery.loadMoreUsers();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.7,
        ),
        itemCount: discovery.displayUsers.length + (discovery.isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= discovery.displayUsers.length) {
            return const Center(child: CircularProgressIndicator());
          }

          final displayUser = discovery.displayUsers[index];
          
          return UserCard(
            user: displayUser,
            onTap: () => _viewProfile(context, displayUser),
            compact: true,
            showCompatibility: false,
            currentUser: user.currentUser,
          );
        },
      ),
    );
  }

  void _toggleViewMode(DiscoveryProvider discovery) {
    discovery.toggleViewMode();
    
    // If switching to swipe mode, go to current user index
    if (discovery.isSwipeMode && discovery.currentUserIndex < discovery.displayUsers.length) {
      _pageController.animateToPage(
        discovery.currentUserIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showFilters(BuildContext context, DiscoveryProvider discovery) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FiltersScreen(
          currentFilters: discovery.activeFilters,
          availableOptions: discovery.availableFilterOptions,
          onApplyFilters: (filters) {
            discovery.applyFilters(filters);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _viewProfile(BuildContext context, UserModel user) {
    // Track profile view
    final userProvider = context.read<UserProvider>();
    userProvider.incrementProfileView(user.id);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserProfileDetailScreen(user: user),
      ),
    );
  }

  void _handleLike(DiscoveryProvider discovery, String userId) {
    discovery.onUserSwiped(userId, true);
    _moveToNextUser(discovery);
    
    // Show match dialog if mutual like (you could implement this)
    _checkForMatch(userId);
  }

  void _handlePass(DiscoveryProvider discovery, String userId) {
    discovery.onUserSwiped(userId, false);
    _moveToNextUser(discovery);
  }

  void _moveToNextUser(DiscoveryProvider discovery) {
    if (discovery.isSwipeMode && _pageController.hasClients) {
      final nextIndex = discovery.currentUserIndex + 1;
      if (nextIndex < discovery.displayUsers.length) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _checkForMatch(String userId) async {
    // You could implement mutual match checking here
    // using your match_service or a separate matching service
    
    // Example:
    // final result = await _matchService.checkMutualLike(userId);
    // if (result.success && result.isMatch) {
    //   _showMatchDialog(userId);
    // }
  }

  void _showMatchDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 It\'s a Match!'),
        content: const Text('You both liked each other! Start a conversation now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to chat or create conversation
              _startConversation(userId);
            },
            child: const Text('Say Hi!'),
          ),
        ],
      ),
    );
  }

  void _startConversation(String userId) {
    // Navigate to chat screen or create conversation
    // You would implement this based on your conversation flow
  }
}