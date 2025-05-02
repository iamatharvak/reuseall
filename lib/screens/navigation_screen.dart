import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:url_launcher/url_launcher.dart';

import '../services/location_service.dart';

class NavigationScreen extends StatefulWidget {
  final LatLng origin;
  final LatLng destination;
  final String title;

  const NavigationScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.title,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  // Controller for Google Map
  final Completer<GoogleMapController> _mapController = Completer();
  
  // Current location
  LatLng? _currentLocation;
  
  // Markers and polylines
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  // Map loading state
  bool _isLoading = true;
  
  // Navigation instructions
  List<String> _instructions = [];
  int _currentStepIndex = 0;
  
 
  String _distance = "Calculating...";
  String _duration = "Calculating...";
  
  
  String _arrivalTime = "Calculating...";
  
  
  double _progress = 0.0;
  
  
  final String _apiKey = "YOUR_GOOGLE_MAPS_API_KEY";
  
  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }
  
  
  Future<void> _initializeNavigation() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    
    
    bool locationInitialized = await locationService.initialize();
    
    if (locationInitialized) {
      // Get current location
      _currentLocation = locationService.currentLocation ?? widget.origin;
      
      
      _updateMarkers();
      
      
      await _generateRoute();
      
      
      locationService.locationStream.listen((location) {
        setState(() {
          _currentLocation = location;
          _updateMarkers();
          _updateProgress();
        });
      });
    }
    
    setState(() {
      _isLoading = false;
    });
  }
  
  
  void _updateMarkers() {
    Set<Marker> markers = {};
    
    // Current location marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("current_location"),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: "Current Location"),
        ),
      );
    }
    
   
    markers.add(
      Marker(
        markerId: const MarkerId("destination"),
        position: widget.destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: widget.title),
      ),
    );
    
    setState(() {
      _markers = markers;
    });
  }
  
  
  Future<void> _generateRoute() async {
    try {
      PolylinePoints polylinePoints = PolylinePoints();
      List<LatLng> polylineCoordinates = [];
      
      
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        _apiKey,
        PointLatLng(_currentLocation!.latitude, _currentLocation!.longitude),
        PointLatLng(widget.destination.latitude, widget.destination.longitude),
        travelMode: TravelMode.driving,
      );
      
      // Parse navigation instructions (steps)
      // In a real app, you would parse these from the Directions API
      _parseNavigationInstructions(result);
      
      // Convert points to LatLng coordinates
      if (result.points.isNotEmpty) {
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
      }
      
      // Create the polyline
      Polyline polyline = Polyline(
        polylineId: const PolylineId("navigation_route"),
        color: Colors.blue,
        points: polylineCoordinates,
        width: 5,
      );
      
      setState(() {
        _polylines = {polyline};
        
        // Mock distance and duration (in a real app, get from Directions API)
        _distance = "3.2 km";
        _duration = "8 mins";
        
        // Calculate arrival time
        // final now = DateTime.now
                // Calculate arrival time
        final now = DateTime.now();
        _arrivalTime = "${now.add(const Duration(minutes: 8)).hour}:${now.add(const Duration(minutes: 8)).minute.toString().padLeft(2, '0')}";
      });
    } catch (e) {
      debugPrint("Error generating route: $e");
    }
  }

  // Dummy parser — replace with actual parsing logic if needed
  void _parseNavigationInstructions(PolylineResult result) {
    _instructions = ["Start navigation", "Head towards your destination", "You have arrived"];
  }

  // Update navigation progress
  void _updateProgress() {
    // Example: set a fixed progress for demo purposes
    _progress = 0.5;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation ?? widget.origin,
                      zoom: 14,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: (controller) => _mapController.complete(controller),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text("Distance: $_distance | Duration: $_duration"),
                      Text("Arrival: $_arrivalTime"),
                      LinearProgressIndicator(value: _progress),
                      if (_instructions.isNotEmpty)
                        Text("Step: ${_instructions[_currentStepIndex]}"),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
