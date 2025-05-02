import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:permission_handler/permission_handler.dart';

class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Stream controller for location updates
  final _locationController = StreamController<LatLng>.broadcast();
  Stream<LatLng> get locationStream => _locationController.stream;

  // Current location
  LatLng? _currentLocation;
  LatLng? get currentLocation => _currentLocation;

  // StreamSubscription for location updates
  StreamSubscription<Position>? _positionSubscription;

  // Initialize the location service
  Future<bool> initialize() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled
      return false;
    }

    // Check for location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      return false;
    }

    // Get the current position
    try {
      Position position = await Geolocator.getCurrentPosition();
      _updatePosition(position);
      
      // Start listening for position updates
      _startLocationUpdates();
      return true;
    } catch (e) {
      print("Error getting current location: $e");
      return false;
    }
  }

  // Start listening for location updates
  void _startLocationUpdates() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen(_updatePosition);
  }

  // Update the current position
  void _updatePosition(Position position) {
    _currentLocation = LatLng(position.latitude, position.longitude);
    _locationController.add(_currentLocation!);
  }

  // Get the current location once
  Future<LatLng?> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print("Error getting current location: $e");
      return null;
    }
  }

  // Dispose resources
  void dispose() {
    _positionSubscription?.cancel();
    _locationController.close();
  }
}