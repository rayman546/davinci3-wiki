import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import '../widgets/network_aware_widget.dart';
import '../providers/connectivity_provider.dart';

class MockConnectivityProvider extends Mock implements ConnectivityProvider {
  @override
  bool get isConnected => super.noSuchMethod(
    Invocation.getter(#isConnected),
    returnValue: true,
    returnValueForMissingStub: true,
  );
}

void main() {
  group('NetworkAwareWidget', () {
    testWidgets('shows online content when connected',
        (WidgetTester tester) async {
      final mockConnectivityProvider = MockConnectivityProvider();
      when(mockConnectivityProvider.isConnected).thenReturn(true);
      
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<ConnectivityProvider>.value(
          value: mockConnectivityProvider,
          child: Scaffold(
            body: NetworkAwareWidget(
              onlineChild: const Text('Online Content'),
              offlineChild: const Text('Offline Content'),
            ),
          ),
        ),
      ));

      // Verify online content is shown
      expect(find.text('Online Content'), findsOneWidget);
      expect(find.text('Offline Content'), findsNothing);
    });

    testWidgets('shows offline content when not connected',
        (WidgetTester tester) async {
      final mockConnectivityProvider = MockConnectivityProvider();
      when(mockConnectivityProvider.isConnected).thenReturn(false);
      
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<ConnectivityProvider>.value(
          value: mockConnectivityProvider,
          child: Scaffold(
            body: NetworkAwareWidget(
              onlineChild: const Text('Online Content'),
              offlineChild: const Text('Offline Content'),
            ),
          ),
        ),
      ));

      // Verify offline content is shown
      expect(find.text('Offline Content'), findsOneWidget);
      expect(find.text('Online Content'), findsNothing);
    });

    testWidgets('shows loading state when specified and loading',
        (WidgetTester tester) async {
      final mockConnectivityProvider = MockConnectivityProvider();
      when(mockConnectivityProvider.isConnected).thenReturn(true);
      
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<ConnectivityProvider>.value(
          value: mockConnectivityProvider,
          child: Scaffold(
            body: NetworkAwareWidget(
              onlineChild: const Text('Online Content'),
              offlineChild: const Text('Offline Content'),
              isLoading: true,
              loadingChild: const CircularProgressIndicator(),
            ),
          ),
        ),
      ));

      // Verify loading state is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Online Content'), findsNothing);
      expect(find.text('Offline Content'), findsNothing);
    });

    testWidgets('responds to connectivity changes',
        (WidgetTester tester) async {
      final mockConnectivityProvider = MockConnectivityProvider();
      when(mockConnectivityProvider.isConnected).thenReturn(true);
      
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<ConnectivityProvider>.value(
          value: mockConnectivityProvider,
          child: Scaffold(
            body: NetworkAwareWidget(
              onlineChild: const Text('Online Content'),
              offlineChild: const Text('Offline Content'),
            ),
          ),
        ),
      ));

      // Verify initial state shows online content
      expect(find.text('Online Content'), findsOneWidget);
      expect(find.text('Offline Content'), findsNothing);
      
      // Change connectivity to offline
      when(mockConnectivityProvider.isConnected).thenReturn(false);
      
      // Trigger rebuild to reflect connectivity change
      mockConnectivityProvider.notifyListeners();
      await tester.pump();
      
      // Verify state is updated to show offline content
      expect(find.text('Offline Content'), findsOneWidget);
      expect(find.text('Online Content'), findsNothing);
    });

    testWidgets('shows custom offline message when provided',
        (WidgetTester tester) async {
      final mockConnectivityProvider = MockConnectivityProvider();
      when(mockConnectivityProvider.isConnected).thenReturn(false);
      
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<ConnectivityProvider>.value(
          value: mockConnectivityProvider,
          child: Scaffold(
            body: NetworkAwareWidget(
              onlineChild: const Text('Online Content'),
              offlineMessage: 'Custom Offline Message',
            ),
          ),
        ),
      ));

      // Verify custom offline message is shown
      expect(find.text('Custom Offline Message'), findsOneWidget);
      expect(find.text('Online Content'), findsNothing);
    });

    testWidgets('shows default offline widget when no offline child or message',
        (WidgetTester tester) async {
      final mockConnectivityProvider = MockConnectivityProvider();
      when(mockConnectivityProvider.isConnected).thenReturn(false);
      
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<ConnectivityProvider>.value(
          value: mockConnectivityProvider,
          child: Scaffold(
            body: NetworkAwareWidget(
              onlineChild: const Text('Online Content'),
            ),
          ),
        ),
      ));

      // Verify default offline widget is shown
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.text('You\'re offline'), findsOneWidget);
      expect(find.text('Online Content'), findsNothing);
    });

    testWidgets('handles interaction with retry action when offline',
        (WidgetTester tester) async {
      final mockConnectivityProvider = MockConnectivityProvider();
      when(mockConnectivityProvider.isConnected).thenReturn(false);
      
      bool retryPressed = false;
      
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<ConnectivityProvider>.value(
          value: mockConnectivityProvider,
          child: Scaffold(
            body: NetworkAwareWidget(
              onlineChild: const Text('Online Content'),
              onRetry: () {
                retryPressed = true;
              },
              showRetryButton: true,
            ),
          ),
        ),
      ));

      // Verify retry button is shown
      expect(find.widgetWithText(ElevatedButton, 'Try Again'), findsOneWidget);
      
      // Tap retry button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Try Again'));
      await tester.pump();
      
      // Verify callback was called
      expect(retryPressed, true);
    });
  });
} 