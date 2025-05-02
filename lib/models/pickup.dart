import 'package:google_maps_flutter/google_maps_flutter.dart';

class Pickup {
  final bool isCompleted;
  final int id;
  final LatLng location;
  final String timeSlot;
  final int inventory;

  Pickup({
    this.isCompleted = false,
    required this.id,
    required this.location,
    required this.timeSlot,
    required this.inventory,
  });

 
  factory Pickup.fromJson(Map<String, dynamic> json) {
    return Pickup(
      id: json['id'],
      location: LatLng(
        json['location']['latitude'],
        json['location']['longitude'],
      ),
      timeSlot: json['time_slot'],
      inventory: json['inventory'],
    );
  }

  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      'time_slot': timeSlot,
      'inventory': inventory,
    };
  }
}
