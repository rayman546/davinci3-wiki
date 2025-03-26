import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import '../widgets/error_display_widget.dart';
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
  group('ErrorDisplayWidget', () {
    testWidgets('displays correct content for network error in fullScreen mode',
        (WidgetTester tester) async {
      bool retryPressed = false;
      
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ErrorDisplayWidget(
            errorType: ErrorType.network,
            message: 'Failed to connect to the server',
            title: 'Connection Error',
            onRetry: () {
              retryPressed = true;
            },
            displayMode: ErrorDisplayMode.fullScreen,
          ),
        ),
      ));

      // Verify content
      expect(find.text('Connection Error'), findsOneWidget);
      expect(find.text('Failed to connect to the server'), findsOneWidget);
      expect(find.byIcon(Icons.signal_wifi_off), findsOneWidget);
      
      // Verify retry button
      expect(find.widgetWithText(ElevatedButton, 'Try Again'), findsOneWidget);
      
      // Tap retry button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Try Again'));
      await tester.pump();
      
      // Verify callback was called
      expect(retryPressed, true);
    });

    testWidgets('displays correct content for offline error in card mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ErrorDisplayWidget(
            errorType: ErrorType.offline,
            message: 'No internet connection available',
            displayMode: ErrorDisplayMode.card,
          ),
        ),
      ));

      // Verify content
      expect(find.text('You\'re Offline'), findsOneWidget);
      expect(find.text('No internet connection available'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      
      // Verify card appearance
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('displays correct content for empty data in inline mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ErrorDisplayWidget(
            errorType: ErrorType.emptyData,
            message: 'No results found',
            displayMode: ErrorDisplayMode.inline,
            showRetryButton: false,
          ),
        ),
      ));

      // Verify content
      expect(find.text('No Data Found'), findsOneWidget);
      expect(find.text('No results found'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
      
      // Verify no retry button when showRetryButton is false
      expect(find.widgetWithText(TextButton, 'Try Again'), findsNothing);
    });

    testWidgets('disables retry button when offline for network errors',
        (WidgetTester tester) async {
      final mockConnectivityProvider = MockConnectivityProvider();
      when(mockConnectivityProvider.isConnected).thenReturn(false);
      
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<ConnectivityProvider>.value(
          value: mockConnectivityProvider,
          child: Scaffold(
            body: ErrorDisplayWidget(
              errorType: ErrorType.network,
              message: 'Connection error',
              onRetry: () {},
              checkConnectivity: true,
            ),
          ),
        ),
      ));

      // Find the disabled button
      final button = find.byType(ElevatedButton);
      expect(button, findsOneWidget);
      
      // Verify button is disabled
      final elevatedButton = tester.widget<ElevatedButton>(button);
      expect(elevatedButton.onPressed, isNull);
    });

    testWidgets('shows custom icon and title when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ErrorDisplayWidget(
            errorType: ErrorType.unexpected,
            message: 'Something went wrong',
            title: 'Custom Error Title',
            customIcon: Icons.sentiment_very_dissatisfied,
          ),
        ),
      ));

      // Verify custom content
      expect(find.text('Custom Error Title'), findsOneWidget);
      expect(find.byIcon(Icons.sentiment_very_dissatisfied), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsNothing); // Default icon shouldn't be used
    });

    testWidgets('renders secondary action when provided',
        (WidgetTester tester) async {
      bool secondaryActionPressed = false;
      
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ErrorDisplayWidget(
            errorType: ErrorType.client,
            message: 'Request failed',
            onRetry: () {},
            secondaryAction: TextButton(
              onPressed: () {
                secondaryActionPressed = true;
              },
              child: const Text('Secondary Action'),
            ),
          ),
        ),
      ));

      // Verify secondary action is shown
      expect(find.text('Secondary Action'), findsOneWidget);
      
      // Tap secondary action
      await tester.tap(find.text('Secondary Action'));
      await tester.pump();
      
      // Verify callback was called
      expect(secondaryActionPressed, true);
    });
  });
} 