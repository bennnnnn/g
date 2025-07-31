// models/user_search_filter_model.dart
class UserSearchFilter {
  final String? country;
  final String? city;
  final String? religion;
  final String? education;
  final int? minAge;
  final int? maxAge;
  final String? gender;
  final String? interestedIn;
  final double? maxDistance;
  final bool? verifiedOnly;
  final bool? recentlyActiveOnly;
  final bool? hasPhotosOnly;
  final bool? premiumOnly;
  final String? searchQuery; // For name/bio search
  
  const UserSearchFilter({
    this.country,
    this.city,
    this.religion,
    this.education,
    this.minAge,
    this.maxAge,
    this.gender,
    this.interestedIn,
    this.maxDistance,
    this.verifiedOnly,
    this.recentlyActiveOnly,
    this.hasPhotosOnly,
    this.premiumOnly,
    this.searchQuery,
  });

  // Check if any filters are applied
  bool get hasActiveFilters {
    return country != null ||
           city != null ||
           religion != null ||
           education != null ||
           minAge != null ||
           maxAge != null ||
           gender != null ||
           interestedIn != null ||
           maxDistance != null ||
           verifiedOnly == true ||
           recentlyActiveOnly == true ||
           hasPhotosOnly == true ||
           premiumOnly == true ||
           (searchQuery?.isNotEmpty ?? false);
  }

  // Get active filter count for UI
  int get activeFilterCount {
    int count = 0;
    if (country != null) count++;
    if (city != null) count++;
    if (religion != null) count++;
    if (education != null) count++;
    if (minAge != null || maxAge != null) count++;
    if (gender != null) count++;
    if (interestedIn != null) count++;
    if (maxDistance != null) count++;
    if (verifiedOnly == true) count++;
    if (recentlyActiveOnly == true) count++;
    if (hasPhotosOnly == true) count++;
    if (premiumOnly == true) count++;
    if (searchQuery?.isNotEmpty ?? false) count++;
    return count;
  }

  // Convert to Firestore query parameters
  Map<String, dynamic> toFirestoreQuery() {
    Map<String, dynamic> query = {};
    
    if (country != null) query['country'] = country;
    if (city != null) query['city'] = city;
    if (religion != null) query['religion'] = religion;
    if (education != null) query['education'] = education;
    if (gender != null) query['gender'] = gender;
    if (interestedIn != null) query['interestedIn'] = interestedIn;
    if (verifiedOnly == true) query['isVerified'] = true;
    if (hasPhotosOnly == true) query['photos'] = {'arraySize': {'greaterThan': 0}};
    if (premiumOnly == true) query['subscriptionPlan'] = {'notEqualTo': 'free'};
    
    return query;
  }

  // Convert from JSON
  factory UserSearchFilter.fromJson(Map<String, dynamic> json) {
    return UserSearchFilter(
      country: json['country'],
      city: json['city'],
      religion: json['religion'],
      education: json['education'],
      minAge: json['minAge'],
      maxAge: json['maxAge'],
      gender: json['gender'],
      interestedIn: json['interestedIn'],
      maxDistance: json['maxDistance']?.toDouble(),
      verifiedOnly: json['verifiedOnly'],
      recentlyActiveOnly: json['recentlyActiveOnly'],
      hasPhotosOnly: json['hasPhotosOnly'],
      premiumOnly: json['premiumOnly'],
      searchQuery: json['searchQuery'],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'city': city,
      'religion': religion,
      'education': education,
      'minAge': minAge,
      'maxAge': maxAge,
      'gender': gender,
      'interestedIn': interestedIn,
      'maxDistance': maxDistance,
      'verifiedOnly': verifiedOnly,
      'recentlyActiveOnly': recentlyActiveOnly,
      'hasPhotosOnly': hasPhotosOnly,
      'premiumOnly': premiumOnly,
      'searchQuery': searchQuery,
    };
  }

  UserSearchFilter copyWith({
    String? country,
    String? city,
    String? religion,
    String? education,
    int? minAge,
    int? maxAge,
    String? gender,
    String? interestedIn,
    double? maxDistance,
    bool? verifiedOnly,
    bool? recentlyActiveOnly,
    bool? hasPhotosOnly,
    bool? premiumOnly,
    String? searchQuery,
  }) {
    return UserSearchFilter(
      country: country ?? this.country,
      city: city ?? this.city,
      religion: religion ?? this.religion,
      education: education ?? this.education,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      maxDistance: maxDistance ?? this.maxDistance,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      recentlyActiveOnly: recentlyActiveOnly ?? this.recentlyActiveOnly,
      hasPhotosOnly: hasPhotosOnly ?? this.hasPhotosOnly,
      premiumOnly: premiumOnly ?? this.premiumOnly,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  // Clear all filters
  UserSearchFilter clear() {
    return const UserSearchFilter();
  }

  @override
  String toString() {
    return 'UserSearchFilter(filters: $activeFilterCount active)';
  }
}