import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService instance = LocationService._init();
  LocationService._init();

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<bool> checkAndRequestPermission() async {
    if (!isSupported) {
      // ignore: avoid_print
      print('Geolocalização não suportada neste dispositivo/target');
      return false;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // ignore: avoid_print
      print('Serviço de localização desabilitado');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // ignore: avoid_print
        print('Permissão negada');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // ignore: avoid_print
      print('Permissão negada permanentemente');
      return false;
    }

    // ignore: avoid_print
    print('Permissão de localização concedida');
    return true;
    }

  Future<Position?> getCurrentLocation() async {
    if (!isSupported) {
      // ignore: avoid_print
      print('Geolocalização não suportada neste dispositivo/target');
      return null;
    }
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } on MissingPluginException {
      // ignore: avoid_print
      print('Recurso de localização indisponível neste dispositivo/target');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao obter localização: $e');
      return null;
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  String formatCoordinates(double lat, double lon) {
    return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
  }

  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  // GEOCODING
  Future<String?> getAddressFromCoordinates(double lat, double lon) async {
    if (!isSupported) {
      // ignore: avoid_print
      print('Geocoding não suportado neste dispositivo/target');
      return null;
    }
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].where((p) => p != null && p.isNotEmpty).take(3);
        return parts.join(', ');
      }
    } on MissingPluginException {
      // ignore: avoid_print
      print('Geocoding indisponível neste dispositivo/target');
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao obter endereço: $e');
    }
    return null;
  }

  Future<Position?> getLocationFromAddress(String address) async {
    if (!isSupported) {
      // ignore: avoid_print
      print('Geocoding não suportado neste dispositivo/target');
      return null;
    }
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
    } on MissingPluginException {
      // ignore: avoid_print
      print('Geocoding indisponível neste dispositivo/target');
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao buscar endereço: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCurrentLocationWithAddress() async {
    try {
      final position = await getCurrentLocation();
      if (position == null) return null;
      final address = await getAddressFromCoordinates(position.latitude, position.longitude);
      return {
        'position': position,
        'address': address ?? 'Endereço não disponível',
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      // ignore: avoid_print
      print('Erro: $e');
      return null;
    }
  }
}
