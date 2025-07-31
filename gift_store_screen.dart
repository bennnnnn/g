import 'package:flutter/material.dart';
import '../../models/gift_model.dart';
import '../../widgets/custom_button.dart';

class GiftStoreScreen extends StatefulWidget {
  @override
  _GiftStoreScreenState createState() => _GiftStoreScreenState();
}

class _GiftStoreScreenState extends State<GiftStoreScreen> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  List<GiftModel> _gifts = [];
  List<SentGiftModel> _sentGifts = [];
  List<SentGiftModel> _receivedGifts = [];
  bool _isLoading = false;
  int _userCoins = 150; // User's coin balance

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGifts();
    _loadGiftHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGifts() async {
    setState(() {
      _isLoading = true;
    });

    // Mock gifts data
    final mockGifts = [
      // Hearts & Love
      GiftModel(
        id: 'gift_1',
        name: 'Red Rose',
        description: 'A classic symbol of love',
        imageUrl: '🌹',
        animationUrl: '',
        price: 10,
        category: GiftCategory.flowers,
        rarity: GiftRarity.common,
        createdAt: DateTime.now(),
        tags: ['romantic', 'classic'],
      ),
      GiftModel(
        id: 'gift_2',
        name: 'Heart',
        description: 'Show your love',
        imageUrl: '❤️',
        animationUrl: '',
        price: 5,
        category: GiftCategory.hearts,
        rarity: GiftRarity.common,
        createdAt: DateTime.now(),
        tags: ['love', 'simple'],
      ),
      GiftModel(
        id: 'gift_3',
        name: 'Bouquet',
        description: 'Beautiful flower bouquet',
        imageUrl: '💐',
        animationUrl: '',
        price: 25,
        category: GiftCategory.flowers,
        rarity: GiftRarity.uncommon,
        createdAt: DateTime.now(),
        tags: ['romantic', 'elegant'],
      ),
      
      // Food & Treats
      GiftModel(
        id: 'gift_4',
        name: 'Chocolate',
        description: 'Sweet chocolate box',
        imageUrl: '🍫',
        animationUrl: '',
        price: 15,
        category: GiftCategory.food,
        rarity: GiftRarity.common,
        createdAt: DateTime.now(),
        tags: ['sweet', 'treat'],
      ),
      GiftModel(
        id: 'gift_5',
        name: 'Birthday Cake',
        description: 'Celebrate together',
        imageUrl: '🎂',
        animationUrl: '',
        price: 30,
        category: GiftCategory.food,
        rarity: GiftRarity.uncommon,
        createdAt: DateTime.now(),
        tags: ['celebration', 'special'],
      ),
      
      // Drinks
      GiftModel(
        id: 'gift_6',
        name: 'Champagne',
        description: 'Celebrate in style',
        imageUrl: '🥂',
        animationUrl: '',
        price: 50,
        category: GiftCategory.drinks,
        rarity: GiftRarity.rare,
        createdAt: DateTime.now(),
        tags: ['celebration', 'luxury'],
      ),
      
      // Jewelry
      GiftModel(
        id: 'gift_7',
        name: 'Diamond Ring',
        description: 'The ultimate gesture',
        imageUrl: '💍',
        animationUrl: '',
        price: 200,
        category: GiftCategory.jewelry,
        rarity: GiftRarity.legendary,
        isPremiumOnly: true,
        createdAt: DateTime.now(),
        tags: ['luxury', 'commitment'],
      ),
      
      // Animals
      GiftModel(
        id: 'gift_8',
        name: 'Teddy Bear',
        description: 'Cute and cuddly',
        imageUrl: '🧸',
        animationUrl: '',
        price: 20,
        category: GiftCategory.animals,
        rarity: GiftRarity.common,
        createdAt: DateTime.now(),
        tags: ['cute', 'comfort'],
      ),
      
      // Premium
      GiftModel(
        id: 'gift_9',
        name: 'Golden Star',
        description: 'You are a star!',
        imageUrl: '⭐',
        animationUrl: '',
        price: 100,
        category: GiftCategory.premium,
        rarity: GiftRarity.epic,
        isPremiumOnly: true,
        createdAt: DateTime.now(),
        tags: ['premium', 'special'],
      ),
    ];

    setState(() {
      _gifts = mockGifts;
      _isLoading = false;
    });
  }

  Future<void> _loadGiftHistory() async {
    // Mock sent and received gifts
    // This would typically come from an API
    setState(() {
      _sentGifts = [];
      _receivedGifts = [];
    });
  }

  void _buyCoins() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Buy Coins',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              _buildCoinPackage('100 Coins', '\$2.99', 100),
              _buildCoinPackage('500 Coins', '\$12.99', 500),
              _buildCoinPackage('1000 Coins', '\$19.99', 1000),
              _buildCoinPackage('2500 Coins', '\$39.99', 2500),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoinPackage(String title, String price, int coins) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber, Colors.orange],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.monetization_on,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text('Best value for your money'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              price,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          _purchaseCoins(coins);
        },
      ),
    );
  }

  void _purchaseCoins(int coins) {
    setState(() {
      _userCoins += coins;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully purchased $coins coins!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _purchaseGift(GiftModel gift) {
    if (_userCoins < gift.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough coins! You need ${gift.price - _userCoins} more coins.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Buy Coins',
            textColor: Colors.white,
            onPressed: _buyCoins,
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase ${gift.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              gift.imageUrl,
              style: const TextStyle(fontSize: 60),
            ),
            const SizedBox(height: 16),
            Text(gift.description),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Price: ${gift.price} coins'),
                Text('Balance: $_userCoins coins'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _userCoins -= gift.price;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${gift.name} added to your collection!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Purchase'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Gift Store',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber, Colors.orange],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_userCoins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _buyCoins,
            icon: const Icon(
              Icons.add_circle,
              color: Colors.pink,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pink,
          labelColor: Colors.pink,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Store'),
            Tab(text: 'Sent'),
            Tab(text: 'Received'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStoreTab(),
          _buildSentTab(),
          _buildReceivedTab(),
        ],
      ),
    );
  }

  Widget _buildStoreTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.pink),
      );
    }

    final categories = GiftCategory.values;
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Featured gifts banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink.shade400, Colors.red.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Send Special Gifts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Make someone smile today',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '🎁',
                  style: TextStyle(fontSize: 40),
                ),
              ],
            ),
          ),

          // Categories
          ...categories.map((category) {
            final categoryGifts = _gifts
                .where((gift) => gift.category == category && gift.isActive)
                .toList();
            
            if (categoryGifts.isEmpty) return const SizedBox();
            
            return _buildCategorySection(category, categoryGifts);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategorySection(GiftCategory category, List<GiftModel> gifts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                category.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Text(
                category.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: gifts.length,
            itemBuilder: (context, index) {
              return _buildGiftCard(gifts[index]);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGiftCard(GiftModel gift) {
    final canAfford = _userCoins >= gift.price;
    
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: gift.rarity == GiftRarity.legendary
            ? Border.all(color: Colors.amber, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gift image and rarity indicator
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: gift.rarity == GiftRarity.legendary
                  ? LinearGradient(
                      colors: [Colors.amber.shade200, Colors.orange.shade200],
                    )
                  : gift.rarity == GiftRarity.epic
                      ? LinearGradient(
                          colors: [Colors.purple.shade200, Colors.pink.shade200],
                        )
                      : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    gift.imageUrl,
                    style: const TextStyle(fontSize: 50),
                  ),
                ),
                if (gift.isPremiumOnly)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: gift.rarity == GiftRarity.legendary
                          ? Colors.amber
                          : gift.rarity == GiftRarity.epic
                              ? Colors.purple
                              : gift.rarity == GiftRarity.rare
                                  ? Colors.blue
                                  : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      gift.rarity.emoji,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Gift info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gift.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gift.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${gift.price}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: canAfford ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _purchaseGift(gift),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: canAfford ? Colors.pink : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Buy',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: canAfford ? Colors.white : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentTab() {
    if (_sentGifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_giftcard,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            const Text(
              'No gifts sent yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start spreading joy by sending gifts!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sentGifts.length,
      itemBuilder: (context, index) {
        final sentGift = _sentGifts[index];
        return _buildGiftHistoryItem(sentGift, true);
      },
    );
  }

  Widget _buildReceivedTab() {
    if (_receivedGifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            const Text(
              'No gifts received yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gifts from your matches will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _receivedGifts.length,
      itemBuilder: (context, index) {
        final receivedGift = _receivedGifts[index];
        return _buildGiftHistoryItem(receivedGift, false);
      },
    );
  }

  Widget _buildGiftHistoryItem(SentGiftModel sentGift, bool isSent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            sentGift.gift.imageUrl,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sentGift.gift.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSent ? 'Sent to someone special' : 'Received from admirer',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(sentGift.sentAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${sentGift.gift.price}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              if (!sentGift.isRead && !isSent)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}