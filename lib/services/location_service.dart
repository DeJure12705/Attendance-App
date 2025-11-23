import 'package:location/location.dart';

class LocationService {
  final Location _location = Location();
  bool serviceEnabled = false;
  bool permissionGranted = false;

  Future<bool> initialize() async {
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    var permissionStatus = await _location.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await _location.requestPermission();
      if (permissionStatus != PermissionStatus.granted) return false;
    }
    permissionGranted = permissionStatus == PermissionStatus.granted;
    return serviceEnabled && permissionGranted;
  }

  Future<LocationData?> _safeGet() async {
    if (!serviceEnabled || !permissionGranted) return null;
    try {
      return await _location.getLocation();
    } catch (_) {
      return null;
    }
  }

  Future<double?> getLatitude() async => (await _safeGet())?.latitude;
  Future<double?> getLongitude() async => (await _safeGet())?.longitude;
}
