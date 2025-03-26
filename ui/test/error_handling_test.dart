import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:davinci3_wiki_ui/services/api_error_handler.dart';

void main() {
  group('ApiErrorHandler', () {
    test('getErrorMessage returns appropriate message for different error types', () {
      expect(
        ApiErrorHandler.getErrorMessage(Exception('Custom error')),
        'Custom error',
      );
      
      expect(
        ApiErrorHandler.getErrorMessage(http.ClientException('Connection failed')),
        'Connection error. Please try again.',
      );
      
      expect(
        ApiErrorHandler.getErrorMessage(FormatException('Invalid format')),
        'Received invalid data from server.',
      );
    });
    
    test('logError properly logs errors and maintains log size', () {
      // Clear any existing logs
      ApiErrorHandler.clearErrorLog();
      
      // Add more than MAX_ERROR_LOG_SIZE logs to test size limit
      for (int i = 0; i < ApiErrorHandler.MAX_ERROR_LOG_SIZE + 10; i++) {
        ApiErrorHandler.logError(
          'Test error $i',
          showToast: false, // Disable toast for testing
        );
      }
      
      final logs = ApiErrorHandler.getErrorLogs();
      
      // Verify log size is limited
      expect(logs.length, ApiErrorHandler.MAX_ERROR_LOG_SIZE);
      
      // Verify most recent logs are at the beginning (due to reversed order)
      expect(logs.first['message'], 'Test error ${ApiErrorHandler.MAX_ERROR_LOG_SIZE + 9}');
      expect(logs.last['message'], 'Test error 10');
      
      // Verify log fields
      final log = logs.first;
      expect(log.containsKey('timestamp'), true);
      expect(log.containsKey('level'), true);
      expect(log.containsKey('message'), true);
      expect(log['level'], 'ERROR');
    });
    
    test('_tryParseErrorDetails extracts error messages from various JSON formats', () {
      // Test with 'message' field
      final jsonWithMessage = json.encode({'message': 'Error occurred'});
      expect(
        ApiErrorHandler.tryParseErrorDetails(jsonWithMessage),
        'Error occurred',
      );
      
      // Test with 'error' field as string
      final jsonWithErrorString = json.encode({'error': 'Error string'});
      expect(
        ApiErrorHandler.tryParseErrorDetails(jsonWithErrorString),
        'Error string',
      );
      
      // Test with 'error' field as object with 'message'
      final jsonWithErrorObject = json.encode({
        'error': {'message': 'Error in object'}
      });
      expect(
        ApiErrorHandler.tryParseErrorDetails(jsonWithErrorObject),
        'Error in object',
      );
      
      // Test with invalid JSON
      expect(
        ApiErrorHandler.tryParseErrorDetails('Not JSON'),
        null,
      );
    });
  });
} 