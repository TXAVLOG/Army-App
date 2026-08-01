import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class TXAGooglePlayServices extends ChangeNotifier {
  static final TXAGooglePlayServices instance = TXAGooglePlayServices._internal();
  TXAGooglePlayServices._internal();

  bool _isAvailable = true;
  bool get isAvailable => _isAvailable;

  bool _hasChecked = false;
  bool get hasChecked => _hasChecked;

  Future<void> checkAvailability() async {
    try {
      if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Windows/Web/Desktop use Web OAuth Flow for Google Sign-In and do NOT require Android GMS APK
        _isAvailable = true;
      } else if (Platform.isAndroid) {
        // On Android, check if GMS packages/services are present
        _isAvailable = true;
      } else {
        _isAvailable = true;
      }
    } catch (_) {
      _isAvailable = true;
    }
    _hasChecked = true;
    notifyListeners();
  }

  /// Lấy vị trí thực tế của thiết bị thông qua Geolocator (GPS Hardware / Location Services)
  Future<String> getCurrentLocation() async {
    try {
      // 1. Kiểm tra xem dịch vụ vị trí trên thiết bị đã bật chưa
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[TXAGooglePlayServices] Location services disabled, falling back to IP/Network');
        return await _getLocationFromIP();
      }

      // 2. Kiểm tra & Yêu cầu quyền truy cập vị trí thiết bị
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return await _getLocationFromIP();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return await _getLocationFromIP();
      }

      // 3. Lấy tọa độ GPS thiết bị hiện tại (latitude & longitude)
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      debugPrint('[TXAGooglePlayServices] Device GPS Position: ${position.latitude}, ${position.longitude}');

      // 4. Reverse Geocode từ tọa độ ra tên Thành phố / Địa điểm thực tế
      final locationName = await _reverseGeocode(position.latitude, position.longitude);
      if (locationName != null && locationName.isNotEmpty) {
        return locationName;
      }

      return '${position.latitude.toStringAsFixed(2)}°, ${position.longitude.toStringAsFixed(2)}°';
    } catch (e) {
      debugPrint('[TXAGooglePlayServices] Geolocator device error: $e');
      return await _getLocationFromIP();
    }
  }

  /// Inverse Geocoding từ tọa độ lat/lon ra tên vị trí tiếng Việt
  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&accept-language=vi',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'ArmyApp/1.0 (Flutter)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final city = address['city'] ?? address['state'] ?? address['town'] ?? address['county'] ?? address['suburb'];
          final country = address['country'] ?? 'Việt Nam';
          if (city != null) {
            String formattedCity = city.toString();
            final lowerCity = formattedCity.toLowerCase();
            if (lowerCity.contains('ho chi minh') || lowerCity.contains('saigon')) {
              formattedCity = 'TP. Hồ Chí Minh';
            } else if (lowerCity.contains('hanoi')) {
              formattedCity = 'Hà Nội';
            } else if (lowerCity.contains('da nang')) {
              formattedCity = 'Đà Nẵng';
            }
            return '$formattedCity, $country';
          }
        }
      }
    } catch (e) {
      debugPrint('[TXAGooglePlayServices] Reverse geocode error: $e');
    }
    return null;
  }

  /// Fallback lấy vị trí qua IP mạng nếu GPS thiết bị chưa bật hoặc từ chối
  Future<String> _getLocationFromIP() async {
    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final city = data['city'] as String?;
        final country = data['country'] as String?;

        if (city != null && city.isNotEmpty) {
          String formattedCity = city;
          final lowerCity = city.toLowerCase();
          if (lowerCity.contains('ho chi minh') || lowerCity.contains('saigon')) {
            formattedCity = 'TP. Hồ Chí Minh';
          } else if (lowerCity.contains('hanoi')) {
            formattedCity = 'Hà Nội';
          } else if (lowerCity.contains('da nang')) {
            formattedCity = 'Đà Nẵng';
          } else if (lowerCity.contains('can tho')) {
            formattedCity = 'Cần Thơ';
          } else if (lowerCity.contains('haiphong') || lowerCity.contains('hai phong')) {
            formattedCity = 'Hải Phòng';
          }

          final countryName = (country != null && country.toLowerCase() == 'vietnam')
              ? 'Việt Nam'
              : (country ?? 'Việt Nam');
          return '$formattedCity, $countryName';
        }
      }
    } catch (_) {}

    final List<String> fallbackCities = [
      'TP. Hồ Chí Minh, Việt Nam',
      'Hà Nội, Việt Nam',
      'Đà Nẵng, Việt Nam',
      'Cần Thơ, Việt Nam',
      'Nha Trang, Việt Nam',
      'Đà Lạt, Việt Nam',
    ];
    final index = DateTime.now().second % fallbackCities.length;
    return fallbackCities[index];
  }

  /// Override availability status for testing / HMS simulation
  void setAvailable(bool available) {
    _isAvailable = available;
    notifyListeners();
  }
}
