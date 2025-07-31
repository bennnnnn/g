import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  
  // Settings preferences
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _showOnlineStatus = true;
  bool _showDistance = true;
  bool _privateMode = false;
  String _language = 'English';
  String _theme = 'Light';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    setState(() {
      _currentUser = _authService.currentUser;
    });
  }

  void _editProfile() {
    // Navigate to edit profile screen
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditProfileSheet(),
    );
  }

  void _showSubscriptionPlans() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSubscriptionSheet(),
    );
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle account deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion requested. You will receive a confirmation email.'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Profile Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.pink,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.pink, Colors.red.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _currentUser?.photos.isNotEmpty == true
                                ? NetworkImage(_currentUser!.photos.first)
                                : null,
                            child: _currentUser?.photos.isEmpty != false
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _editProfile,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 20,
                                  color: Colors.pink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _currentUser?.name ?? 'User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (_currentUser?.age != null)
                        Text(
                          'Age ${_currentUser!.age}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Settings Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Premium Card
                  if (_currentUser?.isPremium != true)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber, Colors.orange],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Go Premium',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const Text(
                                  'Unlock unlimited likes, super likes, and more!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _showSubscriptionPlans,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Upgrade',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Settings Sections
                  _buildSettingsSection(
                    'Account',
                    [
                      _buildSettingsItem(
                        icon: Icons.person,
                        title: 'Edit Profile',
                        subtitle: 'Update your photos and info',
                        onTap: _editProfile,
                      ),
                      _buildSettingsItem(
                        icon: Icons.location_on,
                        title: 'Location',
                        subtitle: 'Manage location settings',
                        onTap: () => _showLocationSettings(),
                      ),
                      _buildSettingsItem(
                        icon: Icons.security,
                        title: 'Privacy & Safety',
                        subtitle: 'Control who can see you',
                        onTap: () => _showPrivacySettings(),
                      ),
                    ],
                  ),

                  _buildSettingsSection(
                    'Notifications',
                    [
                      _buildSwitchItem(
                        icon: Icons.notifications,
                        title: 'Push Notifications',
                        subtitle: 'Get notified about matches and messages',
                        value: _pushNotifications,
                        onChanged: (value) {
                          setState(() {
                            _pushNotifications = value;
                          });
                        },
                      ),
                      _buildSwitchItem(
                        icon: Icons.email,
                        title: 'Email Notifications',
                        subtitle: 'Receive updates via email',
                        value: _emailNotifications,
                        onChanged: (value) {
                          setState(() {
                            _emailNotifications = value;
                          });
                        },
                      ),
                    ],
                  ),

                  _buildSettingsSection(
                    'Discovery',
                    [
                      _buildSwitchItem(
                        icon: Icons.visibility,
                        title: 'Show me on Discovery',
                        subtitle: 'Turn off to browse privately',
                        value: !_privateMode,
                        onChanged: (value) {
                          setState(() {
                            _privateMode = !value;
                          });
                        },
                      ),
                      _buildSwitchItem(
                        icon: Icons.near_me,
                        title: 'Show Distance',
                        subtitle: 'Display distance on profiles',
                        value: _showDistance,
                        onChanged: (value) {
                          setState(() {
                            _showDistance = value;
                          });
                        },
                      ),
                      _buildSwitchItem(
                        icon: Icons.circle,
                        title: 'Show Online Status',
                        subtitle: 'Let others know when you\'re active',
                        value: _showOnlineStatus,
                        onChanged: (value) {
                          setState(() {
                            _showOnlineStatus = value;
                          });
                        },
                      ),
                    ],
                  ),

                  _buildSettingsSection(
                    'App Settings',
                    [
                      _buildSettingsItem(
                        icon: Icons.language,
                        title: 'Language',
                        subtitle: _language,
                        onTap: () => _showLanguageSelector(),
                      ),
                      _buildSettingsItem(
                        icon: Icons.palette,
                        title: 'Theme',
                        subtitle: _theme,
                        onTap: () => _showThemeSelector(),
                      ),
                      _buildSettingsItem(
                        icon: Icons.storage,
                        title: 'Storage',
                        subtitle: 'Manage app storage',
                        onTap: () => _showStorageSettings(),
                      ),
                    ],
                  ),

                  _buildSettingsSection(
                    'Support',
                    [
                      _buildSettingsItem(
                        icon: Icons.help,
                        title: 'Help Center',
                        subtitle: 'Get help and support',
                        onTap: () => _showHelpCenter(),
                      ),
                      _buildSettingsItem(
                        icon: Icons.feedback,
                        title: 'Send Feedback',
                        subtitle: 'Help us improve the app',
                        onTap: () => _showFeedbackForm(),
                      ),
                      _buildSettingsItem(
                        icon: Icons.info,
                        title: 'About',
                        subtitle: 'App version and info',
                        onTap: () => _showAboutDialog(),
                      ),
                    ],
                  ),

                  _buildSettingsSection(
                    'Legal',
                    [
                      _buildSettingsItem(
                        icon: Icons.description,
                        title: 'Terms of Service',
                        onTap: () => _showTermsOfService(),
                      ),
                      _buildSettingsItem(
                        icon: Icons.privacy_tip,
                        title: 'Privacy Policy',
                        onTap: () => _showPrivacyPolicy(),
                      ),
                      _buildSettingsItem(
                        icon: Icons.gavel,
                        title: 'Community Guidelines',
                        onTap: () => _showCommunityGuidelines(),
                      ),
                    ],
                  ),

                  // Danger Zone
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Danger Zone',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDangerItem(
                          title: 'Logout',
                          subtitle: 'Sign out of your account',
                          onTap: _logout,
                        ),
                        _buildDangerItem(
                          title: 'Delete Account',
                          subtitle: 'Permanently delete your account and data',
                          onTap: _deleteAccount,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.grey.shade600),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.grey.shade600),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            )
          : null,
      trailing: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.pink,
      ),
    );
  }

  Widget _buildDangerItem({
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.red,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade400,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.red),
      onTap: onTap,
    );
  }

  Widget _buildEditProfileSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('Edit Profile Form Coming Soon'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Premium Plans',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildPremiumPlan(
                    'Premium',
                    '\$9.99/month',
                    '⭐',
                    [
                      'Unlimited likes',
                      'See who likes you',
                      'Super likes',
                      'Hide ads',
                      'Undo swipes',
                    ],
                    Colors.pink,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumPlan(
                    'Gold',
                    '\$19.99/month',
                    '🏆',
                    [
                      'Everything in Premium',
                      'Boosts',
                      'Read receipts',
                      'Advanced filters',
                      'Priority support',
                    ],
                    Colors.amber,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumPlan(
                    'Platinum',
                    '\$29.99/month',
                    '💎',
                    [
                      'Everything in Gold',
                      'Message before matching',
                      'Priority likes',
                      'See who viewed your profile',
                      'Premium gifts',
                    ],
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPlan(
    String name,
    String price,
    String emoji,
    List<String> features,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.check, color: color, size: 16),
                const SizedBox(width: 8),
                Text(feature),
              ],
            ),
          )).toList(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$name subscription activated!'),
                    backgroundColor: color,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Choose $name'),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for various settings
  void _showLocationSettings() {
    // Show location settings
  }

  void _showPrivacySettings() {
    // Show privacy settings
  }

  void _showLanguageSelector() {
    // Show language selector
  }

  void _showThemeSelector() {
    // Show theme selector
  }

  void _showStorageSettings() {
    // Show storage settings
  }

  void _showHelpCenter() {
    // Show help center
  }

  void _showFeedbackForm() {
    // Show feedback form
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Dating App',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.pink,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.favorite,
          color: Colors.white,
          size: 30,
        ),
      ),
      children: [
        const Text('Find your perfect match with our innovative dating platform.'),
      ],
    );
  }

  void _showTermsOfService() {
    // Show terms of service
  }

  void _showPrivacyPolicy() {
    // Show privacy policy
  }

  void _showCommunityGuidelines() {
    // Show community guidelines
  }
}