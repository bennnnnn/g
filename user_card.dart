// screens/widgets/user_card.dart
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/match_service.dart';

class UserCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onPass;
  final bool showActions;
  final bool showCompatibility;
  final bool compact;
  final UserModel? currentUser;

  const UserCard({
    super.key,
    required this.user,
    this.onTap,
    this.onLike,
    this.onPass,
    this.showActions = false,
    this.showCompatibility = false,
    this.compact = false,
    this.currentUser,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  final MatchService _matchService = MatchService();
  double? _compatibilityScore;

  @override
  void initState() {
    super.initState();
    if (widget.showCompatibility && widget.currentUser != null) {
      _calculateCompatibility();
    }
  }

  void _calculateCompatibility() {
    if (widget.currentUser != null) {
      final score = _matchService.calculateCompatibility(
        widget.currentUser!,
        widget.user,
      );
      if (mounted) {
        setState(() {
          _compatibilityScore = score;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              _buildBackground(),
              _buildGradientOverlay(),
              _buildUserInfo(),
              if (widget.showCompatibility) _buildCompatibilityBadge(),
              if (widget.user.isVerified) _buildVerifiedBadge(),
              if (widget.user.isPremium) _buildPremiumBadge(),
              if (widget.showActions) _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    final photos = widget.user.photos.where((photo) => photo.isNotEmpty).toList();
    
    if (photos.isEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[300],
        child: Icon(
          Icons.person,
          size: widget.compact ? 60 : 120,
          color: Colors.grey[600],
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Image.network(
        photos.first,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Icon(
              Icons.error,
              size: widget.compact ? 30 : 60,
              color: Colors.grey[600],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.user.name ?? 'Unknown'}, ${widget.user.age ?? '?'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.compact ? 16 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.user.isRecentlyActive)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          if (!widget.compact) ...[
            const SizedBox(height: 4),
            if (widget.user.city != null || widget.user.country != null)
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _buildLocationText(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (widget.user.bio != null && widget.user.bio!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.user.bio!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCompatibilityBadge() {
    if (_compatibilityScore == null) return const SizedBox.shrink();

    final percentage = (_compatibilityScore! * 100).round();
    final color = _getCompatibilityColor(percentage);

    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '$percentage%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.verified,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildPremiumBadge() {
    return Positioned(
      top: widget.user.isVerified ? 56 : 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.amber,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.star,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.close,
            color: Colors.grey,
            onPressed: widget.onPass,
          ),
          _buildActionButton(
            icon: Icons.favorite,
            color: Colors.red,
            onPressed: widget.onLike,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        iconSize: 28,
      ),
    );
  }

  String _buildLocationText() {
    if (widget.user.city != null && widget.user.country != null) {
      return '${widget.user.city}, ${widget.user.country}';
    } else if (widget.user.city != null) {
      return widget.user.city!;
    } else if (widget.user.country != null) {
      return widget.user.country!;
    }
    return 'Location not set';
  }

  Color _getCompatibilityColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.lightGreen;
    if (percentage >= 40) return Colors.orange;
    if (percentage >= 20) return Colors.deepOrange;
    return Colors.red;
  }
}