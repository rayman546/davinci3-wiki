import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'services/wiki_service.dart';
import 'services/search_history_service.dart';
import 'services/cache_service.dart';
import 'services/connectivity_service.dart';
import 'services/api_error_handler.dart';
import 'providers/connectivity_provider.dart';
import 'pages/articles_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('Davinci3 Wiki');
    setWindowMinSize(const Size(800, 600));
  }

  // Initialize services
  final cacheService = CacheService(
    maxCacheSize: 200, // 200 MB max cache size
    cacheTTL: const Duration(days: 7), // Cache TTL of 7 days
  );
  await cacheService.init();

  final searchHistoryService = SearchHistoryService();
  await searchHistoryService.init();

  final connectivityService = ConnectivityService();

  final wikiService = WikiService(
    baseUrl: 'http://localhost:3000',
    cacheService: cacheService,
    cachePriority: 0.7, // Prioritize cache 70% of the time for better performance
    requestTimeout: const Duration(seconds: 10),
  );

  runApp(
    MultiProvider(
      providers: [
        // Services
        Provider<CacheService>(
          create: (_) => cacheService,
        ),
        ProxyProvider<CacheService, WikiService>(
          update: (_, cacheService, __) => wikiService,
        ),
        Provider<ConnectivityService>(
          create: (_) => connectivityService,
          dispose: (_, service) => service.dispose(),
        ),
        
        // Providers
        ChangeNotifierProxyProvider<ConnectivityService, ConnectivityProvider>(
          create: (_) => ConnectivityProvider(null),
          update: (_, connectivityService, previous) => 
            previous!..update(connectivityService),
        ),
        Provider.value(value: searchHistoryService),
      ],
      child: DavinciWikiApp(),
    ),
  );
}

class DavinciWikiApp extends StatelessWidget {
  const DavinciWikiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Davinci3 Wiki',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isCheckingConnection = false;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ArticlesPage(),
      SearchPage(),
      SettingsPage(),
    ];
    
    // Automatically check connection when the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnection();
    });
  }
  
  Future<void> _checkConnection() async {
    if (_isCheckingConnection) return;
    
    setState(() {
      _isCheckingConnection = true;
    });
    
    try {
      await Provider.of<ConnectivityProvider>(context, listen: false).checkConnection();
    } catch (e) {
      if (mounted) {
        ApiErrorHandler.logError('Connection check failed: $e', showToast: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingConnection = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the connectivity status
    final connectivityProvider = context.watch<ConnectivityProvider>();
    final isConnected = connectivityProvider.isConnected;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Davinci3 Wiki'),
        actions: [
          // Connection status with refresh
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _isCheckingConnection
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : IconButton(
                  icon: Icon(
                    isConnected ? Icons.wifi : Icons.wifi_off,
                    color: isConnected ? Colors.green : Colors.red,
                  ),
                  onPressed: _checkConnection,
                  tooltip: isConnected ? 'Connected' : 'Offline - Tap to check connection',
                ),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.article),
                label: Text('Articles'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search),
                label: Text('Search'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
      // Show a snackbar when connectivity changes
      bottomSheet: isConnected == false 
        ? Container(
            width: double.infinity,
            color: Colors.red.shade700,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'You are offline. Some features may be limited.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: _checkConnection,
                  child: const Text(
                    'Check Connection',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ) 
        : null,
    );
  }
}

);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Settings Page'),
    );
  }
}

 