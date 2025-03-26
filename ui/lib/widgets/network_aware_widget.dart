import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import 'error_display_widget.dart';

/// Display mode for offline content
enum OfflineDisplayMode {
  /// Full screen offline message
  fullScreen,
  
  /// Inline/banner message
  inline,
  
  /// Small badge indicator
  badge,
}

/// A widget that shows different content based on network connectivity status.
/// 
/// Features:
/// - Shows normal content when online
/// - Displays appropriate offline message when disconnected
/// - Supports different display modes
/// - Configurable appearance and messages
class NetworkAwareWidget extends StatelessWidget {
  /// The main content to display when online
  final Widget onlineContent;
  
  /// Optional custom offline content
  final Widget? offlineContent;
  
  /// Mode to display offline message
  final OfflineDisplayMode offlineMode;
  
  /// Custom offline message
  final String? offlineMessage;
  
  /// Optional action when offline
  final VoidCallback? offlineAction;
  
  /// Text for offline action button
  final String offlineActionText;
  
  /// Whether the widget should enforce connectivity
  /// If true, shows offline content when disconnected
  /// If false, just shows the online content regardless of connectivity status
  /// (Useful for content that can work offline)
  final bool enforceConnectivity;

  const NetworkAwareWidget({
    Key? key,
    required this.onlineContent,
    this.offlineContent,
    this.offlineMode = OfflineDisplayMode.fullScreen,
    this.offlineMessage,
    this.offlineAction,
    this.offlineActionText = 'Retry Connection',
    this.enforceConnectivity = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If not enforcing connectivity, just show the online content
    if (!enforceConnectivity) {
      return onlineContent;
    }
    
    // Use connectivity provider to check network status
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivityProvider, child) {
        final isConnected = connectivityProvider.isConnected;
        
        if (isConnected) {
          return onlineContent;
        } else if (offlineContent != null) {
          return offlineContent!;
        } else {
          switch (offlineMode) {
            case OfflineDisplayMode.fullScreen:
              return _buildFullScreenOffline(context);
            case OfflineDisplayMode.inline:
              return _buildInlineOffline(context);
            case OfflineDisplayMode.badge:
              return _buildBadgeOffline(context);
          }
        }
      },
    );
  }
  
  Widget _buildFullScreenOffline(BuildContext context) {
    return ErrorDisplayWidget(
      errorType: ErrorType.offline,
      message: offlineMessage ?? 'No internet connection available. Please check your network settings and try again.',
      onRetry: offlineAction != null 
          ? () {
              final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
              connectivityProvider.checkConnection();
              offlineAction?.call();
            }
          : null,
      showRetryButton: offlineAction != null,
      retryButtonText: offlineActionText,
      secondaryAction: TextButton(
        onPressed: () {
          final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
          connectivityProvider.checkConnection();
        },
        child: const Text('Check Connection'),
      ),
    );
  }
  
  Widget _buildInlineOffline(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.orange.shade100,
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.orange),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    offlineMessage ?? 'You are currently offline',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
                if (offlineAction != null)
                  TextButton(
                    onPressed: () {
                      final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
                      connectivityProvider.checkConnection();
                      offlineAction?.call();
                    },
                    child: Text(offlineActionText),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.5, 0, 0, 0, 0,
              0, 0.5, 0, 0, 0,
              0, 0, 0.5, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: onlineContent,
          ),
        ),
      ],
    );
  }
  
  Widget _buildBadgeOffline(BuildContext context) {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.5, 0, 0, 0, 0,
            0, 0.5, 0, 0, 0,
            0, 0, 0.5, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: onlineContent,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Offline',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
} 