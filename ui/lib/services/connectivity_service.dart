import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Service that monitors network connectivity status
class ConnectivityService {
  // Connectivity instance to monitor network status
  final Connectivity _connectivity = Connectivity();
  
  // Stream controller to broadcast connectivity status
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  
  // Status getters
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  
  // Stream of connectivity status (true = connected, false = disconnected)
  Stream<bool> get onConnectivityChanged => _connectionStatusController.stream;

  Timer? _periodicCheck;

  ConnectivityService() {
    // Initialize
    _initConnectivity();
    
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    
    // Set up periodic connectivity check
    _periodicCheck = Timer.periodic(const Duration(minutes: 2), (_) {
      checkConnectivity();
    });
  }

  /// Initialize connectivity state
  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      await _updateConnectionStatus(result);
    } catch (e) {
      print('Connectivity initialization error: $e');
      _connectionStatusController.add(false);
      _isConnected = false;
    }
  }

  /// Update connection status based on connectivity result
  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      _isConnected = false;
      _connectionStatusController.add(false);
      return;
    }
    
    // Verify actual internet connectivity by making a request
    final hasInternet = await _checkInternetAccess();
    _isConnected = hasInternet;
    _connectionStatusController.add(hasInternet);
  }

  /// Check internet access by making a request to a reliable endpoint
  Future<bool> _checkInternetAccess() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.google.com'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Internet access check failed: $e');
      return false;
    }
  }

  /// Public method to check connectivity
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      
      if (result == ConnectivityResult.none) {
        _isConnected = false;
        _connectionStatusController.add(false);
        return false;
      }
      
      final hasInternet = await _checkInternetAccess();
      _isConnected = hasInternet;
      _connectionStatusController.add(hasInternet);
      return hasInternet;
    } catch (e) {
      print('Connectivity check error: $e');
      _isConnected = false;
      _connectionStatusController.add(false);
      return false;
    }
  }

  /// Dispose of resources
  void dispose() {
    _connectionStatusController.close();
    _periodicCheck?.cancel();
  }
} 