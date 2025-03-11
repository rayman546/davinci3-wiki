import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'dart:io';
import 'services/wiki_service.dart';
import 'services/search_history_service.dart';
import 'services/cache_service.dart';
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
  final cacheService = CacheService();
  await cacheService.init();

  final searchHistoryService = SearchHistoryService();
  await searchHistoryService.init();

  final wikiService = WikiService(
    baseUrl: 'http://localhost:8080',
    cacheService: cacheService,
  );

  runApp(DavinciWikiApp(
    wikiService: wikiService,
    searchHistoryService: searchHistoryService,
    cacheService: cacheService,
  ));
}

class DavinciWikiApp extends StatelessWidget {
  final WikiService wikiService;
  final SearchHistoryService searchHistoryService;
  final CacheService cacheService;

  const DavinciWikiApp({
    super.key,
    required this.wikiService,
    required this.searchHistoryService,
    required this.cacheService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Davinci3 Wiki',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
      home: HomePage(
        wikiService: wikiService,
        searchHistoryService: searchHistoryService,
        cacheService: cacheService,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final WikiService wikiService;
  final SearchHistoryService searchHistoryService;
  final CacheService cacheService;

  const HomePage({
    super.key,
    required this.wikiService,
    required this.searchHistoryService,
    required this.cacheService,
  });

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
      ArticlesPage(wikiService: widget.wikiService),
      SearchPage(
        wikiService: widget.wikiService,
        searchHistoryService: widget.searchHistoryService,
      ),
      SettingsPage(
        wikiService: widget.wikiService,
        cacheService: widget.cacheService,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}

class ArticlesPage extends StatelessWidget {
  final WikiService wikiService;

  const ArticlesPage({super.key, required this.wikiService});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Articles Page'),
    );
  }
}

class SearchPage extends StatelessWidget {
  final WikiService wikiService;
  final SearchHistoryService searchHistoryService;

  const SearchPage({
    super.key,
    required this.wikiService,
    required this.searchHistoryService,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Search Page'),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final WikiService wikiService;
  final CacheService cacheService;

  const SettingsPage({
    super.key,
    required this.wikiService,
    required this.cacheService,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Settings Page'),
    );
  }
} 