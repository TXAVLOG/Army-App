import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TXAWeatherData {
  final double temperature;
  final String tempString;
  final String emoji;
  final String label;
  final int weatherCode;
  final bool isDay;
  final DateTime timestamp;

  TXAWeatherData({
    required this.temperature,
    required this.tempString,
    required this.emoji,
    required this.label,
    required this.weatherCode,
    required this.isDay,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'tempString': tempString,
        'emoji': emoji,
        'label': label,
        'weatherCode': weatherCode,
        'isDay': isDay,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TXAWeatherData.fromJson(Map<String, dynamic> json) => TXAWeatherData(
        temperature: (json['temperature'] as num).toDouble(),
        tempString: json['tempString'] ?? '25°C',
        emoji: json['emoji'] ?? '☀️',
        label: json['label'] ?? '25°C ☀️',
        weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
        isDay: json['isDay'] ?? true,
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      );
}

class TXAWeatherService {
  static final TXAWeatherService instance = TXAWeatherService._internal();
  TXAWeatherService._internal();

  TXAWeatherData? _cachedWeather;
  TXAWeatherData? get cachedWeather => _cachedWeather;

  static const String _prefKey = 'txa_cached_weather_json';

  /// Fetch real-time weather from Open-Meteo API using device GPS position.
  /// Caches result for 15 minutes to save bandwidth.
  Future<TXAWeatherData> fetchCurrentWeather({bool forceRefresh = false}) async {
    // 1. Check memory cache (15-minute validity)
    if (!forceRefresh && _cachedWeather != null) {
      final age = DateTime.now().difference(_cachedWeather!.timestamp);
      if (age.inMinutes < 15) {
        return _cachedWeather!;
      }
    }

    // 2. Try SharedPreferences cache
    if (_cachedWeather == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_prefKey);
        if (raw != null && raw.isNotEmpty) {
          _cachedWeather = TXAWeatherData.fromJson(jsonDecode(raw));
          final age = DateTime.now().difference(_cachedWeather!.timestamp);
          if (age.inMinutes < 15 && !forceRefresh) {
            return _cachedWeather!;
          }
        }
      } catch (_) {}
    }

    // 3. Fallback coordinates (Hanoi lat: 21.0285, lon: 105.8542)
    double lat = 21.0285;
    double lon = 105.8542;

    try {
      final hasPermission = await _checkLocationPermission();
      if (hasPermission) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 4),
          ),
        );
        lat = position.latitude;
        lon = position.longitude;
      }
    } catch (e) {
      debugPrint('ℹ️ [TXAWeatherService] Location fetch fallback to default: $e');
    }

    // 4. Fetch from Open-Meteo API (Free, no API key required)
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final currentWeather = data['current_weather'];
        if (currentWeather != null) {
          final temp = (currentWeather['temperature'] as num).toDouble();
          final code = (currentWeather['weathercode'] as num).toInt();
          final isDay = (currentWeather['is_day'] as num?)?.toInt() == 1;

          final emoji = _getWeatherEmoji(code, isDay);
          final tempString = '${temp.round()}°C';
          final label = '$tempString $emoji';

          _cachedWeather = TXAWeatherData(
            temperature: temp,
            tempString: tempString,
            emoji: emoji,
            label: label,
            weatherCode: code,
            isDay: isDay,
            timestamp: DateTime.now(),
          );

          // Save to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKey, jsonEncode(_cachedWeather!.toJson()));

          return _cachedWeather!;
        }
      }
    } catch (e) {
      debugPrint('❌ [TXAWeatherService] API fetch error: $e');
    }

    // Return cached weather or default fallback
    if (_cachedWeather != null) return _cachedWeather!;

    return TXAWeatherData(
      temperature: 25.0,
      tempString: '25°C',
      emoji: '☀️',
      label: '25°C ☀️',
      weatherCode: 0,
      isDay: true,
      timestamp: DateTime.now(),
    );
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  String _getWeatherEmoji(int code, bool isDay) {
    switch (code) {
      case 0:
        return isDay ? '☀️' : '🌙';
      case 1:
      case 2:
      case 3:
        return isDay ? '🌤️' : '☁️';
      case 45:
      case 48:
        return '🌫️';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return '🌧️';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return '❄️';
      case 95:
      case 96:
      case 99:
        return '⛈️';
      default:
        return '🌡️';
    }
  }
}
