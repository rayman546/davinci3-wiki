import 'package:flutter/material.dart';
import '../providers/connectivity_provider.dart';
import 'package:provider/provider.dart';

/// Type of error to display
enum ErrorType {
  /// Network errors (connection failed, timeout, etc.)
  network,
  
  /// Server errors (500 status codes, etc.)
  server,
  
  /// Client errors (404, invalid input, etc.)
  client,
  
  /// Validation errors (incorrect format, etc.)
  validation,
  
  /// Unexpected or unknown errors
  unexpected,
  
  /// Empty data state (no results, etc.)
  emptyData,
  
  /// Offline state (no internet connection)
  offline,
}

/// A reusable widget for displaying errors in a consistent way across the app.
/// 
/// Features:
/// - Different error types with appropriate default icons
/// - Customizable title, message, and actions
/// - Retry functionality with optional callback
/// - Adaptive to different display contexts (full screen, card, inline)
class ErrorDisplayWidget extends StatelessWidget {
  /// The type of error being displayed
  final ErrorType errorType;
  
  /// The error message to display
  final String message;
  
  /// Optional title to display above the message
  final String? title;
  
  /// Custom icon to override the default for the error type
  final IconData? customIcon;
  
  /// Callback function for retry button
  final VoidCallback? onRetry;
  
  /// Display mode for the error
  final ErrorDisplayMode displayMode;
  
  /// Optional second action button
  final Widget? secondaryAction;
  
  /// Whether to show the retry button
  final bool showRetryButton;
  
  /// Whether to automatically check connectivity status to enable/disable retry
  final bool checkConnectivity;
  
  /// Custom retry button text
  final String retryButtonText;

  const ErrorDisplayWidget({
    Key? key,
    required this.errorType,
    required this.message,
    this.title,
    this.customIcon,
    this.onRetry,
    this.displayMode = ErrorDisplayMode.fullScreen,
    this.secondaryAction,
    this.showRetryButton = true,
    this.checkConnectivity = true,
    this.retryButtonText = 'Try Again',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isRetryEnabled = true;
    
    // Check connectivity if needed (for network-dependent operations)
    if (checkConnectivity) {
      final connectivityProvider = Provider.of<ConnectivityProvider>(context);
      isRetryEnabled = connectivityProvider.isConnected && errorType != ErrorType.offline;
    }
    
    // Get appropriate icon
    final icon = customIcon ?? _getIconForErrorType(errorType);
    
    // Get default title if not provided
    final errorTitle = title ?? _getTitleForErrorType(errorType);
    
    // Build widget based on display mode
    switch (displayMode) {
      case ErrorDisplayMode.fullScreen:
        return _buildFullScreenError(
          context, icon, errorTitle, message, isRetryEnabled);
      case ErrorDisplayMode.card:
        return _buildCardError(
          context, icon, errorTitle, message, isRetryEnabled);
      case ErrorDisplayMode.inline:
        return _buildInlineError(
          context, icon, errorTitle, message, isRetryEnabled);
    }
  }
  
  IconData _getIconForErrorType(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.signal_wifi_off;
      case ErrorType.server:
        return Icons.cloud_off;
      case ErrorType.client:
        return Icons.error_outline;
      case ErrorType.validation:
        return Icons.report_problem;
      case ErrorType.unexpected:
        return Icons.warning_amber;
      case ErrorType.emptyData:
        return Icons.search_off;
      case ErrorType.offline:
        return Icons.wifi_off;
    }
  }
  
  String _getTitleForErrorType(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Network Error';
      case ErrorType.server:
        return 'Server Error';
      case ErrorType.client:
        return 'Request Error';
      case ErrorType.validation:
        return 'Validation Error';
      case ErrorType.unexpected:
        return 'Unexpected Error';
      case ErrorType.emptyData:
        return 'No Data Found';
      case ErrorType.offline:
        return 'You\'re Offline';
    }
  }
  
  Widget _buildFullScreenError(
    BuildContext context,
    IconData icon,
    String title,
    String message,
    bool isRetryEnabled,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: _getIconColor(context, errorType),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildActionButtons(context, isRetryEnabled),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCardError(
    BuildContext context,
    IconData icon,
    String title,
    String message,
    bool isRetryEnabled,
  ) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: _getIconColor(context, errorType),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildActionButtons(context, isRetryEnabled),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInlineError(
    BuildContext context,
    IconData icon,
    String title,
    String message,
    bool isRetryEnabled,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: _getIconColor(context, errorType),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (showRetryButton && onRetry != null)
            TextButton(
              onPressed: isRetryEnabled ? onRetry : null,
              child: Text(retryButtonText),
            ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons(BuildContext context, bool isRetryEnabled) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showRetryButton && onRetry != null)
          ElevatedButton(
            onPressed: isRetryEnabled ? onRetry : null,
            child: Text(retryButtonText),
          ),
        if (secondaryAction != null) ...[
          const SizedBox(width: 16),
          secondaryAction!,
        ],
      ],
    );
  }
  
  Color _getIconColor(BuildContext context, ErrorType type) {
    switch (type) {
      case ErrorType.network:
      case ErrorType.server:
      case ErrorType.client:
      case ErrorType.unexpected:
        return Theme.of(context).colorScheme.error;
      case ErrorType.validation:
        return Colors.orange;
      case ErrorType.emptyData:
        return Colors.blue;
      case ErrorType.offline:
        return Colors.grey;
    }
  }
}

/// Display mode for the error widget
enum ErrorDisplayMode {
  /// Full screen error display
  fullScreen,
  
  /// Card-style error display
  card,
  
  /// Inline/row error display
  inline,
} 