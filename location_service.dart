import 'dart:math';

class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  double? _currentLatitude;
  double? _currentLongitude;
  String? _currentAddress;
  bool _isLocationEnabled = false;
  bool _hasPermission = false;

  // Get current location
  Future<LocationResult> getCurrentLocation() async {
    try {
      // In a real app, you would use location packages like geolocator
      // Position position = await Geolocator.getCurrentPosition();
      
      // For demo purposes, simulate getting location
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock location (New York City)
      _currentLatitude = 40.7128;
      _currentLongitude = -74.0060;
      _currentAddress = 'New York, NY, USA';
      _isLocationEnabled = true;
      _hasPermission = true;

      return LocationResult(
        success: true,
        latitude: _currentLatitude!,
        longitude: _currentLongitude!,
        address: _currentAddress,
        message: 'Location obtained successfully',
      );
    } catch (e) {
      return LocationResult(
        success: false,
        message: 'Failed to get location: ${e.toString()}',
      );
    }
  }

  // Request location permissions
  Future<bool> requestLocationPermission() async {
    try {
      // In a real app, you would request permissions here
      // LocationPermission permission = await Geolocator.requestPermission();
      
      // For demo purposes, simulate permission granted
      _hasPermission = true;
      return true;
    } catch (e) {
      print('Failed to request location permission: $e');
      return false;
    }
  }

  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      // In a real app: return await Geolocator.isLocationServiceEnabled();
      return _isLocationEnabled;
    } catch (e) {
      print('Failed to check location service: $e');
      return false;
    }
  }

  // Check location permission status
  Future<LocationPermissionStatus> getLocationPermissionStatus() async {
    try {
      // In a real app, you would check actual permission status
      // LocationPermission permission = await Geolocator.checkPermission();
      
      if (_hasPermission) {
        return LocationPermissionStatus.granted;
      } else {
        return LocationPermissionStatus.denied;
      }
    } catch (e) {
      print('Failed to check permission status: $e');
      return LocationPermissionStatus.denied;
    }
  }

  // Calculate distance between two points in kilometers
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;
    
    return distance;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Get distance to another user
  double? getDistanceToUser({
    required double userLatitude,
    required double userLongitude,
  }) {
    if (_currentLatitude == null || _currentLongitude == null) {
      return null;
    }

    return calculateDistance(
      lat1: _currentLatitude!,
      lon1: _currentLongitude!,
      lat2: userLatitude,
      lon2: userLongitude,
    );
  }

  // Format distance for display
  String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m away';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceKm.round()}km away';
    }
  }

  // Get address from coordinates (reverse geocoding)
  Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // In a real app, you would use geocoding services
      // List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      // For demo purposes, return mock addresses based on coordinates
      return _getMockAddress(latitude, longitude);
    } catch (e) {
      print('Failed to get address: $e');
      return null;
    }
  }

  String _getMockAddress(double latitude, double longitude) {
    // Mock addresses for demo
    final mockAddresses = [
      'New York, NY',
      'Los Angeles, CA',
      'Chicago, IL',
      'Houston, TX',
      'Phoenix, AZ',
      'Philadelphia, PA',
      'San Antonio, TX',
      'San Diego, CA',
      'Dallas, TX',
      'San Jose, CA',
    ];
    
    // Use coordinates to generate consistent address
    int index = ((latitude + longitude).abs() * 100).round() % mockAddresses.length;
    return mockAddresses[index];
  }

  // Get coordinates from address (geocoding)
  Future<LocationCoordinates?> getCoordinatesFromAddress(String address) async {
    try {
      // In a real app, you would use geocoding services
      // List<Location> locations = await locationFromAddress(address);
      
      // For demo purposes, return mock coordinates
      return _getMockCoordinates(address);
    } catch (e) {
      print('Failed to get coordinates: $e');
      return null;
    }
  }

  LocationCoordinates _getMockCoordinates(String address) {
    // Mock coordinates for common cities
    final cityCoordinates = {
      'New York': LocationCoordinates(40.7128, -74.0060),
      'Los Angeles': LocationCoordinates(34.0522, -118.2437),
      'Chicago': LocationCoordinates(41.8781, -87.6298),
      'Houston': LocationCoordinates(29.7604, -95.3698),
      'Phoenix': LocationCoordinates(33.4484, -112.0740),
      'Philadelphia': LocationCoordinates(39.9526, -75.1652),
      'San Antonio': LocationCoordinates(29.4241, -98.4936),
      'San Diego': LocationCoordinates(32.7157, -117.1611),
      'Dallas': LocationCoordinates(32.7767, -96.7970),
      'San Jose': LocationCoordinates(37.3382, -121.8863),
    };

    // Try to find matching city
    for (String city in cityCoordinates.keys) {
      if (address.toLowerCase().contains(city.toLowerCase())) {
        return cityCoordinates[city]!;
      }
    }

    // Default to New York if no match found
    return cityCoordinates['New York']!;
  }

  // Update user location in backend
  Future<bool> updateUserLocation({
    required double latitude,
    required longitude,
  }) async {
    try {
      // In a real app, you would send location to your backend
      // final response = await http.post('$baseUrl/user/location', ...);
      
      _currentLatitude = latitude;
      _currentLongitude = longitude;
      _currentAddress = await getAddressFromCoordinates(
        latitude: latitude,
        longitude: longitude,
      );
      
      return true;
    } catch (e) {
      print('Failed to update user location: $e');
      return false;
    }
  }

  // Get nearby users (mock implementation)
  Future<List<NearbyUser>> getNearbyUsers({
    double radiusKm = 50,
    int limit = 20,
  }) async {
    try {
      if (_currentLatitude == null || _currentLongitude == null) {
        throw Exception('Current location not available');
      }

      // Mock nearby users
      final List<NearbyUser> nearbyUsers = [];
      final random = Random();

      for (int i = 0; i < limit; i++) {
        // Generate random coordinates within radius
        double randomLat = _currentLatitude! + 
            (random.nextDouble() - 0.5) * (radiusKm / 111); // Rough conversion
        double randomLon = _currentLongitude! + 
            (random.nextDouble() - 0.5) * (radiusKm / 111);

        double distance = calculateDistance(
          lat1: _currentLatitude!,
          lon1: _currentLongitude!,
          lat2: randomLat,
          lon2: randomLon,
        );

        if (distance <= radiusKm) {
          nearbyUsers.add(NearbyUser(
            userId: 'user_$i',
            latitude: randomLat,
            longitude: randomLon,
            distance: distance,
            lastSeen: DateTime.now().subtract(
              Duration(minutes: random.nextInt(60)),
            ),
          ));
        }
      }

      // Sort by distance
      nearbyUsers.sort((a, b) => a.distance.compareTo(b.distance));
      return nearbyUsers;
    } catch (e) {
      print('Failed to get nearby users: $e');
      return [];
    }
  }

  // Start location tracking
  Future<void> startLocationTracking() async {
    try {
      // In a real app, you would start location updates
      // Geolocator.getPositionStream().listen((Position position) { ... });
      
      print('Location tracking started');
    } catch (e) {
      print('Failed to start location tracking: $e');
    }
  }

  // Stop location tracking
  void stopLocationTracking() {
    try {
      // In a real app, you would stop location updates
      print('Location tracking stopped');
    } catch (e) {
      print('Failed to stop location tracking: $e');
    }
  }

  // Getters
  double? get currentLatitude => _currentLatitude;
  double? get currentLongitude => _currentLongitude;
  String? get currentAddress => _currentAddress;
  bool get isLocationEnabled => _isLocationEnabled;
  bool get hasPermission => _hasPermission;

  // Check if location is available
  bool get hasCurrentLocation => 
      _currentLatitude != null && _currentLongitude != null;
}

// Location result model
class LocationResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String message;

  LocationResult({
    required this.success,
    this.latitude,
    this.longitude,
    this.address,
    required this.message,
  });

  @override
  String toString() {
    return 'LocationResult(success: $success, lat: $latitude, lon: $longitude, message: $message)';
  }
}

// Location coordinates model
class LocationCoordinates {
  final double latitude;
  final double longitude;

  LocationCoordinates(this.latitude, this.longitude);

  @override
  String toString() {
    return 'LocationCoordinates(lat: $latitude, lon: $longitude)';
  }
}

// Nearby user model
class NearbyUser {
  final String userId;
  final double latitude;
  final double longitude;
  final double distance;
  final DateTime lastSeen;

  NearbyUser({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.lastSeen,
  });

  @override
  String toString() {
    return 'NearbyUser(userId: $userId, distance: ${distance.toStringAsFixed(1)}km)';
  }
}

// Permission status enum
enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  whileInUse,
  always,
  unableToDetermine,
}