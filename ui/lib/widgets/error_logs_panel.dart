import 'package:flutter/material.dart';
import '../services/api_error_handler.dart';

/// Widget that displays error logs from the ApiErrorHandler
class ErrorLogsPanel extends StatefulWidget {
  const ErrorLogsPanel({super.key});

  @override
  State<ErrorLogsPanel> createState() => _ErrorLogsPanelState();
}

class _ErrorLogsPanelState extends State<ErrorLogsPanel> {
  List<Map<String, dynamic>> _logs = [];
  
  @override
  void initState() {
    super.initState();
    _loadLogs();
  }
  
  void _loadLogs() {
    setState(() {
      _logs = ApiErrorHandler.getErrorLogs();
    });
  }
  
  Color _getLevelColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      case 'INFO':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline),
                const SizedBox(width: 8),
                Text(
                  'Error Logs',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  onPressed: _loadLogs,
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                  onPressed: () {
                    ApiErrorHandler.clearErrorLog();
                    _loadLogs();
                  },
                ),
              ],
            ),
            const Divider(),
            _logs.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No logs available'),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final level = log['level'] as String;
                        final message = log['message'] as String;
                        final timestamp = log['timestamp'] as String;
                        final error = log['error'] as String?;
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getLevelColor(level),
                            foregroundColor: Colors.white,
                            child: Text(level[0]),
                          ),
                          title: Text(message),
                          subtitle: Text(
                            '${timestamp.substring(0, 19)} ${error != null ? '• $error' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          isThreeLine: error != null,
                          dense: true,
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
} 