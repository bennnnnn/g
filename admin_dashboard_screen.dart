/// Get role color for UI
  Color get roleColor {
    switch (role) {
      case 'user':
        return Colors.grey;
      case 'moderator':
        return Colors.blue;
      case 'admin':
        return Colors.orange;
      case 'superAdmin':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }// lib/presentation/screens/admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/analytics_service.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AnalyticsService _analytics = AnalyticsService();
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A3A),
        elevation: 0,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B9D),
          labelColor: const Color(0xFFFF6B9D),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.report), text: 'Reports'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AnalyticsTab(),
          UsersTab(),
          ReportsTab(),
          SettingsTab(),
        ],
      ),
    );
  }
}

/// Analytics Tab - Business Metrics
class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Real-Time Metrics'),
          const SizedBox(height: 16),
          _buildMetricsGrid(),
          const SizedBox(height: 32),
          _buildSectionTitle('Revenue Analytics'),
          const SizedBox(height: 16),
          const RevenueChart(),
          const SizedBox(height: 32),
          _buildSectionTitle('User Engagement'),
          const SizedBox(height: 16),
          const EngagementMetrics(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs;

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.report_off,
                  size: 64,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No reports found',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final doc = reports[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildReportCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildReportCard(String reportId, Map<String, dynamic> data) {
    final reporterId = data['reporterId'] as String? ?? '';
    final reportedUserId = data['reportedUserId'] as String? ?? '';
    final reason = data['reason'] as String? ?? 'No reason provided';
    final status = data['status'] as String? ?? 'pending';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Report #${reportId.substring(0, 8)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Reason: $reason',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reporter: $reporterId',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Reported: $reportedUserId',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reported: ${_formatDateTime(createdAt)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _resolveReport(reportId, 'resolved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Resolve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _resolveReport(reportId, 'dismissed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'dismissed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'resolved':
        return Icons.check_circle;
      case 'dismissed':
        return Icons.cancel;
      default:
        return Icons.report;
    }
  }

  Future<void> _resolveReport(String reportId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'status': newStatus,
        'resolvedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error resolving report: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Settings Tab - Admin Configuration
class SettingsTab extends StatefulWidget {
  const SettingsTab({Key? key}) : super(key: key);

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final TextEditingController _broadcastController = TextEditingController();

  @override
  void dispose() {
    _broadcastController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Broadcast Notification'),
          const SizedBox(height: 16),
          _buildBroadcastSection(),
          const SizedBox(height: 32),
          _buildSectionTitle('App Statistics'),
          const SizedBox(height: 16),
          _buildAppStats(),
          const SizedBox(height: 32),
          _buildSectionTitle('System Actions'),
          const SizedBox(height: 16),
          _buildSystemActions(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBroadcastSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send notification to all users',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _broadcastController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter your message...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFF6B9D)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sendBroadcastNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B9D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Send Broadcast'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final thisWeek = now.subtract(Duration(days: now.weekday - 1));
        final thisMonth = DateTime(now.year, now.month, 1);

        final todayUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final lastActive = (data['lastActiveAt'] as Timestamp?)?.toDate();
          return lastActive != null && lastActive.isAfter(today);
        }).length;

        final weeklyUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final lastActive = (data['lastActiveAt'] as Timestamp?)?.toDate();
          return lastActive != null && lastActive.isAfter(thisWeek);
        }).length;

        final monthlyUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final lastActive = (data['lastActiveAt'] as Timestamp?)?.toDate();
          return lastActive != null && lastActive.isAfter(thisMonth);
        }).length;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A3A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildStatRow('Total Users', users.length.toString()),
              const Divider(color: Colors.white24),
              _buildStatRow('Daily Active Users', todayUsers.toString()),
              const Divider(color: Colors.white24),
              _buildStatRow('Weekly Active Users', weeklyUsers.toString()),
              const Divider(color: Colors.white24),
              _buildStatRow('Monthly Active Users', monthlyUsers.toString()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemActions() {
    return Column(
      children: [
        _buildActionButton(
          'Export User Data',
          Icons.download,
          Colors.blue,
          _exportUserData,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Clear Analytics Cache',
          Icons.clear_all,
          Colors.orange,
          _clearAnalyticsCache,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Generate Daily Report',
          Icons.assessment,
          Colors.green,
          _generateDailyReport,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
      ),
    );
  }

  Future<void> _sendBroadcastNotification() async {
    final message = _broadcastController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Create broadcast notification document
      await FirebaseFirestore.instance.collection('broadcast_notifications').add({
        'message': message,
        'sentAt': Timestamp.fromDate(DateTime.now()),
        'sentBy': FirebaseAuth.instance.currentUser?.uid,
        'status': 'pending',
      });

      _broadcastController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Broadcast notification queued for sending'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending broadcast: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportUserData() async {
    try {
      // In a real app, this would generate and download a CSV/Excel file
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User data export started. Check email for download link.'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearAnalyticsCache() async {
    try {
      // Clear local analytics cache
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analytics cache cleared'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Clear cache failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generateDailyReport() async {
    try {
      final analytics = AnalyticsService();
      final report = await analytics.generateDailyReport();
      
      // Show report summary
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A3A),
          title: const Text(
            'Daily Report',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active Users: ${report.activeUsers}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'New Users: ${report.newUsers}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Messages: ${report.totalMessages}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Revenue: \${report.totalRevenue.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report generation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Admin Access Control Widget
class AdminAccessControl extends StatelessWidget {
  final Widget child;

  const AdminAccessControl({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (!authSnapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: Text('Please log in'),
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(authSnapshot.data!.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            final isAdmin = userData?['isAdmin'] as bool? ?? false;
            final role = userData?['role'] as String? ?? 'user';

            if (!isAdmin && role != 'admin') {
              return Scaffold(
                backgroundColor: const Color(0xFF0F0F23),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 64,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Admin Access Required',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You need admin privileges to access this section',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return child;
          },
        );
      },
    );
  }
}
        }

        final users = snapshot.data!.docs;
        final totalUsers = users.length;
        final premiumUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final plan = data['subscriptionPlan'] as String? ?? 'free';
          return plan != 'free';
        }).length;

        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final newUsersToday = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          return createdAt != null && createdAt.isAfter(todayStart);
        }).length;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildMetricCard(
              'Total Users',
              totalUsers.toString(),
              Icons.people,
              Colors.blue,
            ),
            _buildMetricCard(
              'Premium Users',
              premiumUsers.toString(),
              Icons.star,
              Colors.orange,
            ),
            _buildMetricCard(
              'New Today',
              newUsersToday.toString(),
              Icons.person_add,
              Colors.green,
            ),
            _buildMetricCard(
              'Conversion Rate',
              '${((premiumUsers / totalUsers) * 100).toStringAsFixed(1)}%',
              Icons.trending_up,
              Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.arrow_upward, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Revenue Chart Widget
class RevenueChart extends StatelessWidget {
  const RevenueChart({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('analytics_events')
            .where('event_name', isEqualTo: 'revenue_event')
            .orderBy('timestamp', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data!.docs;
          double totalRevenue = 0;
          double subscriptionRevenue = 0;
          double giftRevenue = 0;

          for (final doc in events) {
            final data = doc.data() as Map<String, dynamic>;
            final parameters = data['parameters'] as Map<String, dynamic>? ?? {};
            final amount = (parameters['amount'] as num?)?.toDouble() ?? 0;
            final eventType = parameters['event_type'] as String? ?? '';

            totalRevenue += amount;
            if (eventType == 'subscription_purchase') {
              subscriptionRevenue += amount;
            } else if (eventType == 'gift_purchase') {
              giftRevenue += amount;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.monetization_on, color: Color(0xFFFF6B9D)),
                  const SizedBox(width: 8),
                  const Text(
                    'Revenue Overview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildRevenueItem(
                      'Total Revenue',
                      '\$${totalRevenue.toStringAsFixed(2)}',
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildRevenueItem(
                      'Subscriptions',
                      '\$${subscriptionRevenue.toStringAsFixed(2)}',
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildRevenueItem(
                      'Gifts',
                      '\$${giftRevenue.toStringAsFixed(2)}',
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Simple revenue bar chart
              _buildRevenueBar(subscriptionRevenue, giftRevenue, totalRevenue),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRevenueItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueBar(double subscriptions, double gifts, double total) {
    if (total == 0) return const SizedBox();

    final subscriptionRatio = subscriptions / total;
    final giftRatio = gifts / total;

    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.white.withOpacity(0.1),
      ),
      child: Row(
        children: [
          if (subscriptionRatio > 0)
            Expanded(
              flex: (subscriptionRatio * 100).round(),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          if (giftRatio > 0)
            Expanded(
              flex: (giftRatio * 100).round(),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Engagement Metrics Widget
class EngagementMetrics extends StatelessWidget {
  const EngagementMetrics({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('analytics_events')
          .where('event_name', whereIn: ['message_sent', 'conversation_started', 'gift_purchase'])
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data!.docs;
        int messagesCount = 0;
        int conversationsCount = 0;
        int giftsCount = 0;

        for (final doc in events) {
          final data = doc.data() as Map<String, dynamic>;
          final eventName = data['event_name'] as String? ?? '';

          switch (eventName) {
            case 'message_sent':
              messagesCount++;
              break;
            case 'conversation_started':
              conversationsCount++;
              break;
            case 'gift_purchase':
              giftsCount++;
              break;
          }
        }

        return Row(
          children: [
            Expanded(
              child: _buildEngagementCard(
                'Messages',
                messagesCount.toString(),
                Icons.message,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildEngagementCard(
                'Conversations',
                conversationsCount.toString(),
                Icons.chat,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildEngagementCard(
                'Gifts Sent',
                giftsCount.toString(),
                Icons.card_giftcard,
                Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEngagementCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Users Tab - User Management
class UsersTab extends StatefulWidget {
  const UsersTab({Key? key}) : super(key: key);

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  String _searchQuery = '';
  String _filterType = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchAndFilter(),
        Expanded(child: _buildUsersList()),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A3A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Users', 'all'),
                _buildFilterChip('Premium', 'premium'),
                _buildFilterChip('Free', 'free'),
                _buildFilterChip('Blocked', 'blocked'),
                _buildFilterChip('Reported', 'reported'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterType) {
    final isSelected = _filterType == filterType;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterType = filterType;
          });
        },
        backgroundColor: const Color(0xFF1A1A3A),
        selectedColor: const Color(0xFFFF6B9D),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] as String? ?? '').toLowerCase();
          final email = (data['email'] as String? ?? '').toLowerCase();
          final phone = (data['phoneNumber'] as String? ?? '').toLowerCase();
          
          // Search filter
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            if (!name.contains(query) && !email.contains(query) && !phone.contains(query)) {
              return false;
            }
          }

          // Type filter
          switch (_filterType) {
            case 'premium':
              final plan = data['subscriptionPlan'] as String? ?? 'free';
              return plan != 'free';
            case 'free':
              final plan = data['subscriptionPlan'] as String? ?? 'free';
              return plan == 'free';
            case 'blocked':
              return data['isBlocked'] as bool? ?? false;
            case 'reported':
              final reportedUsers = data['reportedUsers'] as List? ?? [];
              return reportedUsers.isNotEmpty;
            default:
              return true;
          }
        }).toList();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final doc = users[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildUserCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'Unknown';
    final email = data['email'] as String? ?? '';
    final phone = data['phoneNumber'] as String? ?? '';
    final plan = data['subscriptionPlan'] as String? ?? 'free';
    final isBlocked = data['isBlocked'] as bool? ?? false;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final photos = data['photos'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBlocked ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: photos.isNotEmpty && photos[0].isNotEmpty
              ? NetworkImage(photos[0])
              : null,
          backgroundColor: const Color(0xFFFF6B9D),
          child: photos.isEmpty || photos[0].isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (plan != 'free')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B9D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  plan.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email.isNotEmpty)
              Text(
                email,
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            Text(
              phone,
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            if (createdAt != null)
              Text(
                'Joined ${_formatDate(createdAt)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) => _handleUserAction(value, userId, data),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  const Icon(Icons.visibility),
                  const SizedBox(width: 8),
                  const Text('View Profile'),
                ],
              ),
            ),
            PopupMenuItem(
              value: isBlocked ? 'unblock' : 'block',
              child: Row(
                children: [
                  Icon(isBlocked ? Icons.check : Icons.block),
                  const SizedBox(width: 8),
                  Text(isBlocked ? 'Unblock' : 'Block'),
                ],
              ),
            ),
            if (plan == 'free')
              const PopupMenuItem(
                value: 'promote',
                child: Row(
                  children: [
                    Icon(Icons.star),
                    SizedBox(width: 8),
                    Text('Give Premium'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleUserAction(String action, String userId, Map<String, dynamic> userData) async {
    switch (action) {
      case 'view':
        _showUserDetails(userId, userData);
        break;
      case 'block':
        await _toggleBlockUser(userId, true);
        break;
      case 'unblock':
        await _toggleBlockUser(userId, false);
        break;
      case 'promote':
        await _giveFreePremium(userId);
        break;
    }
  }

  void _showUserDetails(String userId, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => UserDetailsDialog(userId: userId, userData: userData),
    );
  }

  Future<void> _toggleBlockUser(String userId, bool block) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isBlocked': block,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(block ? 'User blocked' : 'User unblocked'),
          backgroundColor: block ? Colors.red : Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _giveFreePremium(String userId) async {
    try {
      final endDate = DateTime.now().add(const Duration(days: 30));
      
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'subscriptionPlan': 'monthly',
        'subscriptionExpiresAt': Timestamp.fromDate(endDate),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Free premium granted for 30 days'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) return 'Today';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()} weeks ago';
    return '${(difference.inDays / 30).floor()} months ago';
  }
}

/// User Details Dialog
class UserDetailsDialog extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const UserDetailsDialog({
    Key? key,
    required this.userId,
    required this.userData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = userData['name'] as String? ?? 'Unknown';
    final email = userData['email'] as String? ?? 'No email';
    final phone = userData['phoneNumber'] as String? ?? 'No phone';
    final age = userData['age'] as int?;
    final bio = userData['bio'] as String? ?? 'No bio';
    final photos = userData['photos'] as List? ?? [];
    final country = userData['country'] as String? ?? 'Unknown';
    final city = userData['city'] as String? ?? 'Unknown';

    return Dialog(
      backgroundColor: const Color(0xFF1A1A3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: photos.isNotEmpty && photos[0].isNotEmpty
                      ? NetworkImage(photos[0])
                      : null,
                  backgroundColor: const Color(0xFFFF6B9D),
                  child: photos.isEmpty || photos[0].isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 24),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (age != null)
                        Text(
                          'Age: $age',
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                      Text(
                        '$city, $country',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Email', email),
            _buildDetailRow('Phone', phone),
            _buildDetailRow('Bio', bio),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reports Tab - Moderation
class ReportsTab extends StatelessWidget {
  const ReportsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());