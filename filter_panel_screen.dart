import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_search_filter_model.dart';
import '../../models/enums.dart';
import '../../services/location_service.dart';
import '../../services/analytics_service.dart';
import '../../services/validation_service.dart';

class FilterPanelScreen extends StatefulWidget {
  final UserSearchFilterModel currentFilters;

  const FilterPanelScreen({
    Key? key,
    required this.currentFilters,
  }) : super(key: key);

  @override
  State<FilterPanelScreen> createState() => _FilterPanelScreenState();
}

class _FilterPanelScreenState extends State<FilterPanelScreen>
    with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final ValidationService _validationService = ValidationService();
  
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  
  // Local filter state (until user applies)
  String? _selectedCountry;
  String? _selectedCity;
  String? _selectedReligion;
  String? _selectedEducation;
  RangeValues _ageRange = const RangeValues(18, 35);
  Gender? _selectedGender;
  double _maxDistance = 50;
  bool _verifiedOnly = false;
  bool _recentlyActiveOnly = false;
  bool _hasPhotosOnly = false;
  bool _premiumOnly = false;

  // Controllers
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // Predefined options
  final List<String> _popularCountries = [
    'United States',
    'Canada',
    'United Kingdom',
    'Australia',
    'Germany',
    'France',
    'Spain',
    'Italy',
    'Japan',
    'South Korea',
    'Brazil',
    'Mexico',
    'India',
    'Netherlands',
    'Sweden',
  ];
  
  final Map<String, List<String>> _popularCities = {
    'United States': [
      'New York',
      'Los Angeles',
      'Chicago',
      'Houston',
      'Phoenix',
      'Philadelphia',
      'San Antonio',
      'San Diego',
      'Dallas',
      'San Jose',
      'Austin',
      'Jacksonville',
    ],
    'Canada': [
      'Toronto',
      'Montreal',
      'Vancouver',
      'Calgary',
      'Edmonton',
      'Ottawa',
      'Winnipeg',
      'Quebec City',
    ],
    'United Kingdom': [
      'London',
      'Birmingham',
      'Manchester',
      'Glasgow',
      'Liverpool',
      'Leeds',
      'Sheffield',
      'Edinburgh',
      'Bristol',
      'Cardiff',
    ],
  };

  final List<String> _religions = [
    'Christianity',
    'Islam',
    'Judaism',
    'Hinduism',
    'Buddhism',
    'Sikhism',
    'Other',
    'Not Religious',
    'Prefer not to say',
  ];

  final List<String> _educationLevels = [
    'High School',
    'Some College',
    'Bachelor\'s Degree',
    'Master\'s Degree',
    'PhD',
    'Trade School',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupAnimations();
    _loadCurrentFilters();
    _trackScreenView();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  void _loadCurrentFilters() {
    final currentFilters = widget.currentFilters;
    
    setState(() {
      _selectedCountry = currentFilters.country;
      _selectedCity = currentFilters.city;
      _selectedReligion = null; // Not in current model - would need to add
      _selectedEducation = null; // Not in current model - would need to add
      _ageRange = RangeValues(
        (currentFilters.minAge ?? 18).toDouble(),
        (currentFilters.maxAge ?? 35).toDouble(),
      );
      _selectedGender = currentFilters.gender;
      _maxDistance = currentFilters.maxDistance ?? 50;
      _verifiedOnly = currentFilters.verifiedOnly ?? false;
      _recentlyActiveOnly = currentFilters.recentlyActive ?? false;
      _hasPhotosOnly = false; // Not in current model - would need to add
      _premiumOnly = false; // Not in current model - would need to add
    });

    // Initialize controllers
    _countryController.text = _selectedCountry ?? '';
    _cityController.text = _selectedCity ?? '';
  }

  void _trackScreenView() {
    _analyticsService.trackScreenView('filter_panel_screen');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _applyFilters() async {
    // Validate filters
    final validation = _validationService.validateSearchFilters(
      minAge: _ageRange.start.round(),
      maxAge: _ageRange.end.round(),
      maxDistance: _maxDistance,
    );

    if (!validation.isValid) {
      _showErrorSnackBar(validation.error!);
      return;
    }

    // Create new filter from current state
    final newFilter = UserSearchFilterModel(
      country: _selectedCountry,
      city: _selectedCity,
      minAge: _ageRange.start.round(),
      maxAge: _ageRange.end.round(),
      gender: _selectedGender,
      maxDistance: _maxDistance,
      verifiedOnly: _verifiedOnly,
      recentlyActive: _recentlyActiveOnly,
    );

    // Track analytics
    await _analyticsService.trackUserInteraction(
      'filters_applied',
      'filter_panel_screen',
      properties: {
        'filter_count': _getActiveFilterCount(),
        'has_country': _selectedCountry != null,
        'has_city': _selectedCity != null,
        'age_range': '${_ageRange.start.round()}-${_ageRange.end.round()}',
        'distance': _maxDistance,
        'verified_only': _verifiedOnly,
        'recent_only': _recentlyActiveOnly,
      },
    );

    Navigator.of(context).pop(newFilter);
  }

  void _clearAllFilters() async {
    setState(() {
      _selectedCountry = null;
      _selectedCity = null;
      _selectedReligion = null;
      _selectedEducation = null;
      _ageRange = const RangeValues(18, 35);
      _selectedGender = null;
      _maxDistance = 50;
      _verifiedOnly = false;
      _recentlyActiveOnly = false;
      _hasPhotosOnly = false;
      _premiumOnly = false;
      _countryController.clear();
      _cityController.clear();
    });
    
    await _analyticsService.trackUserInteraction(
      'filters_cleared',
      'filter_panel_screen',
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  bool get _hasChanges {
    final currentFilters = widget.currentFilters;
    
    return _selectedCountry != currentFilters.country ||
           _selectedCity != currentFilters.city ||
           _ageRange.start.round() != (currentFilters.minAge ?? 18) ||
           _ageRange.end.round() != (currentFilters.maxAge ?? 35) ||
           _selectedGender != currentFilters.gender ||
           _maxDistance != (currentFilters.maxDistance ?? 50) ||
           _verifiedOnly != (currentFilters.verifiedOnly ?? false) ||
           _recentlyActiveOnly != (currentFilters.recentlyActive ?? false);
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedCountry != null) count++;
    if (_selectedCity != null) count++;
    if (_ageRange.start > 18 || _ageRange.end < 35) count++;
    if (_selectedGender != null) count++;
    if (_maxDistance != 50) count++;
    if (_verifiedOnly) count++;
    if (_recentlyActiveOnly) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SlideTransition(
        position: Offset(0, _slideAnimation.value),
        child: Column(
          children: [
            // Tab bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFFE91E63),
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: const Color(0xFFE91E63),
                tabs: const [
                  Tab(text: 'Location'),
                  Tab(text: 'Basics'),
                  Tab(text: 'Preferences'),
                ],
              ),
            ),
            
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLocationTab(),
                  _buildBasicsTab(),
                  _buildPreferencesTab(),
                ],
              ),
            ),
            
            // Bottom buttons
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Filters',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close),
      ),
      actions: [
        TextButton(
          onPressed: _clearAllFilters,
          child: const Text(
            'Clear All',
            style: TextStyle(
              color: Color(0xFFE91E63),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Country selection
          const Text(
            'Country',
            style: TextStyle(
              fontSize: 16,  
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showCountryPicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedCountry ?? 'Any Country',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedCountry != null 
                            ? Colors.black87 
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // City selection
          const Text(
            'City',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showCityPicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedCity ?? 'Any City',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedCity != null 
                            ? Colors.black87 
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Distance slider
          const Text(
            'Maximum Distance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_maxDistance.round()} km',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFE91E63),
              thumbColor: const Color(0xFFE91E63),
              overlayColor: const Color(0xFFE91E63).withOpacity(0.2),
            ),
            child: Slider(
              value: _maxDistance,
              min: 1,
              max: 200,
              divisions: 199,
              onChanged: (value) {
                setState(() {
                  _maxDistance = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Age range
          const Text(
            'Age Range',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_ageRange.start.round()} - ${_ageRange.end.round()} years old',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          RangeSlider(
            values: _ageRange,
            min: 18,
            max: 100,
            divisions: 82,
            activeColor: const Color(0xFFE91E63),
            labels: RangeLabels(
              _ageRange.start.round().toString(),
              _ageRange.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() {
                _ageRange = values;
              });
            },
          ),
          
          const SizedBox(height: 24),
          
          // Gender selection
          const Text(
            'Gender',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildGenderChip('All', null),
              _buildGenderChip('Women', Gender.female),
              _buildGenderChip('Men', Gender.male),
              _buildGenderChip('Non-binary', Gender.nonBinary),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Religion (if you want to add this to your model)
          const Text(
            'Religion',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showReligionPicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedReligion ?? 'Any Religion',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedReligion != null 
                            ? Colors.black87 
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Education
          const Text(
            'Education',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showEducationPicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedEducation ?? 'Any Education Level',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedEducation != null 
                            ? Colors.black87 
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Special Filters',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Verified only
          _buildSwitchTile(
            title: 'Verified profiles only',
            subtitle: 'Show only users with verified profiles',
            value: _verifiedOnly,
            onChanged: (value) {
              setState(() {
                _verifiedOnly = value;
              });
            },
            icon: Icons.verified,
          ),
          
          const SizedBox(height: 16),
          
          // Recently active
          _buildSwitchTile(
            title: 'Recently active',
            subtitle: 'Show users active within the last 7 days',
            value: _recentlyActiveOnly,
            onChanged: (value) {
              setState(() {
                _recentlyActiveOnly = value;
              });
            },
            icon: Icons.schedule,
          ),
          
          const SizedBox(height: 16),
          
          // Has photos
          _buildSwitchTile(
            title: 'Has photos',
            subtitle: 'Show only profiles with photos',
            value: _hasPhotosOnly,
            onChanged: (value) {
              setState(() {
                _hasPhotosOnly = value;
              });
            },
            icon: Icons.photo,
          ),
          
          const SizedBox(height: 16),
          
          // Premium users
          _buildSwitchTile(
            title: 'Premium users only',
            subtitle: 'Show only premium subscribers',
            value: _premiumOnly,
            onChanged: (value) {
              setState(() {
                _premiumOnly = value;
              });
            },
            icon: Icons.star,
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String label, Gender? gender) {
    final isSelected = _selectedGender == gender;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedGender = selected ? gender : null;
        });
      },
      selectedColor: const Color(0xFFE91E63).withOpacity(0.2),
      checkmarkColor: const Color(0xFFE91E63),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        secondary: Icon(
          icon,
          color: const Color(0xFFE91E63),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFE91E63),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          // Active filter count
          if (_getActiveFilterCount() > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_getActiveFilterCount()} filters',
                style: const TextStyle(
                  color: Color(0xFFE91E63),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          
          const Spacer(),
          
          // Apply button
          ElevatedButton(
            onPressed: _hasChanges ? _applyFilters : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Apply Filters',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Select Country',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _popularCountries.length,
                itemBuilder: (context, index) {
                  final country = _popularCountries[index];
                  return ListTile(
                    title: Text(country),
                    selected: _selectedCountry == country,
                    onTap: () {
                      setState(() {
                        _selectedCountry = country;
                        _selectedCity = null; // Reset city when country changes
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCityPicker() {
    if (_selectedCountry == null) {
      _showErrorSnackBar('Please select a country first');
      return;
    }

    final cities = _popularCities[_selectedCountry] ?? [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Select City in $_selectedCountry',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: cities.length,
                itemBuilder: (context, index) {
                  final city = cities[index];
                  return ListTile(
                    title: Text(city),
                    selected: _selectedCity == city,
                    onTap: () {
                      setState(() {
                        _selectedCity = city;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReligionPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Select Religion',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _religions.length,
                itemBuilder: (context, index) {
                  final religion = _religions[index];
                  return ListTile(
                    title: Text(religion),
                    selected: _selectedReligion == religion,
                    onTap: () {
                      setState(() {
                        _selectedReligion = religion;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEducationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Select Education Level',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _educationLevels.length,
                itemBuilder: (context, index) {
                  final education = _educationLevels[index];
                  return ListTile(
                    title: Text(education),
                    selected: _selectedEducation == education,
                    onTap: () {
                      setState(() {
                        _selectedEducation = education;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }