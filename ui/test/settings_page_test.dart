import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:davinci3_wiki_ui/pages/settings_page.dart';
import 'package:davinci3_wiki_ui/services/wiki_service.dart';
import 'package:davinci3_wiki_ui/services/cache_service.dart';
import 'package:davinci3_wiki_ui/providers/connectivity_provider.dart';
import 'package:davinci3_wiki_ui/services/connectivity_service.dart';
import 'package:davinci3_wiki_ui/widgets/settings_panel.dart';
import 'package:davinci3_wiki_ui/widgets/performance_metrics_panel.dart';
import 'package:davinci3_wiki_ui/models/article.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks for our services
@GenerateMocks([WikiService, CacheService, ConnectivityService])
import 'settings_page_test.mocks.dart';

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
    when(mockCacheService.getCacheSize()).thenReturn(25.5); // 25.5 MB
    
    // Set up performance metrics
    when(mockWikiService.getPerformanceMetrics()).thenReturn({
      'cacheOverview': {
        'totalCacheSize': 25.5,
        'itemCount': 120,
        'hitRate': 0.85,
      },
      'queryTimings': {
        'getArticle': 45.2,
        'search': 120.5,
        'semanticSearch': 350.8,
      },
      'overallCacheStats': {
        'hits': 850,
        'misses': 150,
        'totalRequests': 1000,
      },
    });
    
    // Set up most accessed articles
    when(mockWikiService.getMostAccessedArticles(limit: 5))
        .thenAnswer((_) async => [
              Article(
                id: 'article1',
                title: 'Most Popular Article',
                content: 'Content',
                lastModified: DateTime.now(),
                categories: ['Category'],
              ),
              Article(
                id: 'article2',
                title: 'Second Most Popular',
                content: 'Content',
                lastModified: DateTime.now(),
                categories: ['Category'],
              ),
            ]);
  });

  Widget createSettingsPageWithMocks() {
    return MultiProvider(
      providers: [
        Provider<WikiService>.value(value: mockWikiService),
        Provider<CacheService>.value(value: mockCacheService),
        Provider<ConnectivityService>.value(value: mockConnectivityService),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivityProvider),
      ],
      child: MaterialApp(
        home: SettingsPage(),
      ),
    );
  }

  testWidgets('SettingsPage should display cache management panel', 
      (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createSettingsPageWithMocks());
    
    // Verify that the cache management panel is displayed
    expect(find.text('Cache Management'), findsOneWidget);
    expect(find.text('Manage application cache to free up space. Current cache size: 25.50 MB'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Clear Cache'), findsOneWidget);
  });

  testWidgets('SettingsPage should display connection status', 
      (WidgetTester tester) async {
    // Build our app and trigger a frame with connected status
    when(mockConnectivityService.isConnected).thenReturn(true);
    connectivityProvider.update(mockConnectivityService);
    await tester.pumpWidget(createSettingsPageWithMocks());
    
    // Verify that the connection status is displayed
    expect(find.text('Connection'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Your device is connected to the internet.'), findsOneWidget);
    expect(find.byIcon(Icons.wifi), findsOneWidget);
    
    // Change to disconnected status
    when(mockConnectivityService.isConnected).thenReturn(false);
    connectivityProvider.update(mockConnectivityService);
    await tester.pump();
    
    // Verify that the disconnected status is displayed
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Your device is not connected to the internet.'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Check Again'), findsOneWidget);
    expect(find.text('You are offline. Some settings are unavailable.'), findsOneWidget);
  });

  testWidgets('SettingsPage should display performance metrics panel', 
      (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createSettingsPageWithMocks());
    
    // Wait for the performance metrics to load
    await tester.pumpAndSettle();
    
    // Verify that the performance metrics panel is displayed
    expect(find.byType(PerformanceMetricsPanel), findsOneWidget);
    
    // Verify that the cache overview is displayed
    expect(find.text('Cache Overview'), findsOneWidget);
    expect(find.text('Total Size'), findsOneWidget);
    expect(find.text('25.5 MB'), findsOneWidget);
    
    // Verify that the query timings are displayed
    expect(find.text('Query Timings'), findsOneWidget);
    expect(find.text('getArticle'), findsOneWidget);
    expect(find.text('45.2 ms'), findsOneWidget);
    
    // Verify that the cache stats are displayed
    expect(find.text('Cache Statistics'), findsOneWidget);
    expect(find.text('Hits'), findsOneWidget);
    expect(find.text('850'), findsOneWidget);
  });

  testWidgets('SettingsPage should display most accessed articles', 
      (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createSettingsPageWithMocks());
    
    // Wait for the most accessed articles to load
    await tester.pumpAndSettle();
    
    // Verify that the most accessed articles section is displayed
    expect(find.text('Most Accessed Articles'), findsOneWidget);
    
    // Verify that the articles are displayed
    expect(find.text('Most Popular Article'), findsOneWidget);
    expect(find.text('Second Most Popular'), findsOneWidget);
  });

  testWidgets('SettingsPage should handle clear cache action', 
      (WidgetTester tester) async {
    // Set up the mock to handle clearCache
    when(mockWikiService.clearCache())
        .thenAnswer((_) async => null);
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createSettingsPageWithMocks());
    
    // Tap on the clear cache button
    await tester.tap(find.widgetWithText(ElevatedButton, 'Clear Cache'));
    await tester.pump(); // Start the loading indicator
    
    // Verify that the loading indicator is displayed
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Complete the operation
    await tester.pumpAndSettle();
    
    // Verify that the success message is displayed
    expect(find.text('Cache cleared successfully'), findsOneWidget);
    
    // Verify that clearCache was called
    verify(mockWikiService.clearCache()).called(1);
    
    // Verify that performance metrics were refreshed
    verify(mockWikiService.getPerformanceMetrics()).called(2); // Once on init, once after clearing
  });

  testWidgets('SettingsPage should handle clear cache error', 
      (WidgetTester tester) async {
    // Set up the mock to throw an error
    when(mockWikiService.clearCache())
        .thenThrow(Exception('Failed to clear cache'));
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createSettingsPageWithMocks());
    
    // Tap on the clear cache button
    await tester.tap(find.widgetWithText(ElevatedButton, 'Clear Cache'));
    await tester.pump(); // Start the loading indicator
    
    // Verify that the loading indicator is displayed
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Complete the operation
    await tester.pumpAndSettle();
    
    // Verify that the error message is displayed
    expect(find.text('Error clearing cache: Exception: Failed to clear cache'), findsOneWidget);
  });

  testWidgets('SettingsPage should disable clear cache when offline', 
      (WidgetTester tester) async {
    // Set up the mock to return disconnected status
    when(mockConnectivityService.isConnected).thenReturn(false);
    connectivityProvider.update(mockConnectivityService);
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createSettingsPageWithMocks());
    
    // Get the clear cache button
    final clearCacheButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Clear Cache'),
    );
    
    // Verify that the button is disabled
    expect(clearCacheButton.onPressed, isNull);
    
    // Verify that the offline message is displayed
    expect(find.text('You are offline. Some settings are unavailable.'), findsOneWidget);
  });
} 