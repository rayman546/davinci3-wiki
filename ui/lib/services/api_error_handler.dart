import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../providers/connectivity_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// A centralized error handler for API requests throughout the application.
/// 
/// This class provides utilities for:
/// - Converting errors to user-friendly messages
/// - Handling HTTP responses consistently
/// - Executing API requests with proper error handling
/// - Showing error dialogs and snackbars
class ApiErrorHandler {
  /// Log levels for different error severities
  static const int LOG_LEVEL_INFO = 0;
  static const int LOG_LEVEL_WARNING = 1;
  static const int LOG_LEVEL_ERROR = 2;
  
  /// Maximum number of errors to keep in memory
  static const int MAX_ERROR_LOG_SIZE = 100;
  
  /// In-memory log of recent errors
  static final List<Map<String, dynamic>> _errorLog = [];

  /// Converts an exception into a user-friendly error message
  static String getErrorMessage(dynamic error) {
    if (error is TimeoutException) {
      return 'Request timed out. Please try again later.';
    } else if (error is SocketException) {
      return 'Network error. Please check your connection.';
    } else if (error is http.ClientException) {
      return 'Connection error. Please try again.';
    } else if (error is FormatException || error is JsonDecodingError) {
      return 'Received invalid data from server.';
    } else if (error is Exception) {
      // Extract just the error message without the 'Exception: ' prefix
      String errorString = error.toString();
      if (errorString.startsWith('Exception: ')) {
        return errorString.substring('Exception: '.length);
      }
      return errorString;
    }
    return 'An unexpected error occurred: $error';
  }

  /// Processes an HTTP response and handles common error cases
  /// Returns the parsed JSON body on success
  static Future<T> handleResponse<T>({
    required http.Response response,
    required T Function(dynamic jsonData) onSuccess,
    String? customErrorMessage,
  }) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final jsonData = json.decode(response.body);
        return onSuccess(jsonData);
      } on FormatException catch (_) {
        throw Exception('Invalid response format from server');
      }
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      // Client errors
      final message = customErrorMessage ?? 'Client error';
      final details = tryParseErrorDetails(response.body);
      throw Exception('$message: ${details ?? response.statusCode}');
    } else if (response.statusCode >= 500) {
      // Server errors
      final message = customErrorMessage ?? 'Server error';
      throw Exception('$message: ${response.statusCode}');
    } else {
      throw Exception(customErrorMessage ?? 'Unknown error: ${response.statusCode}');
    }
  }

  /// Helper method to try to parse error details from response
  static String? tryParseErrorDetails(String body) {
    try {
      final jsonData = json.decode(body);
      if (jsonData is Map && jsonData.containsKey('message')) {
        return jsonData['message'] as String?;
      }
      if (jsonData is Map && jsonData.containsKey('error')) {
        if (jsonData['error'] is String) {
          return jsonData['error'] as String;
        } else if (jsonData['error'] is Map && jsonData['error'].containsKey('message')) {
          return jsonData['error']['message'] as String?;
        }
      }
    } catch (_) {
      // Couldn't parse JSON, return null
    }
    return null;
  }

  /// Executes an API call with connectivity check and error handling
  static Future<T> execute<T>({
    required Future<T> Function() apiCall,
    required ConnectivityProvider connectivityProvider,
    required String offlineErrorMessage,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // Check connectivity first
    if (!connectivityProvider.isConnected) {
      throw Exception(offlineErrorMessage);
    }

    try {
      return await apiCall().timeout(timeout);
    } catch (e) {
      // Convert error to user-friendly message
      throw Exception(getErrorMessage(e));
    }
  }

  /// Executes an API call with retries and exponential backoff
  static Future<T> executeWithRetry<T>({
    required Future<T> Function() apiCall,
    required ConnectivityProvider connectivityProvider,
    required String offlineErrorMessage,
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // Check connectivity first
    if (!connectivityProvider.isConnected) {
      throw Exception(offlineErrorMessage);
    }

    int retries = 0;
    Duration delay = initialDelay;
    Exception? lastException;

    while (retries <= maxRetries) {
      try {
        return await apiCall().timeout(timeout);
      } catch (e) {
        lastException = Exception(getErrorMessage(e));
        
        // If we've reached max retries, rethrow the error
        if (retries == maxRetries) {
          throw lastException;
        }
        
        // Check connectivity again before retrying
        if (!connectivityProvider.isConnected) {
          throw Exception(offlineErrorMessage);
        }
        
        // Exponential backoff
        await Future.delayed(delay);
        delay *= 2;
        retries++;
      }
    }

    // This should never be reached, but just in case
    throw lastException ?? Exception('Unknown error during retry');
  }

  /// Shows an error dialog with the given error message
  static Future<void> showErrorDialog(
    BuildContext context, 
    String errorMessage, {
    String title = 'Error',
    String buttonText = 'OK',
  }) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(errorMessage),
          actions: <Widget>[
            TextButton(
              child: Text(buttonText),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Shows an error snackbar with the given error message
  static void showErrorSnackBar(
    BuildContext context, 
    String errorMessage, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final snackBar = SnackBar(
      content: Text(errorMessage),
      backgroundColor: Colors.red,
      duration: duration,
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
  
  /// Logs an error message to console and internal error log
  /// 
  /// Parameters:
  /// - [message]: The error message to log
  /// - [logLevel]: The severity level (LOG_LEVEL_INFO, LOG_LEVEL_WARNING, LOG_LEVEL_ERROR)
  /// - [showToast]: Whether to show a toast message to the user
  /// - [error]: The optional error object that caused this log
  /// - [stackTrace]: The optional stack trace for the error
  static void logError(
    String message, {
    int logLevel = LOG_LEVEL_ERROR,
    bool showToast = true,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    // Create timestamp for the log
    final timestamp = DateTime.now().toIso8601String();
    
    // Format log message with appropriate level prefix
    String levelPrefix;
    switch (logLevel) {
      case LOG_LEVEL_INFO:
        levelPrefix = 'INFO';
        break;
      case LOG_LEVEL_WARNING:
        levelPrefix = 'WARNING';
        break;
      case LOG_LEVEL_ERROR:
      default:
        levelPrefix = 'ERROR';
        break;
    }
    
    // Log to console
    final logMessage = '[$levelPrefix] $timestamp: $message';
    if (logLevel == LOG_LEVEL_ERROR) {
      print('\x1B[31m$logMessage\x1B[0m'); // Red color for errors
      if (error != null) print('\x1B[31mError details: $error\x1B[0m');
      if (stackTrace != null) print('\x1B[31m$stackTrace\x1B[0m');
    } else if (logLevel == LOG_LEVEL_WARNING) {
      print('\x1B[33m$logMessage\x1B[0m'); // Yellow color for warnings
      if (error != null) print('\x1B[33mError details: $error\x1B[0m');
    } else {
      print(logMessage); // Normal color for info
      if (error != null) print('Error details: $error');
    }
    
    // Store in in-memory log
    _errorLog.add({
      'timestamp': timestamp,
      'level': levelPrefix,
      'message': message,
      'error': error?.toString(),
      'stackTrace': stackTrace?.toString(),
    });
    
    // Keep log size under limit
    if (_errorLog.length > MAX_ERROR_LOG_SIZE) {
      _errorLog.removeAt(0);
    }
    
    // Show toast notification if enabled
    if (showToast) {
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 3,
        backgroundColor: logLevel == LOG_LEVEL_ERROR 
          ? Colors.red 
          : (logLevel == LOG_LEVEL_WARNING ? Colors.amber : Colors.grey[700]),
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
    
    // TODO: In production, we could also send logs to a remote logging service
    // or write to a persistent log file
  }
  
  /// Returns the recent error logs
  static List<Map<String, dynamic>> getErrorLogs() {
    return List.from(_errorLog.reversed);
  }
  
  /// Clears the error log
  static void clearErrorLog() {
    _errorLog.clear();
  }
} 