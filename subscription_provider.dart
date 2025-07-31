import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../providers/auth_state_provider.dart';
import '../models/subscription_model.dart';
import '../models/enums.dart';
import '../services/subscription_service.dart';
import '../services/payment_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final PaymentService _paymentService = PaymentService();

  // Current subscription state
  SubscriptionModel? _currentSubscription;
  List<SubscriptionModel> _subscriptionHistory = [];
  
  // Product information
  Map<SubscriptionPlan, ProductDetails> _subscriptionProducts = {};
  
  // Loading states
  bool _isLoading = false;
  bool _isLoadingProducts = false;
  bool _isPurchasing = false;
  bool _isLoadingHistory = false;
  
  // Pagination for history
  DocumentSnapshot? _lastHistoryDocument;
  bool _hasMoreHistory = false;
  
  // Error handling
  String? _error;
  String? _purchaseError;
  
  // Payment callbacks
  bool _isPaymentInitialized = false;

  // Getters
  SubscriptionModel? get currentSubscription => _currentSubscription;
  List<SubscriptionModel> get subscriptionHistory => _subscriptionHistory;
  Map<SubscriptionPlan, ProductDetails> get subscriptionProducts => _subscriptionProducts;
  
  bool get isLoading => _isLoading;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isPurchasing => _isPurchasing;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get hasMoreHistory => _hasMoreHistory;
  
  String? get error => _error;
  String? get purchaseError => _purchaseError;
  
  // Premium status checks (DELEGATE TO MODEL)
  bool get isPremium => _currentSubscription?.isPremium ?? false;
  bool get hasUnlimitedMessaging => isPremium;
  bool get isSubscriptionActive => _currentSubscription?.isCurrentlyActive ?? false;
  bool get isNearExpiry => _currentSubscription?.isNearExpiry ?? false;
  
  // Subscription details (DELEGATE TO MODEL)
  String get subscriptionStatusText => _currentSubscription?.planDisplayName ?? 'Free Plan';
  String get remainingTimeText => _currentSubscription?.remainingTimeFormatted ?? 'No active subscription';
  int get daysRemaining => _currentSubscription?.daysRemaining ?? 0;
  int get hoursRemaining => _currentSubscription?.hoursRemaining ?? 0;
  SubscriptionPlan get currentPlan => _currentSubscription?.plan ?? SubscriptionPlan.free;

  /// Initialize subscription provider
  Future<void> initialize() async {
    if (_isLoading) return;
    
    _setLoading(true);
    _clearError();
    
    try {
      // Initialize payment system
      await _initializePayments();
      
      // Load current subscription
      await _loadCurrentSubscription();
      
      // Load available products
      await _loadSubscriptionProducts();
      
      debugPrint('SubscriptionProvider initialized successfully');
    } catch (e) {
      _setError('Failed to initialize subscription system: $e');
      debugPrint('Error initializing SubscriptionProvider: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Initialize payment system
  Future<void> _initializePayments() async {
    if (_isPaymentInitialized) return;
    
    try {
      // DELEGATE TO SERVICE
      final initialized = await _paymentService.initializePayments();
      if (!initialized) {
        debugPrint('Mobile payments not available');
        return;
      }
      
      // Set payment callbacks
      _paymentService.setPaymentCallbacks(
        onSuccess: _handlePaymentSuccess,
        onError: _handlePaymentError,
      );
      
      _isPaymentInitialized = true;
      debugPrint('Payment system initialized');
    } catch (e) {
      debugPrint('Error initializing payments: $e');
    }
  }

  /// Load current subscription (DELEGATE TO SERVICE)
  Future<void> _loadCurrentSubscription() async {
    try {
      final result = await _subscriptionService.getCurrentSubscription();
      if (result.success && result.subscription != null) {
        _currentSubscription = result.subscription;
        debugPrint('Current subscription loaded: ${_currentSubscription!.plan}');
      } else {
        _currentSubscription = null;
        debugPrint('No active subscription found');
      }
    } catch (e) {
      debugPrint('Error loading current subscription: $e');
      _currentSubscription = null;
    }
  }

  /// Load available subscription products from stores (DELEGATE TO SERVICE)
  Future<void> _loadSubscriptionProducts() async {
    if (!_isPaymentInitialized) return;
    
    _isLoadingProducts = true;
    notifyListeners();
    
    try {
      final result = await _paymentService.getSubscriptionProducts();
      if (result.success) {
        _subscriptionProducts = result.products;
        debugPrint('Subscription products loaded: ${_subscriptionProducts.length} products');
      } else {
        debugPrint('Failed to load subscription products: ${result.error}');
      }
    } catch (e) {
      debugPrint('Error loading subscription products: $e');
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  /// Purchase subscription (DELEGATE TO SERVICE)
  Future<bool> purchaseSubscription(SubscriptionPlan plan) async {
    if (_isPurchasing) return false;
    
    _setPurchasing(true);
    _clearPurchaseError();
    
    try {
      // Validate plan
      if (plan == SubscriptionPlan.free) {
        _setPurchaseError('Cannot purchase free plan');
        return false;
      }
      
      // Check if already have active subscription
      if (_currentSubscription?.isCurrentlyActive == true) {
        _setPurchaseError('You already have an active subscription');
        return false;
      }
      
      // DELEGATE TO SERVICE
      final result = await _paymentService.purchaseSubscription(plan: plan);
      
      if (result.success) {
        debugPrint('Subscription purchase initiated: $plan');
        return true;
      } else {
        _setPurchaseError(result.error ?? 'Purchase failed');
        return false;
      }
    } catch (e) {
      _setPurchaseError('Purchase failed: $e');
      debugPrint('Error purchasing subscription: $e');
      return false;
    } finally {
      _setPurchasing(false);
    }
  }

  /// Cancel current subscription (DELEGATE TO SERVICE)
  Future<bool> cancelSubscription({String? reason}) async {
    if (_currentSubscription == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      final result = await _subscriptionService.cancelSubscription(
        _currentSubscription!.id,
        reason: reason,
      );
      
      if (result.success) {
        _currentSubscription = result.subscription;
        debugPrint('Subscription cancelled successfully');
        notifyListeners();
        return true;
      } else {
        _setError(result.error ?? 'Failed to cancel subscription');
        return false;
      }
    } catch (e) {
      _setError('Failed to cancel subscription: $e');
      debugPrint('Error cancelling subscription: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Renew subscription
  Future<bool> renewSubscription() async {
    if (_currentSubscription == null) return false;
    return await purchaseSubscription(_currentSubscription!.plan);
  }

  /// Restore purchases (DELEGATE TO SERVICE)
  Future<bool> restorePurchases() async {
    if (!_isPaymentInitialized) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      final result = await _paymentService.restorePurchases();
      if (result.success) {
        await _loadCurrentSubscription();
        debugPrint('Purchases restored successfully');
        return true;
      } else {
        _setError(result.error ?? 'Failed to restore purchases');
        return false;
      }
    } catch (e) {
      _setError('Failed to restore purchases: $e');
      debugPrint('Error restoring purchases: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Load subscription history (DELEGATE TO SERVICE)
  Future<void> loadSubscriptionHistory({bool refresh = false}) async {
    if (_isLoadingHistory && !refresh) return;
    
    if (refresh) {
      _subscriptionHistory.clear();
      _lastHistoryDocument = null;
      _hasMoreHistory = false;
    }
    
    _isLoadingHistory = true;
    notifyListeners();
    
    try {
      final result = await _subscriptionService.getSubscriptionHistory(
        limit: 20,
        lastDocument: _lastHistoryDocument,
      );
      
      if (result.success) {
        if (refresh) {
          _subscriptionHistory = result.subscriptions;
        } else {
          _subscriptionHistory.addAll(result.subscriptions);
        }
        
        _lastHistoryDocument = result.lastDocument;
        _hasMoreHistory = result.hasMore;
        
        debugPrint('Subscription history loaded: ${result.subscriptions.length} items');
      } else {
        _setError(result.error ?? 'Failed to load subscription history');
      }
    } catch (e) {
      _setError('Failed to load subscription history: $e');
      debugPrint('Error loading subscription history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Get subscription analytics (DELEGATE TO SERVICE)
  Future<SubscriptionAnalytics?> getSubscriptionAnalytics() async {
    try {
      final result = await _subscriptionService.getSubscriptionAnalytics();
      if (result.success) {
        return result.analytics;
      } else {
        _setError(result.error ?? 'Failed to get analytics');
        return null;
      }
    } catch (e) {
      _setError('Failed to get analytics: $e');
      debugPrint('Error getting subscription analytics: $e');
      return null;
    }
  }

  /// Check if user can access premium features (DELEGATE TO MODEL)
  bool canAccessPremiumFeature(SubscriptionFeature feature) {
    if (_currentSubscription == null) return false;
    return _currentSubscription!.hasFeature(feature);
  }

  /// Get price for subscription plan (UI STATE ONLY)
  String getSubscriptionPrice(SubscriptionPlan plan) {
    // Try to get price from store products first
    final product = _subscriptionProducts[plan];
    if (product != null) {
      return product.price;
    }
    
    // DELEGATE TO SERVICE for fallback pricing
    final pricing = _subscriptionService.getSubscriptionPricing()[plan];
    if (pricing != null) {
      final price = pricing['price'] as double?;
      if (price != null) {
        return '\$${price.toStringAsFixed(2)}';
      }
    }
    
    return 'N/A';
  }

  /// Get subscription plan details (DELEGATE TO SERVICE)
  Map<String, dynamic>? getSubscriptionDetails(SubscriptionPlan plan) {
    return _subscriptionService.getSubscriptionPricing()[plan];
  }

  /// Handle payment success callback
  void _handlePaymentSuccess(String productId, PurchaseDetails details) async {
    debugPrint('Payment success for product: $productId');
    
    try {
      // Reload current subscription
      await _loadCurrentSubscription();
      
      // Refresh subscription history
      await loadSubscriptionHistory(refresh: true);
      
      _clearPurchaseError();
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error handling payment success: $e');
    } finally {
      _setPurchasing(false);
    }
  }

  /// Handle payment error callback
  void _handlePaymentError(String productId, String error) {
    debugPrint('Payment error for product $productId: $error');
    _setPurchaseError(error);
    _setPurchasing(false);
  }

  /// Check subscription expiry periodically
  Future<void> checkSubscriptionExpiry() async {
    if (_currentSubscription == null) return;
    
    try {
      // Reload current subscription to get latest status
      await _loadCurrentSubscription();
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking subscription expiry: $e');
    }
  }

  /// Force refresh subscription status
  Future<void> refreshSubscriptionStatus() async {
    await _loadCurrentSubscription();
    notifyListeners();
  }

  /// Clear subscription cache
  Future<void> clearCache() async {
    try {
      _currentSubscription = null;
      _subscriptionHistory.clear();
      _subscriptionProducts.clear();
      _lastHistoryDocument = null;
      _hasMoreHistory = false;
      
      // Reload everything
      await initialize();
    } catch (e) {
      debugPrint('Error clearing subscription cache: $e');
    }
  }

  /// UI State Management Methods
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setPurchasing(bool purchasing) {
    if (_isPurchasing != purchasing) {
      _isPurchasing = purchasing;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  void _setPurchaseError(String? error) {
    if (_purchaseError != error) {
      _purchaseError = error;
      notifyListeners();
    }
  }

  void _clearError() {
    _setError(null);
  }

  void _clearPurchaseError() {
    _setPurchaseError(null);
  }

  void clearErrors() {
    _clearError();
    _clearPurchaseError();
  }

  /// Get subscription status description (DELEGATE TO SERVICE/MODEL)
  String getSubscriptionStatusDescription() {
    if (_currentSubscription == null) {
      return 'Free Plan - Limited messaging';
    }
    
    return _currentSubscription!.subscriptionStatusDescription;
  }

  /// Get next billing date (DELEGATE TO MODEL)
  DateTime? get nextBillingDate {
    if (_currentSubscription?.isCurrentlyActive != true) return null;
    return _currentSubscription!.endDate;
  }

  /// Get subscription benefits (DELEGATE TO SERVICE)
  List<String> getSubscriptionBenefits(SubscriptionPlan plan) {
    final details = _subscriptionService.getSubscriptionPricing()[plan];
    return details?['benefits'] ?? [];
  }

  /// Check if payment is available (DELEGATE TO SERVICE)
  Future<bool> isPaymentAvailable() async {
    return await _paymentService.isPaymentAvailable();
  }

  /// Update auth state provider dependency
  void updateAuth(AuthStateProvider auth) {
    // Handle auth state changes if needed
    if (!auth.isAuthenticated) {
      _currentSubscription = null;
      _subscriptionHistory.clear();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }
}