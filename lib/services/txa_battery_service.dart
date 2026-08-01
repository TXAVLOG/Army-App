import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';

class TXABatteryService extends ChangeNotifier {
  static final TXABatteryService instance = TXABatteryService._internal();
  TXABatteryService._internal();

  final Battery _battery = Battery();
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.unknown;
  Timer? _timer;
  StreamSubscription<BatteryState>? _stateSubscription;

  int get batteryLevel => _batteryLevel;
  BatteryState get batteryState => _batteryState;

  bool get isBatteryCritical {
    // Chỉ áp dụng trên thiết bị Android và iOS
    if (kIsWeb) return false;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return false;
      }
    } catch (_) {
      return false;
    }

    return _batteryLevel <= 5 && _batteryState != BatteryState.charging;
  }

  Future<void> init() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
    } catch (e) {
      debugPrint('Error getting battery status: $e');
    }

    _stateSubscription?.cancel();
    _stateSubscription = _battery.onBatteryStateChanged.listen((state) {
      _batteryState = state;
      _updateStatus();
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkLevel();
    });

    notifyListeners();
  }

  Future<void> _checkLevel() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (level != _batteryLevel || state != _batteryState) {
        _batteryLevel = level;
        _batteryState = state;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking battery level: $e');
    }
  }

  void _updateStatus() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }
}
