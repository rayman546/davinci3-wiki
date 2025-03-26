import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../widgets/loading_state_widget.dart';

void main() {
  group('LoadingStateWidget', () {
    testWidgets('displays circular progress indicator with fullScreen mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoadingStateWidget(
            isLoading: true,
            loadingMode: LoadingMode.fullScreen,
            child: const Text('Content'),
          ),
        ),
      ));

      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Verify child is not shown when loading
      expect(find.text('Content'), findsNothing);
      
      // Verify fullscreen loading appearance
      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('displays skeleton loading when skeleton mode is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoadingStateWidget(
            isLoading: true,
            loadingMode: LoadingMode.skeleton,
            skeletonBuilder: (context) => Column(
              children: [
                Container(height: 20, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Container(height: 20, color: Colors.grey.shade300),
              ],
            ),
            child: const Text('Content'),
          ),
        ),
      ));

      // Verify skeleton is shown
      expect(find.byType(Container), findsNWidgets(2));
      
      // Verify child is not shown when loading
      expect(find.text('Content'), findsNothing);
    });

    testWidgets('shows child when not loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoadingStateWidget(
            isLoading: false,
            loadingMode: LoadingMode.fullScreen,
            child: const Text('Content'),
          ),
        ),
      ));

      // Verify loading indicator is not shown
      expect(find.byType(CircularProgressIndicator), findsNothing);
      
      // Verify child is shown when not loading
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('displays shimmer effect when shimmer mode is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoadingStateWidget(
            isLoading: true,
            loadingMode: LoadingMode.shimmer,
            skeletonBuilder: (context) => Column(
              children: [
                Container(height: 20, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Container(height: 20, color: Colors.grey.shade300),
              ],
            ),
            child: const Text('Content'),
          ),
        ),
      ));

      // Verify shimmer is shown (find shimmer container)
      expect(find.byType(Container), findsNWidgets(2));
      
      // Verify child is not shown when loading
      expect(find.text('Content'), findsNothing);
    });

    testWidgets('displays overlay loading indicator when overlay mode is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoadingStateWidget(
            isLoading: true,
            loadingMode: LoadingMode.overlay,
            child: const Text('Content'),
          ),
        ),
      ));

      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Verify child is shown with overlay
      expect(find.text('Content'), findsOneWidget);
      
      // Verify overlay is shown
      expect(find.byType(Stack), findsOneWidget);
    });

    testWidgets('displays inline loader when inline mode is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoadingStateWidget(
            isLoading: true,
            loadingMode: LoadingMode.inline,
            inlineLoadingWidgetBuilder: (context) => 
                const SizedBox(height: 30, child: Text('Loading...')),
            child: const Text('Content'),
          ),
        ),
      ));

      // Verify inline loading is shown
      expect(find.text('Loading...'), findsOneWidget);
      
      // Verify child is not shown when loading
      expect(find.text('Content'), findsNothing);
    });

    testWidgets('shows custom loading widget when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoadingStateWidget(
            isLoading: true,
            loadingMode: LoadingMode.custom,
            customLoadingWidget: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
            child: const Text('Content'),
          ),
        ),
      ));

      // Verify custom loading widget is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Verify child is not shown when loading
      expect(find.text('Content'), findsNothing);
    });
  });
} 