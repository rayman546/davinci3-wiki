import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'services/wiki_service.dart';
import 'services/search_history_service.dart';
import 'services/cache_service.dart';
import 'services/connectivity_service.dart';
import 'providers/connectivity_provider.dart';
import 'pages/home_page.dart';
import 'pages/articles_page.dart';
import 'pages/article_details_page.dart';
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
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/articles': (context) => const ArticlesPage(),
        '/article': (context) => const ArticleDetailsPage(),
        '/search': (context) => const SearchPage(),
        '/settings': (context) => const SettingsPage(),
      },
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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ArticlesPage(),
      SearchPage(),
      SettingsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Access the connectivity status
    final isConnected = context.watch<ConnectivityProvider>().isConnected;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Davinci3 Wiki'),
        actions: [
          // Connectivity indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: isConnected 
              ? const Icon(Icons.wifi, color: Colors.green)
              : const Icon(Icons.wifi_off, color: Colors.red),
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
            child: const Text(
              'You are offline. Some features may be limited.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ) 
        : null,
    );
  }
}

class ArticlesPage extends StatelessWidget {
  const ArticlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Articles Page'),
    );
  }
}

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Search Page'),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Settings Page'),
    );
  }
} 