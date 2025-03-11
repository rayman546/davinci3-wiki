import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:davinci3_wiki_ui/widgets/performance_metrics_panel.dart';
import 'package:davinci3_wiki_ui/services/wiki_service.dart';
import 'package:davinci3_wiki_ui/services/cache_service.dart';
import 'package:davinci3_wiki_ui/providers/connectivity_provider.dart';
import 'package:davinci3_wiki_ui/services/connectivity_service.dart';
import 'package:davinci3_wiki_ui/pages/settings_page.dart';
import 'package:davinci3_wiki_ui/models/article.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks for our services
@GenerateMocks([WikiService, CacheService, ConnectivityService])
import 'performance_metrics_test.mocks.dart';

void main() {
  late MockWikiService mockWikiService;
  late MockCacheService mockCacheService;
  late MockConnectivityService mockConnectivityService;
  late ConnectivityProvider connectivityProvider;

  setUp(() {
    mockWikiService = MockWikiService();
    mockCacheService = MockCacheService();
    mockConnectivityService = MockConnectivityService();
    connectivityProvider = ConnectivityProvider(mockConnectivityService);
    
    // Set up default behavior for mocks
    when(mockConnectivityService.isConnected).thenReturn(true);
    when(mockCacheService.getCacheSize()).thenReturn(25.5);
  });

  // Helper function to create test metrics
  Map<String, dynamic> createTestMetrics({
    double cacheSize = 25.5,
    int itemCount = 120,
    double hitRate = 0.85,
    Map<String, double>? queryTimings,
    Map<String, int>? cacheStats,
  }) {
    return {
      'cacheOverview': {
        'totalCacheSize': cacheSize,
        'itemCount': itemCount,
        'hitRate': hitRate,
      },
      if (queryTimings != null) 'queryTimings': queryTimings,
      if (cacheStats != null) 'overallCacheStats': cacheStats,
    };
  }

  testWidgets('PerformanceMetricsPanel should display cache overview', 
      (WidgetTester tester) async {
    // Create test metrics
    final metrics = createTestMetrics();
    
    // Build our widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PerformanceMetricsPanel(
            metrics: metrics,
            onRefresh: () {},
            isLoading: false,
          ),
        ),
      ),
    );
    
    // Verify that the cache overview is displayed
    expect(find.text('Cache Overview'), findsOneWidget);
    expect(find.text('Total Size'), findsOneWidget);
    expect(find.text('25.5 MB'), findsOneWidget);
    expect(find.text('Item Count'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('Hit Rate'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets('PerformanceMetricsPanel should display query timings when available', 
      (WidgetTester tester) async {
    // Create test metrics with query timings
    final metrics = createTestMetrics(
      queryTimings: {
        'getArticle': 45.2,
        'search': 120.5,
        'semanticSearch': 350.8,
      },
    );
    
    // Build our widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PerformanceMetricsPanel(
            metrics: metrics,
            onRefresh: () {},
            isLoading: false,
          ),
        ),
      ),
    );
    
    // Verify that the query timings are displayed
    expect(find.text('Query Timings'), findsOneWidget);
    expect(find.text('getArticle'), findsOneWidget);
    expect(find.text('45.2 ms'), findsOneWidget);
    expect(find.text('search'), findsOneWidget);
    expect(find.text('120.5 ms'), findsOneWidget);
    expect(find.text('semanticSearch'), findsOneWidget);
    expect(find.text('350.8 ms'), findsOneWidget);
  });

  testWidgets('PerformanceMetricsPanel should display cache statistics when available', 
      (WidgetTester tester) async {
    // Create test metrics with cache statistics
    final metrics = createTestMetrics(
      cacheStats: {
        'hits': 850,
        'misses': 150,
        'totalRequests': 1000,
      },
    );
    
    // Build our widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PerformanceMetricsPanel(
            metrics: metrics,
            onRefresh: () {},
            isLoading: false,
          ),
        ),
      ),
    );
    
    // Verify that the cache statistics are displayed
    expect(find.text('Cache Statistics'), findsOneWidget);
    expect(find.text('Hits'), findsOneWidget);
    expect(find.text('850'), findsOneWidget);
    expect(find.text('Misses'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.text('Total Requests'), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);
  });

  testWidgets('PerformanceMetricsPanel should handle refresh action', 
      (WidgetTester tester) async {
    // Create test metrics
    final metrics = createTestMetrics();
    
    // Create a mock refresh callback
    bool refreshCalled = false;
    void onRefresh() {
      refreshCalled = true;
    }
    
    // Build our widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PerformanceMetricsPanel(
            metrics: metrics,
            onRefresh: onRefresh,
            isLoading: false,
          ),
        ),
      ),
    );
    
    // Tap on the refresh button
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    
    // Verify that the refresh callback was called
    expect(refreshCalled, isTrue);
  });

  testWidgets('PerformanceMetricsPanel should display loading indicator when loading', 
      (WidgetTester tester) async {
    // Create test metrics
    final metrics = createTestMetrics();
    
    // Build our widget with loading state
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PerformanceMetricsPanel(
            metrics: metrics,
            onRefresh: () {},
            isLoading: true,
          ),
        ),
      ),
    );
    
    // Verify that the loading indicator is displayed
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('SettingsPage should display performance metrics', 
      (WidgetTester tester) async {
    // Set up the mock to return performance metrics
    final metrics = createTestMetrics(
      queryTimings: {
        'getArticle': 45.2,
        'search': 120.5,
      },
      cacheStats: {
        'hits': 850,
        'misses': 150,
        'totalRequests': 1000,
      },
    );
    when(mockWikiService.getPerformanceMetrics()).thenReturn(metrics);
    
    // Set up the mock to return most accessed articles
    when(mockWikiService.getMostAccessedArticles(limit: 5))
        .thenAnswer((_) async => [
              Article(
                id: 'article1',
                title: 'Most Popular Article',
                content: 'Content',
                lastModified: DateTime.now(),
                categories: ['Category'],
              ),
            ]);
    
    // Build our app with the SettingsPage
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WikiService>.value(value: mockWikiService),
          Provider<CacheService>.value(value: mockCacheService),
          Provider<ConnectivityService>.value(value: mockConnectivityService),
          ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivityProvider),
        ],
        child: MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );
    
    // Wait for the performance metrics to load
    await tester.pumpAndSettle();
    
    // Verify that the performance metrics panel is displayed
    expect(find.byType(PerformanceMetricsPanel), findsOneWidget);
    
    // Verify that the cache overview is displayed
    expect(find.text('Cache Overview'), findsOneWidget);
    expect(find.text('25.5 MB'), findsOneWidget);
    
    // Verify that the query timings are displayed
    expect(find.text('Query Timings'), findsOneWidget);
    expect(find.text('45.2 ms'), findsOneWidget);
    
    // Verify that the cache statistics are displayed
    expect(find.text('Cache Statistics'), findsOneWidget);
    expect(find.text('850'), findsOneWidget);
    
    // Verify that the most accessed articles section is displayed
    expect(find.text('Most Accessed Articles'), findsOneWidget);
    expect(find.text('Most Popular Article'), findsOneWidget);
  });

  testWidgets('SettingsPage should refresh performance metrics when requested', 
      (WidgetTester tester) async {
    // Set up the mock to return initial performance metrics
    final initialMetrics = createTestMetrics(
      cacheSize: 25.5,
      itemCount: 120,
    );
    when(mockWikiService.getPerformanceMetrics()).thenReturn(initialMetrics);
    
    // Set up the mock to return most accessed articles
    when(mockWikiService.getMostAccessedArticles(limit: 5))
        .thenAnswer((_) async => []);
    
    // Build our app with the SettingsPage
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WikiService>.value(value: mockWikiService),
          Provider<CacheService>.value(value: mockCacheService),
          Provider<ConnectivityService>.value(value: mockConnectivityService),
          ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivityProvider),
        ],
        child: MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );
    
    // Wait for the performance metrics to load
    await tester.pumpAndSettle();
    
    // Verify that the initial metrics are displayed
    expect(find.text('120'), findsOneWidget);
    
    // Change the mock to return updated metrics
    final updatedMetrics = createTestMetrics(
      cacheSize: 30.0,
      itemCount: 150,
    );
    when(mockWikiService.getPerformanceMetrics()).thenReturn(updatedMetrics);
    
    // Tap on the refresh button
    await tester.tap(find.byIcon(Icons.refresh));
    
    // Wait for the metrics to refresh
    await tester.pumpAndSettle();
    
    // Verify that the updated metrics are displayed
    expect(find.text('150'), findsOneWidget);
    
    // Verify that getPerformanceMetrics was called twice
    verify(mockWikiService.getPerformanceMetrics()).called(2);
  });
} 