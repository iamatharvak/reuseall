import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../models/pickup.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import 'navigation_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  
  final Completer<GoogleMapController> _mapController = Completer();
  
  
  final MapService _mapService = MapService();
  
  
  LatLng? _currentLocation;
  
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  
  bool _isMapLoading = true;
  bool _isRouteLoading = false;
  
  
  Pickup? _selectedPickup;
  
  
  String? _mapStyle;
  
  // Sample data for pickups and warehouse
  // In a real app, this would come from an API
  final List<Pickup> _pickups = [
    Pickup(
      id: 1,
      location: const LatLng(12.971598, 77.594566),
      timeSlot: "9AM-10AM",
      inventory: 5,
    ),
    Pickup(
      id: 2,
      location: const LatLng(12.972819, 77.595212),
      timeSlot: "9AM-10AM",
      inventory: 3,
    ),
    Pickup(
      id: 3,
      location: const LatLng(12.963842, 77.609043),
      timeSlot: "10AM-11AM",
      inventory: 7,
    ),
  ];
  
  final LatLng _warehouseLocation = const LatLng(12.961115, 77.600000);
  
  
  bool get _allPickupsCompleted => _pickups.every((pickup) => pickup.isCompleted);
  
  
  String _routeStats = "Calculating...";
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMapStyle();
    _initializeMap();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh map when app is resumed
      _refreshMap();
    }
  }
  
  
  Future<void> _loadMapStyle() async {
    try {
      // In a real app, we would have a map_style.json in your assets
      
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
    } catch (e) {
      print("Error loading map style: $e");
    }
  }
  
  
  Future<void> _initializeMap() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    
  
    bool locationInitialized = await locationService.initialize();
    
    if (locationInitialized) {
      
      _currentLocation = locationService.currentLocation;
      
      if (_currentLocation != null) {
        
        _updateMapMarkers();
        
        
        await _generateRoute();
        
        
        locationService.locationStream.listen((location) {
          setState(() {
            _currentLocation = location;
            _updateMapMarkers();
          });
        });
      }
    }
    
    setState(() {
      _isMapLoading = false;
    });
  }
  
  
  void _updateMapMarkers() {
    if (_currentLocation != null) {
      setState(() {
        _markers = _mapService.createMarkers(
          riderLocation: _currentLocation!,
          pickups: _pickups,
          warehouseLocation: _warehouseLocation,
          onMarkerTap: _onMarkerTap,
        );
      });
    }
  }
  
  
  void _onMarkerTap(MarkerId markerId) {
  if (markerId.value.startsWith('pickup_')) {
    int id = int.parse(markerId.value.split('_')[1]);
    setState(() {
      _selectedPickup = _pickups.firstWhere((pickup) => pickup.id == id);
    });

    
    _showPickupDetailsSheet(_selectedPickup!);
  }
}

  

  Future<void> _generateRoute() async {
    if (_currentLocation != null) {
      setState(() {
        _isRouteLoading = true;
      });
      
      try {
        final polylines = await _mapService.createRoutePolyline(
          riderLocation: _currentLocation!,
          pickups: _pickups,
          warehouseLocation: _warehouseLocation,
        );
        
        
        final stats = await _mapService.calculateRouteStats(
          riderLocation: _currentLocation!,
          pickups: _pickups,
          warehouseLocation: _warehouseLocation,
        );
        
        setState(() {
          _polylines = polylines;
          _routeStats = stats;
          _isRouteLoading = false;
        });
      } catch (e) {
        setState(() {
          _isRouteLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  
  Future<void> _refreshMap() async {
    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      if (_mapStyle != null) {
        await controller.setMapStyle(_mapStyle);
      }
    }
    
    _updateMapMarkers();
    await _generateRoute();
  }
  
  
  void _navigateToPickup(Pickup pickup) async {
    
    Navigator.pop(context);
    
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          origin: _currentLocation!,
          destination: pickup.location,
          title: 'Pickup #${pickup.id}',
        ),
      ),
    );
  }
  
  
  void _launchExternalNavigation() async {
    
    LatLng destination;
    String label;
    
    
    final nextPickup = _pickups.firstWhere(
      (pickup) => !pickup.isCompleted,
      orElse: () => _pickups.first,
    );
    
    if (_allPickupsCompleted) {
      
      destination = _warehouseLocation;
      label = 'ReuseAll Warehouse';
    } else {
      
      destination = nextPickup.location;
      label = 'Pickup #${nextPickup.id}';
    }
    
    
    try {
      final success = await MapsLauncher.launchCoordinates(
        destination.latitude,
        destination.longitude,
        label
      );
      
      if (!success) {
        _fallbackNavigation(destination);
      }
    } catch (e) {
      _fallbackNavigation(destination);
    }
  }
  
  
  void _fallbackNavigation(LatLng destination) async {
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}';
    
    try {
      await launchUrl(Uri.parse(googleMapsUrl));
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not launch navigation. Please ensure Google Maps is installed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  
  void _markPickupCompleted(Pickup pickup) {
    setState(() {
      final index = _pickups.indexWhere((p) => p.id == pickup.id);
      if (index != -1) {
        final updatedPickup = Pickup(
          id: pickup.id,
          location: pickup.location,
          timeSlot: pickup.timeSlot,
          inventory: pickup.inventory,
          isCompleted: true,
        );
        
        _pickups[index] = updatedPickup;
        _selectedPickup = updatedPickup;
      }
    });
    
    
    _updateMapMarkers();
    _generateRoute();
    
    
    Navigator.pop(context);
    
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pickup #${pickup.id} marked as completed'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  
  void _showPickupDetailsSheet(Pickup pickup) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pickup #${pickup.id}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text('Time Slot'),
              subtitle: Text(pickup.timeSlot),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: Text('Items to Collect'),
              subtitle: Text('${pickup.inventory} items'),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: Text('Location'),
              subtitle: Text('${pickup.location.latitude}, ${pickup.location.longitude}'),
              dense: true,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToPickup(pickup),
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickup.isCompleted 
                        ? null 
                        : () => _markPickupCompleted(pickup),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pickup.isCompleted 
                          ? Colors.grey 
                          : Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReuseAll Route'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMap,
            tooltip: 'Refresh Route',
          ),
        ],
      ),
      body: _isMapLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation ?? const LatLng(12.9716, 77.5946), // Default to Bangalore
                    zoom: 15,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false, // We'll add our own button
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  onMapCreated: (controller) {
                    _mapController.complete(controller);
                    if (_mapStyle != null) {
                      controller.setMapStyle(_mapStyle);
                    }
                  },
                ),
                
                
                if (_isRouteLoading)
                  const Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Card(
                        color: Colors.white70,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Generating route...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                
                
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      
                      FloatingActionButton.small(
                        onPressed: () async {
                          if (_currentLocation != null && _mapController.isCompleted) {
                            final controller = await _mapController.future;
                            controller.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                _currentLocation!,
                                16,
                              ),
                            );
                          }
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.my_location, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      
                      FloatingActionButton.small(
                        onPressed: () async {
                          if (_mapController.isCompleted) {
                            final controller = await _mapController.future;
                            controller.animateCamera(CameraUpdate.zoomIn());
                          }
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.add, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      
                      FloatingActionButton.small(
                        onPressed: () async {
                          if (_mapController.isCompleted) {
                            final controller = await _mapController.future;
                            controller.animateCamera(CameraUpdate.zoomOut());
                          }
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.remove, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                
                
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Route Summary',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on, color: Colors.green),
                              Text(
                                ' ${_pickups.where((p) => !p.isCompleted).length} Pickups remaining',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.schedule, color: Colors.blue),
                              Text(
                                ' $_routeStats',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _pickups.length + 1, // +1 for warehouse
                              itemBuilder: (context, index) {
                                if (index < _pickups.length) {
                                  // Pickup cards
                                  final pickup = _pickups[index];
                                  return GestureDetector(
                                    onTap: () => _showPickupDetailsSheet(pickup),
                                    child: Container(
                                      width: 150,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: pickup.isCompleted
                                            ? Colors.grey.shade200
                                            : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: pickup.isCompleted
                                              ? Colors.grey
                                              : Colors.green,
                                          width: 1,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Pickup #${pickup.id}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: pickup.isCompleted
                                                      ? Colors.grey
                                                      : Colors.black,
                                                ),
                                              ),
                                              if (pickup.isCompleted)
                                                const Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 18,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            pickup.timeSlot,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: pickup.isCompleted
                                                  ? Colors.grey
                                                  : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${pickup.inventory} items',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: pickup.isCompleted
                                                  ? Colors.grey
                                                  : Colors.black87,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (!pickup.isCompleted)
                                            Text(
                                              'Tap for details',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  
                                  return Container(
                                    width: 150,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue,
                                        width: 1,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Warehouse',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Final Destination',
                                          style: TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'After all pickups',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    
                                    final nextPickup = _pickups.firstWhere(
                                      (pickup) => !pickup.isCompleted,
                                      orElse: () => _pickups.first,
                                    );
                                    
                                    if (_allPickupsCompleted) {
                                     
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => NavigationScreen(
                                            origin: _currentLocation!,
                                            destination: _warehouseLocation,
                                            title: 'Warehouse',
                                          ),
                                        ),
                                      );
                                    } else {
                                      
                                      _navigateToPickup(nextPickup);
                                    }
                                  },
                                  icon: const Icon(Icons.navigation),
                                  label: const Text('Navigate'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              OutlinedButton.icon(
                                onPressed: _launchExternalNavigation,
                                icon: const Icon(Icons.map),
                                label: const Text('Google Maps'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}


extension CompletablePickup on Pickup {
  bool get isCompleted => false; 
}