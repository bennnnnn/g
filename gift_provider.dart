// providers/gift_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gift_model.dart';
import '../models/enums.dart';
import '../services/gift_service.dart';
import '../providers/auth_state_provider.dart';
import '../providers/user_provider.dart';

class GiftProvider extends ChangeNotifier {
  final GiftService _giftService = GiftService();
  
  // Available gifts state
  List<GiftModel> _availableGifts = [];
  final Map<GiftCategory, List<GiftModel>> _giftsByCategory = {};
  Map<GiftCategory, int> _categoryCounts = {};
  
  // Popular and featured gifts
  List<GiftModel> _popularGifts = [];
  final List<GiftModel> _featuredGifts = [];
  
  // User gifts state
  List<SentGiftModel> _sentGifts = [];
  List<SentGiftModel> _receivedGifts = [];
  
  // Current selection state
  GiftModel? _selectedGift;
  GiftCategory? _selectedCategory;
  
  // Loading states
  bool _isLoading = false;
  bool _isLoadingGifts = false;
  bool _isSendingGift = false;
  bool _isLoadingSentGifts = false;
  bool _isLoadingReceivedGifts = false;
  bool _isLoadingPopular = false;
  
  // Pagination state
  DocumentSnapshot? _lastSentDocument;
  DocumentSnapshot? _lastReceivedDocument;
  bool _hasMoreSentGifts = false;
  bool _hasMoreReceivedGifts = false;
  
  // Error handling
  String? _error;
  String? _sendError;
  
  // Gift statistics and unread count
  int _unreadGiftsCount = 0;

  // Dependencies
  AuthStateProvider? _authProvider;

  // GETTERS
  
  // Available gifts
  List<GiftModel> get availableGifts => List.unmodifiable(_availableGifts);
  Map<GiftCategory, List<GiftModel>> get giftsByCategory => Map.unmodifiable(_giftsByCategory);
  Map<GiftCategory, int> get categoryCounts => Map.unmodifiable(_categoryCounts);
  List<GiftModel> get popularGifts => List.unmodifiable(_popularGifts);
  List<GiftModel> get featuredGifts => List.unmodifiable(_featuredGifts);
  
  // User gifts
  List<SentGiftModel> get sentGifts => List.unmodifiable(_sentGifts);
  List<SentGiftModel> get receivedGifts => List.unmodifiable(_receivedGifts);
  
  // Current selection
  GiftModel? get selectedGift => _selectedGift;
  GiftCategory? get selectedCategory => _selectedCategory;
  
  // Loading states
  bool get isLoading => _isLoading;
  bool get isLoadingGifts => _isLoadingGifts;
  bool get isSendingGift => _isSendingGift;
  bool get isLoadingSentGifts => _isLoadingSentGifts;
  bool get isLoadingReceivedGifts => _isLoadingReceivedGifts;
  bool get isLoadingPopular => _isLoadingPopular;
  
  // Pagination
  bool get hasMoreSentGifts => _hasMoreSentGifts;
  bool get hasMoreReceivedGifts => _hasMoreReceivedGifts;
  
  // Errors
  String? get error => _error;
  String? get sendError => _sendError;
  
  // Statistics
  int get unreadGiftsCount => _unreadGiftsCount;
  
  // Computed getters
  bool get hasAvailableGifts => _availableGifts.isNotEmpty;
  bool get hasSelectedGift => _selectedGift != null;
  int get totalAvailableGifts => _availableGifts.length;
  bool get hasSentGifts => _sentGifts.isNotEmpty;
  bool get hasReceivedGifts => _receivedGifts.isNotEmpty;
  bool get hasUnreadGifts => _unreadGiftsCount > 0;
  
  // Get gifts for selected category
  List<GiftModel> get selectedCategoryGifts {
    if (_selectedCategory == null) return _availableGifts;
    return _giftsByCategory[_selectedCategory] ?? [];
  }

  // Get gifts by price range
  List<GiftModel> get affordableGifts => _availableGifts.where((g) => g.finalPrice <= 5.0).toList();
  List<GiftModel> get premiumGifts => _availableGifts.where((g) => g.finalPrice > 10.0).toList();
  List<GiftModel> get legendaryGifts => _availableGifts.where((g) => g.rarity == GiftRarity.legendary).toList();

  // DEPENDENCY INJECTION

  /// Update auth state provider dependency
  void updateAuth(AuthStateProvider auth) {
    _authProvider = auth;
    if (!auth.isAuthenticated) {
      _resetState();
      notifyListeners();
    }
  }

  /// Update user provider dependency
  void updateUser(UserProvider userProvider) {
  }

  // INITIALIZATION

  /// Initialize gift provider
  Future<void> initialize() async {
    if (_authProvider?.isAuthenticated != true) {
      debugPrint('GiftProvider: User not authenticated, skipping initialization');
      return;
    }

    _setLoading(true);
    _clearError();
    
    try {
      // Initialize default gifts if needed
      await _giftService.initializeDefaultGifts();
      
      // Load available gifts
      await loadAvailableGifts();
      
      // Load popular gifts
      await loadPopularGifts();
      
      // Load user's gift data
      await Future.wait([
        _loadUnreadGiftsCount(),
        loadSentGifts(refresh: true),
        loadReceivedGifts(refresh: true),
      ]);
      
      debugPrint('GiftProvider initialized successfully');
    } catch (e) {
      _setError('Failed to initialize gifts: $e');
      debugPrint('Error initializing GiftProvider: $e');
    } finally {
      _setLoading(false);
    }
  }

  // GIFT CATALOG OPERATIONS

  /// Load available gifts with optional filtering
  Future<void> loadAvailableGifts({
    GiftCategory? category,
    GiftRarity? rarity,
    bool premiumOnly = false,
    double? maxPrice,
    bool refresh = false,
  }) async {
    if (refresh || _availableGifts.isEmpty) {
      _isLoadingGifts = true;
      _clearError();
      notifyListeners();
    }
    
    try {
      final result = await _giftService.getAvailableGifts(
        category: category,
        rarity: rarity,
        premiumOnly: premiumOnly,
        maxPrice: maxPrice,
      );
      
      if (result.success) {
        _availableGifts = result.gifts;
        _organizeGiftsByCategory();
        await _loadCategoryCounts();
        debugPrint('Available gifts loaded: ${_availableGifts.length}');
      } else {
        _setError(result.error ?? 'Failed to load gifts');
      }
    } catch (e) {
      _setError('Failed to load gifts: $e');
      debugPrint('Error loading available gifts: $e');
    } finally {
      if (refresh || _isLoadingGifts) {
        _isLoadingGifts = false;
        notifyListeners();
      }
    }
  }

  /// Load gifts by specific category
  Future<void> loadGiftsByCategory(GiftCategory category) async {
    _selectedCategory = category;
    notifyListeners();
    
    try {
      final result = await _giftService.getGiftsByCategory(category);
      
      if (result.success) {
        _giftsByCategory[category] = result.gifts;
        debugPrint('Category gifts loaded: ${result.gifts.length} for $category');
      } else {
        _setError(result.error ?? 'Failed to load category gifts');
      }
    } catch (e) {
      _setError('Failed to load category gifts: $e');
      debugPrint('Error loading gifts by category: $e');
    }
    
    notifyListeners();
  }

  /// Load popular gifts
  Future<void> loadPopularGifts({
    int limit = 10,
    GiftCategory? category,
  }) async {
    _isLoadingPopular = true;
    notifyListeners();
    
    try {
      // Since getPopularGifts doesn't exist in the service, we'll simulate it
      // by getting available gifts and sorting by a popularity metric
      final result = await _giftService.getAvailableGifts(
        category: category,
      );
      
      if (result.success) {
        // Sort by rarity and price to simulate popularity
        // Higher rarity and moderate price range are considered more popular
        var sortedGifts = result.gifts.toList();
        sortedGifts.sort((a, b) {
          // First sort by rarity (higher rarity = more popular)
          final rarityComparison = b.rarity.index.compareTo(a.rarity.index);
          if (rarityComparison != 0) return rarityComparison;
          
          // Then by price (moderate prices are more popular)
          final aPriceScore = _getPopularityPriceScore(a.finalPrice);
          final bPriceScore = _getPopularityPriceScore(b.finalPrice);
          return bPriceScore.compareTo(aPriceScore);
        });
        
        _popularGifts = sortedGifts.take(limit).toList();
        debugPrint('Popular gifts loaded: ${_popularGifts.length}');
      } else {
        _setError(result.error ?? 'Failed to load popular gifts');
      }
    } catch (e) {
      _setError('Failed to load popular gifts: $e');
      debugPrint('Error loading popular gifts: $e');
    } finally {
      _isLoadingPopular = false;
      notifyListeners();
    }
  }

  /// Calculate popularity score based on price
  int _getPopularityPriceScore(double price) {
    // Moderate prices (2-8 dollars) get higher popularity scores
    if (price >= 2.0 && price <= 8.0) return 3;
    if (price >= 1.0 && price <= 10.0) return 2;
    return 1;
  }

  /// Get gift by ID
  Future<GiftModel?> getGiftById(String giftId) async {
    try {
      // Check if gift is already in our available gifts
      GiftModel? existingGift;
      try {
        existingGift = _availableGifts.firstWhere((gift) => gift.id == giftId);
      } catch (e) {
        existingGift = null;
      }
      
      if (existingGift != null) {
        return existingGift;
      }

      // Load from service
      final result = await _giftService.getGiftById(giftId);
      return result.success ? result.gift : null;
    } catch (e) {
      debugPrint('Error getting gift by ID: $e');
      return null;
    }
  }

  // GIFT SENDING OPERATIONS

  /// Send gift to user
  Future<bool> sendGift({
    required String giftId,
    required String recipientUserId,
    String? personalMessage,
    String? conversationId,
  }) async {
    if (_authProvider?.isAuthenticated != true) {
      _setSendError('Please sign in to send gifts');
      return false;
    }

    _isSendingGift = true;
    _clearSendError();
    notifyListeners();
    
    try {
      // Validate inputs
      if (giftId.isEmpty || recipientUserId.isEmpty) {
        _setSendError('Invalid gift or recipient');
        return false;
      }

      // Check if user is trying to send gift to themselves
      if (_authProvider?.user?.uid == recipientUserId) {
        _setSendError('You cannot send gifts to yourself');
        return false;
      }

      // Get gift details for validation
      final gift = await getGiftById(giftId);
      if (gift == null) {
        _setSendError('Gift not found or unavailable');
        return false;
      }

      // Check premium-only gifts
      if (gift.isPremiumOnly && !(_authProvider?.isPremium ?? false)) {
        _setSendError('This gift requires a premium subscription');
        return false;
      }

      // Send gift through service
      final result = await _giftService.sendGift(
        giftId: giftId,
        recipientUserId: recipientUserId,
        personalMessage: personalMessage,
        conversationId: conversationId,
      );
      
      if (result.success && result.sentGift != null) {
        // Add to sent gifts list at the beginning
        _sentGifts.insert(0, result.sentGift!);
        
        debugPrint('Gift sent successfully: $giftId to $recipientUserId');
        notifyListeners();
        return true;
      } else {
        _setSendError(result.error ?? 'Failed to send gift');
        return false;
      }
    } catch (e) {
      _setSendError('Failed to send gift: $e');
      debugPrint('Error sending gift: $e');
      return false;
    } finally {
      _isSendingGift = false;
      notifyListeners();
    }
  }

  // USER GIFT HISTORY OPERATIONS

  /// Load gifts sent by current user
  Future<void> loadSentGifts({
    String? recipientUserId,
    bool refresh = false,
  }) async {
    if (_authProvider?.isAuthenticated != true) return;

    if (refresh) {
      _sentGifts.clear();
      _lastSentDocument = null;
      _hasMoreSentGifts = false;
    }
    
    _isLoadingSentGifts = true;
    _clearError();
    notifyListeners();
    
    try {
      final result = await _giftService.getSentGifts(
        recipientUserId: recipientUserId,
        limit: 20,
        lastDocument: _lastSentDocument,
      );
      
      if (result.success) {
        if (refresh) {
          _sentGifts = result.sentGifts;
        } else {
          _sentGifts.addAll(result.sentGifts);
        }
        
        _lastSentDocument = result.lastDocument;
        _hasMoreSentGifts = result.hasMore;
        
        debugPrint('Sent gifts loaded: ${result.sentGifts.length}');
      } else {
        _setError(result.error ?? 'Failed to load sent gifts');
      }
    } catch (e) {
      _setError('Failed to load sent gifts: $e');
      debugPrint('Error loading sent gifts: $e');
    } finally {
      _isLoadingSentGifts = false;
      notifyListeners();
    }
  }

  /// Load gifts received by current user
  Future<void> loadReceivedGifts({
    String? senderUserId,
    bool refresh = false,
  }) async {
    if (_authProvider?.isAuthenticated != true) return;

    if (refresh) {
      _receivedGifts.clear();
      _lastReceivedDocument = null;
      _hasMoreReceivedGifts = false;
    }
    
    _isLoadingReceivedGifts = true;
    _clearError();
    notifyListeners();
    
    try {
      final result = await _giftService.getReceivedGifts(
        senderUserId: senderUserId,
        limit: 20,
        lastDocument: _lastReceivedDocument,
      );
      
      if (result.success) {
        if (refresh) {
          _receivedGifts = result.sentGifts;
        } else {
          _receivedGifts.addAll(result.sentGifts);
        }
        
        _lastReceivedDocument = result.lastDocument;
        _hasMoreReceivedGifts = result.hasMore;
        
        debugPrint('Received gifts loaded: ${result.sentGifts.length}');
      } else {
        _setError(result.error ?? 'Failed to load received gifts');
      }
    } catch (e) {
      _setError('Failed to load received gifts: $e');
      debugPrint('Error loading received gifts: $e');
    } finally {
      _isLoadingReceivedGifts = false;
      notifyListeners();
    }
  }

  /// Load more sent gifts (pagination)
  Future<void> loadMoreSentGifts() async {
    if (!_hasMoreSentGifts || _isLoadingSentGifts) return;
    await loadSentGifts(refresh: false);
  }

  /// Load more received gifts (pagination)
  Future<void> loadMoreReceivedGifts() async {
    if (!_hasMoreReceivedGifts || _isLoadingReceivedGifts) return;
    await loadReceivedGifts(refresh: false);
  }

  // GIFT INTERACTION OPERATIONS

  /// Mark gift as read
  Future<bool> markGiftAsRead(String sentGiftId) async {
    try {
      final result = await _giftService.markGiftAsRead(sentGiftId);
      
      if (result.success && result.sentGift != null) {
        // Update local state
        final index = _receivedGifts.indexWhere((gift) => gift.id == sentGiftId);
        if (index != -1) {
          _receivedGifts[index] = result.sentGift!;
        }
        
        // Update unread count
        await _loadUnreadGiftsCount();
        
        notifyListeners();
        return true;
      } else {
        _setError(result.error ?? 'Failed to mark gift as read');
        return false;
      }
    } catch (e) {
      _setError('Failed to mark gift as read: $e');
      debugPrint('Error marking gift as read: $e');
      return false;
    }
  }

  /// Mark all received gifts as read
  Future<void> markAllGiftsAsRead() async {
    try {
      final unreadGifts = _receivedGifts.where((gift) => !gift.isRead).toList();
      
      for (final gift in unreadGifts) {
        await markGiftAsRead(gift.id);
      }
      
      debugPrint('All gifts marked as read');
    } catch (e) {
      debugPrint('Error marking all gifts as read: $e');
    }
  }

  // UI STATE MANAGEMENT OPERATIONS

  /// Select gift for UI interactions
  void selectGift(GiftModel gift) {
    _selectedGift = gift;
    notifyListeners();
  }

  /// Clear selected gift
  void clearSelectedGift() {
    _selectedGift = null;
    notifyListeners();
  }

  /// Select category for filtering
  void selectCategory(GiftCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Clear selected category
  void clearSelectedCategory() {
    _selectedCategory = null;
    notifyListeners();
  }

  // GIFT FILTERING AND SEARCH OPERATIONS

  /// Filter gifts by rarity
  List<GiftModel> getGiftsByRarity(GiftRarity rarity) {
    return _availableGifts.where((gift) => gift.rarity == rarity).toList();
  }

  /// Get gifts within price range
  List<GiftModel> getGiftsInPriceRange(double minPrice, double maxPrice) {
    return _availableGifts.where((gift) => 
        gift.finalPrice >= minPrice && gift.finalPrice <= maxPrice).toList();
  }

  /// Search gifts by name, description, or tags
  List<GiftModel> searchGifts(String query) {
    if (query.isEmpty) return _availableGifts;
    
    final lowercaseQuery = query.toLowerCase();
    return _availableGifts.where((gift) =>
        gift.name.toLowerCase().contains(lowercaseQuery) ||
        gift.description.toLowerCase().contains(lowercaseQuery) ||
        gift.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery))
    ).toList();
  }

  /// Get gifts for specific category
  List<GiftModel> getGiftsForCategory(GiftCategory category) {
    return _availableGifts.where((gift) => gift.category == category).toList();
  }

  /// Get premium-only gifts
  List<GiftModel> getPremiumOnlyGifts() {
    return _availableGifts.where((gift) => gift.isPremiumOnly).toList();
  }

  /// Get gifts by tags
  List<GiftModel> getGiftsByTag(String tag) {
    return _availableGifts.where((gift) => 
        gift.tags.any((t) => t.toLowerCase() == tag.toLowerCase())).toList();
  }

  // REAL-TIME UPDATES

  /// Stream received gifts for real-time updates
  Stream<List<SentGiftModel>> streamReceivedGifts() {
    return _giftService.streamReceivedGifts();
  }

  /// Listen to received gifts stream
  void startListeningToReceivedGifts() {
    streamReceivedGifts().listen((gifts) {
      if (gifts.isNotEmpty) {
        _receivedGifts = gifts;
        _loadUnreadGiftsCount();
        notifyListeners();
      }
    });
  }

  // CACHE AND REFRESH OPERATIONS

  /// Clear gift cache and refresh all data
  Future<void> clearCacheAndRefresh() async {
    _setLoading(true);
    
    try {
      await _giftService.clearGiftCache();
      await Future.wait([
        loadAvailableGifts(refresh: true),
        loadPopularGifts(),
        loadSentGifts(refresh: true),
        loadReceivedGifts(refresh: true),
      ]);
      debugPrint('Gift cache cleared and data refreshed');
    } catch (e) {
      _setError('Failed to refresh gifts: $e');
      debugPrint('Error clearing cache and refreshing: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh all gift data
  Future<void> refreshAll() async {
    await Future.wait([
      loadAvailableGifts(refresh: true),
      loadPopularGifts(),
      loadSentGifts(refresh: true),
      loadReceivedGifts(refresh: true),
    ]);
  }

  // PRIVATE HELPER METHODS

  /// Load unread gifts count
  Future<void> _loadUnreadGiftsCount() async {
    try {
      _unreadGiftsCount = await _giftService.getUnreadGiftsCount();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading unread gifts count: $e');
    }
  }

  /// Load category counts
  Future<void> _loadCategoryCounts() async {
    try {
      _categoryCounts = await _giftService.getGiftCategoryCounts();
    } catch (e) {
      debugPrint('Error loading category counts: $e');
    }
  }

  /// Organize gifts by category for efficient access
  void _organizeGiftsByCategory() {
    _giftsByCategory.clear();
    
    for (final gift in _availableGifts) {
      final category = gift.category;
      if (!_giftsByCategory.containsKey(category)) {
        _giftsByCategory[category] = [];
      }
      _giftsByCategory[category]!.add(gift);
    }
    
    // Sort each category by price (ascending)
    for (final category in _giftsByCategory.keys) {
      _giftsByCategory[category]!.sort((a, b) => a.finalPrice.compareTo(b.finalPrice));
    }
  }


  // STATE MANAGEMENT METHODS

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _setSendError(String? error) {
    _sendError = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void _clearSendError() {
    _sendError = null;
    notifyListeners();
  }

  /// Clear all errors
  void clearErrors() {
    _clearError();
    _clearSendError();
  }

  /// Clear specific error types
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSendError() {
    _sendError = null;
    notifyListeners();
  }

  /// Reset all state (called on logout)
  void _resetState() {
    _availableGifts.clear();
    _giftsByCategory.clear();
    _categoryCounts.clear();
    _popularGifts.clear();
    _featuredGifts.clear();
    _sentGifts.clear();
    _receivedGifts.clear();
    _selectedGift = null;
    _selectedCategory = null;
    _lastSentDocument = null;
    _lastReceivedDocument = null;
    _hasMoreSentGifts = false;
    _hasMoreReceivedGifts = false;
    _unreadGiftsCount = 0;
    _error = null;
    _sendError = null;
  }

  // VALIDATION HELPERS

  /// Check if user can send gifts
  bool get canSendGifts {
    return _authProvider?.isAuthenticated == true;
  }

  /// Check if user can send premium gifts
  bool get canSendPremiumGifts {
    return canSendGifts && (_authProvider?.isPremium == true);
  }

  /// Validate gift selection before sending
  String? validateGiftSelection({
    required String giftId,
    required String recipientUserId,
  }) {
    if (!canSendGifts) return 'Please sign in to send gifts';
    if (giftId.isEmpty) return 'Please select a gift';
    if (recipientUserId.isEmpty) return 'Invalid recipient';
    if (_authProvider?.user?.uid == recipientUserId) return 'Cannot send gift to yourself';
    
    GiftModel? gift;
    try {
      gift = _availableGifts.firstWhere((g) => g.id == giftId);
    } catch (e) {
      gift = null;
    }
    
    if (gift == null) return 'Gift not found';
    if (!gift.isAvailable) return 'Gift is no longer available';
    if (gift.isPremiumOnly && !canSendPremiumGifts) {
      return 'This gift requires a premium subscription';
    }
    
    return null; // Valid
  }

  @override
  void dispose() {
    _availableGifts.clear();
    _giftsByCategory.clear();
    _sentGifts.clear();
    _receivedGifts.clear();
    super.dispose();
  }
}