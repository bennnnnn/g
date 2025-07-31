import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';

class FiltersBottomSheet extends StatefulWidget {
  @override
  _FiltersBottomSheetState createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<FiltersBottomSheet> {
  // Filter values
  RangeValues _ageRange = const RangeValues(18, 35);
  double _distance = 50;
  String? _selectedGender;
  bool _verifiedOnly = false;
  bool _premiumOnly = false;
  bool _recentlyActive = false;
  List<String> _selectedInterests = [];
  String? _education;
  String? _lifestyle;
  bool _hasChildren = false;
  bool _wantsChildren = false;

  // Options
  final List<String> _genderOptions = ['Men', 'Women', 'Everyone'];
  final List<String> _interestOptions = [
    'Travel', 'Music', 'Sports', 'Art', 'Food', 'Movies',
    'Books', 'Fitness', 'Technology', 'Nature', 'Dancing', 'Photography'
  ];
  final List<String> _educationOptions = [
    'High School', 'Some College', 'Bachelor\'s', 'Master\'s', 'PhD', 'Trade School'
  ];
  final List<String> _lifestyleOptions = [
    'Active', 'Relaxed', 'Social', 'Quiet', 'Adventurous', 'Homebody'
  ];

  @override
  void initState() {
    super.initState();
    _selectedGender = _genderOptions[0];
  }

  void _resetFilters() {
    setState(() {
      _ageRange = const RangeValues(18, 35);
      _distance = 50;
      _selectedGender = _genderOptions[0];
      _verifiedOnly = false;
      _premiumOnly = false;
      _recentlyActive = false;
      _selectedInterests.clear();
      _education = null;
      _lifestyle = null;
      _hasChildren = false;
      _wantsChildren = false;
    });
  }

  void _applyFilters() {
    // Apply filters logic here
    Navigator.pop(context, {
      'ageRange': _ageRange,
      'distance': _distance,
      'gender': _selectedGender,
      'verifiedOnly': _verifiedOnly,
      'premiumOnly': _premiumOnly,
      'recentlyActive': _recentlyActive,
      'interests': _selectedInterests,
      'education': _education,
      'lifestyle': _lifestyle,
      'hasChildren': _hasChildren,
      'wantsChildren': _wantsChildren,
    });
  }

  @override
  Widget build(BuildContext context) {
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
          // Header
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
                  'Filters',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: Colors.pink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Age Range
                  _buildSectionTitle('Age Range'),
                  Text(
                    '${_ageRange.start.round()} - ${_ageRange.end.round()} years',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  RangeSlider(
                    values: _ageRange,
                    min: 18,
                    max: 100,
                    divisions: 82,
                    activeColor: Colors.pink,
                    onChanged: (values) {
                      setState(() {
                        _ageRange = values;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Distance
                  _buildSectionTitle('Distance'),
                  Text(
                    '${_distance.round()} km away',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Slider(
                    value: _distance,
                    min: 1,
                    max: 200,
                    divisions: 199,
                    activeColor: Colors.pink,
                    onChanged: (value) {
                      setState(() {
                        _distance = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Gender
                  _buildSectionTitle('Show me'),
                  ...(_genderOptions.map((gender) => RadioListTile<String>(
                    value: gender,
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                    title: Text(gender),
                    activeColor: Colors.pink,
                    contentPadding: EdgeInsets.zero,
                  )).toList()),
                  
                  const SizedBox(height: 24),
                  
                  // Preferences
                  _buildSectionTitle('Preferences'),
                  _buildSwitchTile(
                    title: 'Verified profiles only',
                    subtitle: 'Show only verified users',
                    value: _verifiedOnly,
                    onChanged: (value) {
                      setState(() {
                        _verifiedOnly = value;
                      });
                    },
                  ),
                  _buildSwitchTile(
                    title: 'Premium members only',
                    subtitle: 'Show only premium subscribers',
                    value: _premiumOnly,
                    onChanged: (value) {
                      setState(() {
                        _premiumOnly = value;
                      });
                    },
                  ),
                  _buildSwitchTile(
                    title: 'Recently active',
                    subtitle: 'Show users active in the last week',
                    value: _recentlyActive,
                    onChanged: (value) {
                      setState(() {
                        _recentlyActive = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Interests
                  _buildSectionTitle('Interests'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interestOptions.map((interest) {
                      final isSelected = _selectedInterests.contains(interest);
                      return FilterChip(
                        label: Text(interest),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedInterests.add(interest);
                            } else {
                              _selectedInterests.remove(interest);
                            }
                          });
                        },
                        selectedColor: Colors.pink.withOpacity(0.2),
                        checkmarkColor: Colors.pink,
                        side: BorderSide(
                          color: isSelected ? Colors.pink : Colors.grey.shade300,
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Education
                  _buildSectionTitle('Education'),
                  _buildDropdown(
                    hint: 'Select education level',
                    value: _education,
                    items: _educationOptions,
                    onChanged: (value) {
                      setState(() {
                        _education = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Lifestyle
                  _buildSectionTitle('Lifestyle'),
                  _buildDropdown(
                    hint: 'Select lifestyle',
                    value: _lifestyle,
                    items: _lifestyleOptions,
                    onChanged: (value) {
                      setState(() {
                        _lifestyle = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Family
                  _buildSectionTitle('Family'),
                  _buildSwitchTile(
                    title: 'Has children',
                    subtitle: 'Show users who have children',
                    value: _hasChildren,
                    onChanged: (value) {
                      setState(() {
                        _hasChildren = value;
                      });
                    },
                  ),
                  _buildSwitchTile(
                    title: 'Wants children',
                    subtitle: 'Show users who want children',
                    value: _wantsChildren,
                    onChanged: (value) {
                      setState(() {
                        _wantsChildren = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Apply button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: SafeArea(
              child: CustomButton(
                text: 'Apply Filters',
                onPressed: _applyFilters,
                width: double.infinity,
                backgroundColor: Colors.pink,
                textColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.pink,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(hint),
          value: value,
          isExpanded: true,
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                'Any',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ...items.map((item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            )).toList(),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}