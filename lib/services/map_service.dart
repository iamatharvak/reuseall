import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../models/pickup.dart';

class MapService {
  // API Key for Google Maps Directions API
  // In a real app, store this securely and don't commit to version control
  final String _apiKey = "YOUR_GOOGLE_MAPS_API_KEY";
  
  
  Set<Marker> createMarkers({
    required LatLng riderLocation,
    required List<Pickup> pickups,
    required LatLng warehouseLocation,
    void Function(MarkerId)? onMarkerTap
  }) {
    Set<Marker> markers = {};
    
    
    markers.add(
      Marker(
        markerId: const MarkerId("rider"),
        position: riderLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: "You"),
      ),
    );
    
    // Add pickup markers
    for (var pickup in pickups) {
      markers.add(
        Marker(
          markerId: MarkerId("pickup_${pickup.id}"),
          position: pickup.location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: "Pickup #${pickup.id}",
            snippet: "Time: ${pickup.timeSlot}, Items: ${pickup.inventory}",
          ),
        ),
      );
    }
    
    
    markers.add(
      Marker(
        markerId: const MarkerId("warehouse"),
        position: warehouseLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "Warehouse"),
      ),
    );
    
    return markers;
  }
  
  
  Future<Set<Polyline>> createRoutePolyline({
    required LatLng riderLocation,
    required List<Pickup> pickups,
    required LatLng warehouseLocation,
  }) async {
    Set<Polyline> polylines = {};
    PolylinePoints polylinePoints = PolylinePoints();
    List<LatLng> polylineCoordinates = [];
    
    
    List<PolylineWayPoint> wayPoints = pickups.map((pickup) => 
      PolylineWayPoint(
        location: "${pickup.location.latitude},${pickup.location.longitude}",
        stopOver: true,
      )
    ).toList();
    
    try {
      
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        _apiKey,
        PointLatLng(riderLocation.latitude, riderLocation.longitude),
        PointLatLng(warehouseLocation.latitude, warehouseLocation.longitude),
        wayPoints: wayPoints,
        travelMode: TravelMode.driving,
      );
      
      
      if (result.points.isNotEmpty) {
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
      }
      
      
      Polyline polyline = Polyline(
        polylineId: const PolylineId("route"),
        color: Colors.blue,
        points: polylineCoordinates,
        width: 5,
      );
      
      polylines.add(polyline);
    } catch (e) {
      print("Error creating route polyline: $e");
    }
    
    return polylines;
  }
  
  
  String calculateRouteStats({
    required LatLng riderLocation,
    required List<Pickup> pickups,
    required LatLng warehouseLocation,
  }) {
    // In a real app, you'd call the Google Directions API to get accurate estimates
    // For now, we'll return a mock value
    return "12.5 km • ~25 minutes";
  }
}