import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/connectivity_service.dart';

/// Provider that manages connectivity state throughout the app
class ConnectivityProvider with ChangeNotifier {
  ConnectivityService? _connectivityService;
  bool _isConnected = true;
  
  ConnectivityProvider(ConnectivityService? connectivityService) {
    _connectivityService = connectivityService;
    _init();
  }
  
  bool get isConnected => _isConnected;
  
  void update(ConnectivityService? connectivityService) {
    if (_connectivityService != connectivityService) {
      _connectivityService = connectivityService;
      _init();
    }
  }
  
  void _init() {
    if (_connectivityService == null) return;
    
    // Set initial state
    _isConnected = _connectivityService!.isConnected;
    
    // Listen for connectivity changes
    _connectivityService!.onConnectivityChanged.listen((isConnected) {
      if (_isConnected != isConnected) {
        _isConnected = isConnected;
        notifyListeners();
      }
    });
  }
  
  Future<void> checkConnection() async {
    if (_connectivityService == null) return;
    
    final isConnected = await _connectivityService!.checkConnectivity();
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      notifyListeners();
    }
  }
} 