import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class SubscriptionModel {
  final String id;
  final String userId;
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final bool autoRenew;
  final String? paymentMethodId;
  final double price;
  final String currency;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final Map<String, dynamic>? metadata;
  final List<SubscriptionFeature> features;

  SubscriptionModel({
    required this.id,
    required this.userId,
    required this.plan,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.isActive = false,
    this.autoRenew = true,
    this.paymentMethodId,
    required this.price,
    this.currency = 'USD',
    this.cancelledAt,
    this.cancellationReason,
    this.metadata,
    this.features = const [],
  });

  // Check if subscription is currently active
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && 
           status == SubscriptionStatus.active &&
           now.isAfter(startDate) && 
           now.isBefore(endDate);
  }

  // Days remaining in subscription
  int get daysRemaining {
    final now = DateTime.now();
    if (!isCurrentlyActive) return 0;
    return endDate.difference(now).inDays;
  }

  // Hours remaining in subscription (useful for daily passes)
  int get hoursRemaining {
    final now = DateTime.now();
    if (!isCurrentlyActive) return 0;
    return endDate.difference(now).inHours;
  }

  // Minutes remaining in subscription
  int get minutesRemaining {
    final now = DateTime.now();
    if (!isCurrentlyActive) return 0;
    return endDate.difference(now).inMinutes;
  }

  // Get subscription duration in a readable format
  String get remainingTimeFormatted {
    if (!isCurrentlyActive) return 'Expired';
    
    final remaining = endDate.difference(DateTime.now());
    
    if (remaining.inDays > 0) {
      return '${remaining.inDays} day${remaining.inDays == 1 ? '' : 's'} left';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours} hour${remaining.inHours == 1 ? '' : 's'} left';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes} minute${remaining.inMinutes == 1 ? '' : 's'} left';
    } else {
      return 'Expires soon';
    }
  }
// Add this getter to SubscriptionModel class
  
  /// Get subscription status description
  String get subscriptionStatusDescription {
    if (!isCurrentlyActive) {
      return 'Subscription expired';
    }
    
    final daysLeft = daysRemaining;
    final hoursLeft = hoursRemaining;
    
    if (daysLeft > 0) {
      return '$planDisplayName - $daysLeft day${daysLeft == 1 ? '' : 's'} left';
    } else if (hoursLeft > 0) {
      return '$planDisplayName - $hoursLeft hour${hoursLeft == 1 ? '' : 's'} left';
    } else {
      return '$planDisplayName - Expires soon';
    }
  }
  // Check if subscription has a specific feature
  bool hasFeature(SubscriptionFeature feature) {
    return features.contains(feature);
  }

  // Check if subscription is premium (not free)
  bool get isPremium {
    return plan != SubscriptionPlan.free && isCurrentlyActive;
  }

  // Check if subscription is about to expire (within 24 hours)
  bool get isNearExpiry {
    if (!isCurrentlyActive) return false;
    final hoursLeft = endDate.difference(DateTime.now()).inHours;
    return hoursLeft <= 24;
  }

  // Get subscription type display name based on plan
  String get planDisplayName {
    return plan.displayName;
  }

  // Get formatted price string
  String get formattedPrice {
    return '\$${price.toStringAsFixed(2)}';
  }

  // Convert from Firestore
  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SubscriptionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      plan: SubscriptionPlan.values.firstWhere(
        (e) => e.toString() == 'SubscriptionPlan.${data['plan']}',
        orElse: () => SubscriptionPlan.free,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.toString() == 'SubscriptionStatus.${data['status']}',
        orElse: () => SubscriptionStatus.inactive,
      ),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? false,
      autoRenew: data['autoRenew'] ?? true,
      paymentMethodId: data['paymentMethodId'],
      price: (data['price'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'USD',
      cancelledAt: data['cancelledAt'] != null 
          ? (data['cancelledAt'] as Timestamp).toDate()
          : null,
      cancellationReason: data['cancellationReason'],
      metadata: data['metadata'],
      features: (data['features'] as List? ?? [])
          .map((f) => SubscriptionFeature.values.firstWhere(
                (e) => e.toString() == 'SubscriptionFeature.$f',
                orElse: () => SubscriptionFeature.unlimitedMessages,
              ))
          .toList(),
    );
  }

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'plan': plan.toString().split('.').last,
      'status': status.toString().split('.').last,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'autoRenew': autoRenew,
      'paymentMethodId': paymentMethodId,
      'price': price,
      'currency': currency,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancellationReason': cancellationReason,
      'metadata': metadata,
      'features': features.map((f) => f.toString().split('.').last).toList(),
    };
  }

  // Convert from JSON
  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      plan: SubscriptionPlan.values.firstWhere(
        (e) => e.toString() == 'SubscriptionPlan.${json['plan']}',
        orElse: () => SubscriptionPlan.free,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.toString() == 'SubscriptionStatus.${json['status']}',
        orElse: () => SubscriptionStatus.inactive,
      ),
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      isActive: json['isActive'] ?? false,
      autoRenew: json['autoRenew'] ?? true,
      paymentMethodId: json['paymentMethodId'],
      price: (json['price'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      cancelledAt: json['cancelledAt'] != null 
          ? DateTime.parse(json['cancelledAt'])
          : null,
      cancellationReason: json['cancellationReason'],
      metadata: json['metadata'],
      features: (json['features'] as List? ?? [])
          .map((f) => SubscriptionFeature.values.firstWhere(
                (e) => e.toString() == 'SubscriptionFeature.$f',
                orElse: () => SubscriptionFeature.unlimitedMessages,
              ))
          .toList(),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'plan': plan.toString().split('.').last,
      'status': status.toString().split('.').last,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive,
      'autoRenew': autoRenew,
      'paymentMethodId': paymentMethodId,
      'price': price,
      'currency': currency,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      'metadata': metadata,
      'features': features.map((f) => f.toString().split('.').last).toList(),
    };
  }

  // Create a copy with updated fields
  SubscriptionModel copyWith({
    String? id,
    String? userId,
    SubscriptionPlan? plan,
    SubscriptionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    bool? autoRenew,
    String? paymentMethodId,
    double? price,
    String? currency,
    DateTime? cancelledAt,
    String? cancellationReason,
    Map<String, dynamic>? metadata,
    List<SubscriptionFeature>? features,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      autoRenew: autoRenew ?? this.autoRenew,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      metadata: metadata ?? this.metadata,
      features: features ?? this.features,
    );
  }

  @override
  String toString() {
    return 'SubscriptionModel(id: $id, plan: $plan, status: $status, active: $isCurrentlyActive)';
  }
}