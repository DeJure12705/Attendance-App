import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

// Location picker for event geofencing.
// Lets a user tap on the map to set center (lat/lng) and adjust a
// circular radius. Returns the selection back to the caller via
// Navigator.pop({...}). Useful for configuring Events' location constraints.
class LocationPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double initialRadius;

  const LocationPickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.initialRadius,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late double _lat;
  late double _lng;
  late double _radius;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Seed local state with initial values provided by the caller.
    _lat = widget.initialLat;
    _lng = widget.initialLng;
    _radius = widget.initialRadius;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Title and a confirmation action to return the selection.
        title: const Text('Set Event Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // Send the picked values back to the previous screen.
              Navigator.pop(context, {
                'lat': _lat,
                'lng': _lng,
                'radius': _radius,
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                // Start the camera at the provided center.
                initialCenter: latlng.LatLng(_lat, _lng),
                initialZoom: 15.0,
                // Update center when the user taps the map.
                onTap: (tapPosition, point) {
                  setState(() {
                    _lat = point.latitude;
                    _lng = point.longitude;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.attendanceapp',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40,
                      height: 40,
                      point: latlng.LatLng(_lat, _lng),
                      // Visual pin to indicate the current center.
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: latlng.LatLng(_lat, _lng),
                      // Radius is in meters; used to visualize the geofence.
                      radius: _radius,
                      color: Colors.blue.withOpacity(0.3),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Display the currently selected coordinates, formatted.
                Text('Latitude: ${_lat.toStringAsFixed(6)}'),
                Text('Longitude: ${_lng.toStringAsFixed(6)}'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Radius (m): '),
                    Expanded(
                      child: Slider(
                        // Adjust the geofence radius between 10m and 1000m.
                        value: _radius,
                        min: 10,
                        max: 1000,
                        divisions: 99,
                        label: _radius.round().toString(),
                        onChanged: (value) {
                          setState(() {
                            _radius = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Helper text echoing the selected radius.
                Text('Radius: ${_radius.round()} meters'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
