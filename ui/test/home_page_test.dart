import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:davinci3_wiki/main.dart';
import 'package:davinci3_wiki/providers/connectivity_provider.dart';
import 'package:davinci3_wiki/services/connectivity_service.dart';
import 'package:davinci3_wiki/services/wiki_service.dart';
import 'package:davinci3_wiki/services/cache_service.dart';
import 'package:davinci3_wiki/services/search_history_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks for our services
@GenerateMocks([ConnectivityService, WikiService, CacheService, SearchHistoryService])
import 'home_page_test.mocks.dart';

void main() {
  late MockConnectivityService mockConnectivityService;
  late MockWikiService mockWikiService;
  late MockCacheService mockCacheService;
  late MockSearchHistoryService mockSearchHistoryService;
  late ConnectivityProvider connectivityProvider;

  setUp(() {
    mockConnectivityService = MockConnectivityService();
    mockWikiService = MockWikiService();
    mockCacheService = MockCacheService();
    mockSearchHistoryService = MockSearchHistoryService();
    connectivityProvider = ConnectivityProvider(mockConnectivityService);
    
    // Set up default behavior for mocks
    when(mockConnectivityService.isConnected).thenReturn(true);
  });

  Widget createHomePageWithMocks() {
    return MultiProvider(
      providers: [
        Provider<CacheService>.value(value: mockCacheService),
        Provider<WikiService>.value(value: mockWikiService),
        Provider<ConnectivityService>.value(value: mockConnectivityService),
        Provider<SearchHistoryService>.value(value: mockSearchHistoryService),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivityProvider),
      ],
      child: MaterialApp(
        home: HomePage(),
      ),
    );
  }

  testWidgets('HomePage should display navigation rail with three destinations', 
      (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createHomePageWithMocks());

    // Verify that the navigation rail is displayed
    expect(find.byType(NavigationRail), findsOneWidget);
    
    // Verify that there are three navigation destinations
    expect(find.byType(NavigationRailDestination), findsNWidgets(3));
    
    // Verify the labels of the destinations
    expect(find.text('Articles'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('HomePage should switch between pages when navigation rail items are selected', 
      (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createHomePageWithMocks());

    // Initially, the Articles page should be selected (index 0)
    expect(find.text('Articles Page'), findsOneWidget);
    
    // Tap on the Search destination (index 1)
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    
    // Now the Search page should be visible
    expect(find.text('Search Page'), findsOneWidget);
    expect(find.text('Articles Page'), findsNothing);
    
    // Tap on the Settings destination (index 2)
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    
    // Now the Settings page should be visible
    expect(find.text('Settings Page'), findsOneWidget);
    expect(find.text('Search Page'), findsNothing);
    
    // Go back to Articles
    await tester.tap(find.byIcon(Icons.article));
    await tester.pumpAndSettle();
    
    // Articles page should be visible again
    expect(find.text('Articles Page'), findsOneWidget);
    expect(find.text('Settings Page'), findsNothing);
  });

  testWidgets('HomePage should display connectivity status indicator', 
      (WidgetTester tester) async {
    // Set up the mock to return connected status
    when(mockConnectivityService.isConnected).thenReturn(true);
    connectivityProvider.update(mockConnectivityService);
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createHomePageWithMocks());
    
    // Verify that the connected icon is displayed
    expect(find.byIcon(Icons.wifi), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsNothing);
    
    // Change to disconnected status
    when(mockConnectivityService.isConnected).thenReturn(false);
    connectivityProvider.update(mockConnectivityService);
    await tester.pump();
    
    // Verify that the disconnected icon is displayed
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.byIcon(Icons.wifi), findsNothing);
    
    // Verify that the offline message is displayed
    expect(find.text('You are offline. Some features may be limited.'), findsOneWidget);
  });
} 