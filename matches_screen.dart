import 'package:flutter/material.dart';
import '../../models/match_model.dart';
import '../../models/user_model.dart';
import '../chat/chat_screen.dart';

class MatchesScreen extends StatefulWidget {
  @override
  _MatchesScreenState createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  List<MatchModel> _matches = [];
  List<UserModel> _likes = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMatches();
    _loadLikes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock matches data
    final mockMatches = List.generate(8, (index) => MatchModel(
      id: 'match_$index',
      userId1: 'current_user',
      userId2: 'user_$index',
      user1: UserModel(
        id: 'current_user',
        phoneNumber: '+1234567890',
        name: 'You',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      user2: UserModel(
        id: 'user_$index',
        phoneNumber: '+1234567890',
        name: _mockNames[index % _mockNames.length],
        age: 22 + (index % 8),
        photos: [
          'https://via.placeholder.com/400x600?text=Match${index + 1}',
        ],
        location: 'New York, NY',
        createdAt: DateTime.now().subtract(Duration(days: index)),
        updatedAt: DateTime.now(),
      ),
      matchedAt: DateTime.now().subtract(Duration(days: index)),
      lastMessage: index % 3 == 0 ? 'Hey! How are you?' : null,
      lastMessageTime: index % 3 == 0 
          ? DateTime.now().subtract(Duration(hours: index))
          : null,
      unreadCount: index % 4,
    ));

    setState(() {
      _matches = mockMatches;
      _isLoading = false;
    });
  }

  Future<void> _loadLikes() async {
    // Mock likes data
    final mockLikes = List.generate(12, (index) => UserModel(
      id: 'like_user_$index',
      phoneNumber: '+1234567890',
      name: _mockNames[index % _mockNames.length],
      age: 22 + (index % 8),
      photos: [
        'https://via.placeholder.com/400x600?text=Like${index + 1}',
      ],
      location: 'New York, NY',
      createdAt: DateTime.now().subtract(Duration(days: index)),
      updatedAt: DateTime.now(),
    ));

    setState(() {
      _likes = mockLikes;
    });
  }

  void _openChat(MatchModel match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          matchId: match.id,
          otherUser: match.getOtherUser('current_user'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Matches',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pink,
          labelColor: Colors.pink,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Matches'),
                  if (_matches.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.pink,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_matches.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Likes'),
                  if (_likes.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_likes.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMatchesTab(),
          _buildLikesTab(),
        ],
      ),
    );
  }

  Widget _buildMatchesTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.pink),
      );
    }

    if (_matches.isEmpty) {
      return _buildEmptyMatches();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final match = _matches[index];
        final otherUser = match.getOtherUser('current_user');
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(
                    otherUser.photos.isNotEmpty 
                        ? otherUser.photos.first 
                        : 'https://via.placeholder.com/60x60?text=👤',
                  ),
                ),
                if (match.unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${match.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Text(
                  otherUser.name ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${match.matchType.emoji}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (match.lastMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    match.lastMessage!,
                    style: TextStyle(
                      color: match.unreadCount > 0 
                          ? Colors.black87 
                          : Colors.grey.shade600,
                      fontWeight: match.unreadCount > 0 
                          ? FontWeight.w500 
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'Matched ${_getTimeAgo(match.matchedAt)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (match.lastMessageTime != null)
                  Text(
                    _getTimeAgo(match.lastMessageTime!),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            onTap: () => _openChat(match),
          ),
        );
      },
    );
  }

  Widget _buildLikesTab() {
    if (_likes.isEmpty) {
      return _buildEmptyLikes();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _likes.length,
      itemBuilder: (context, index) {
        final user = _likes[index];
        
        return GestureDetector(
          onTap: () {
            // Handle like back or super like
            _showLikeOptions(user);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Profile image
                  Positioned.fill(
                    child: Image.network(
                      user.photos.isNotEmpty 
                          ? user.photos.first 
                          : 'https://via.placeholder.com/200x300?text=👤',
                      fit: BoxFit.cover,
                    ),
                  ),
                  
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // User info
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.name}, ${user.age}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (user.location != null)
                          Text(
                            user.location!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Like indicator
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.pink.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyMatches() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          const Text(
            'No matches yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start swiping to find your perfect match!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              // Navigate to browse screen
              DefaultTabController.of(context)?.animateTo(0);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('Start Swiping'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLikes() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.thumb_up_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          const Text(
            'No likes yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'People who like you will appear here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showLikeOptions(UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(
                user.photos.isNotEmpty 
                    ? user.photos.first 
                    : 'https://via.placeholder.com/80x80?text=👤',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${user.name} likes you!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Handle pass
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Pass',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Handle like back - create match
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("It's a match! 🎉"),
                          backgroundColor: Colors.pink,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text('Like Back'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${(difference.inDays / 7).floor()}w';
    }
  }

  // Mock data
  static const List<String> _mockNames = [
    'Emma', 'Olivia', 'Ava', 'Isabella', 'Sophia',
    'Charlotte', 'Mia', 'Amelia', 'Harper', 'Evelyn',
    'James', 'Robert', 'John', 'Michael', 'David',
    'William', 'Richard', 'Joseph', 'Thomas', 'Christopher',
  ];
}