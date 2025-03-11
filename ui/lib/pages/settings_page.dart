import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wiki_service.dart';
import '../services/cache_service.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/settings_panel.dart';
import '../widgets/performance_metrics_panel.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  bool _isLoadingMetrics = false;
  String? _message;
  bool _isError = false;
  Map<String, dynamic> _performanceMetrics = {};

  @override
  void initState() {
    super.initState();
    _loadPerformanceMetrics();
  }

  Future<void> _clearCache() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final wikiService = Provider.of<WikiService>(context, listen: false);
      await wikiService.clearCache();
      setState(() {
        _isLoading = false;
        _message = 'Cache cleared successfully';
        _isError = false;
      });
      
      // Refresh metrics after clearing cache
      await _loadPerformanceMetrics();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = 'Error clearing cache: $e';
        _isError = true;
      });
    }
  }
  
  Future<void> _loadPerformanceMetrics() async {
    setState(() {
      _isLoadingMetrics = true;
    });
    
    try {
      final wikiService = Provider.of<WikiService>(context, listen: false);
      final metrics = wikiService.getPerformanceMetrics();
      
      setState(() {
        _performanceMetrics = metrics;
        _isLoadingMetrics = false;
      });
    } catch (e) {
      print('Error loading performance metrics: $e');
      setState(() {
        _isLoadingMetrics = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = context.watch<ConnectivityProvider>().isConnected;
    final cacheSize = context.read<CacheService>().getCacheSize();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsPanel(
              title: 'Cache Management',
              description: 'Manage application cache to free up space. Current cache size: ${cacheSize.toStringAsFixed(2)} MB',
              onClearCache: isConnected ? _clearCache : null,
              isLoading: _isLoading,
            ),
            if (!isConnected)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'You are offline. Some settings are unavailable.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _isError
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Connection',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                title: Text(isConnected ? 'Online' : 'Offline'),
                subtitle: Text(
                  isConnected 
                    ? 'Your device is connected to the internet.' 
                    : 'Your device is not connected to the internet.',
                ),
                trailing: isConnected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                        onPressed: () {
                          Provider.of<ConnectivityProvider>(context, listen: false).checkConnection();
                        },
                        child: const Text('Check Again'),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            PerformanceMetricsPanel(
              metrics: _performanceMetrics,
              onRefresh: _loadPerformanceMetrics,
              isLoading: _isLoadingMetrics,
            ),
            const SizedBox(height: 24),
            if (_performanceMetrics.containsKey('overallCacheStats')) ...[
              Text(
                'Most Accessed Articles',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _buildMostAccessedArticles(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMostAccessedArticles() {
    return FutureBuilder<List<dynamic>>(
      future: Provider.of<WikiService>(context, listen: false).getMostAccessedArticles(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading most accessed articles: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }
        
        final articles = snapshot.data;
        if (articles == null || articles.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No articles accessed yet'),
            ),
          );
        }
        
        return Card(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              return ListTile(
                leading: const Icon(Icons.article),
                title: Text(article.title),
                subtitle: Text('ID: ${article.id}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to article details
                  Navigator.pushNamed(
                    context,
                    '/article',
                    arguments: article.id,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
} 