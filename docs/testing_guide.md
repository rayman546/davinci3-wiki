# Davinci3 Wiki Testing Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Testing Philosophy](#testing-philosophy)
3. [Test Categories](#test-categories)
   - [Unit Tests](#unit-tests)
   - [Integration Tests](#integration-tests)
   - [End-to-End Tests](#end-to-end-tests)
   - [Performance Tests](#performance-tests)
4. [Test Directory Structure](#test-directory-structure)
5. [Running Tests](#running-tests)
6. [Writing Tests](#writing-tests)
7. [Mocking and Test Data](#mocking-and-test-data)
8. [Continuous Integration](#continuous-integration)
9. [Code Coverage](#code-coverage)
10. [Troubleshooting](#troubleshooting)
11. [Testing Frontend Error Handling](#testing-frontend-error-handling)

## Introduction

This guide describes the testing approach for the Davinci3 Wiki project. It explains how to run existing tests, write new tests, and understand test coverage.

## Testing Philosophy

Davinci3 Wiki follows these testing principles:

1. **Test-Driven Development**: When possible, write tests before implementing features
2. **Comprehensive Coverage**: Aim for high test coverage across all modules
3. **Fast Feedback**: Tests should run quickly to provide immediate feedback
4. **Isolation**: Tests should be independent and not rely on external services
5. **Realistic Scenarios**: Integration tests should reflect real-world usage

## Test Categories

### Unit Tests

Unit tests verify the behavior of individual functions or methods in isolation. They are located alongside the code they test with a `_test` suffix.

**Characteristics**:
- Fast execution
- No external dependencies
- Focus on a single function or method
- Use mocks for external components

**Example**:
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_article_title() {
        let xml = "<page><title>Test Title</title></page>";
        let result = extract_title(xml);
        assert_eq!(result, Ok("Test Title".to_string()));
    }
}
```

### Integration Tests

Integration tests verify that multiple components work together correctly. These tests are located in the `/tests` directory.

**Characteristics**:
- Test interaction between modules
- May use in-memory databases
- Test complete workflows
- Less reliance on mocks

**Example**:
```rust
#[tokio::test]
async fn test_db_init_and_basic_operations() -> WikiResult<()> {
    let db = DbManager::new_in_memory().await?;
    let article = Article {
        id: None,
        title: "Test Article".to_string(),
        content: "Test content".to_string(),
        categories: vec!["Test".to_string()],
    };
    
    let id = db.insert_article(&article).await?;
    let retrieved = db.get_article(id).await?;
    
    assert_eq!(retrieved.title, article.title);
    assert_eq!(retrieved.content, article.content);
    Ok(())
}
```

### End-to-End Tests

End-to-end tests verify the entire system works together. These test the application from the user's perspective.

**Characteristics**:
- Test complete user workflows
- Interact with the application as a user would
- May require actual database and server setup
- Slower than other test types

**Example**:
```rust
#[tokio::test]
async fn test_install_search_workflow() -> WikiResult<()> {
    // Setup test environment
    let temp_dir = TempDir::new("test_wiki")?;
    let config = InstallerConfig {
        data_dir: temp_dir.path().to_path_buf(),
        // Other config options...
    };
    
    // Run installation
    let installer = Installer::new(config);
    installer.install(TestWikiDump::new()).await?;
    
    // Test search functionality
    let db = DbManager::new(temp_dir.path().join("wiki.db")).await?;
    let results = db.search("test query").await?;
    
    assert!(!results.is_empty());
    Ok(())
}
```

### Performance Tests

Performance tests verify the system meets performance requirements.

**Characteristics**:
- Measure execution time
- Test with large datasets
- Verify memory usage
- Check system under load

**Example**:
```rust
#[tokio::test]
async fn test_search_performance() -> WikiResult<()> {
    let db = setup_performance_test_db().await?;
    
    let start = Instant::now();
    let _results = db.search("test query").await?;
    let duration = start.elapsed();
    
    assert!(duration < Duration::from_millis(500));
    Ok(())
}
```

## Test Directory Structure

```
/src
  /module_name
    mod.rs
    implementation.rs
    implementation_test.rs  // Unit tests
/tests
  common/                   // Shared test utilities
    mod.rs
    test_helpers.rs
    mock_data.rs
  db_test.rs                // Integration tests for DB module
  parser_test.rs            // Integration tests for Parser module
  vector_test.rs            // Integration tests for Vector module
  llm_test.rs               // Integration tests for LLM module
  installer_test.rs         // Integration tests for Installer module
  e2e_test.rs               // End-to-end tests
  performance_test.rs       // Performance tests
```

## Running Tests

### Running All Tests

```bash
cargo test
```

### Running Tests for a Specific Module

```bash
cargo test --test db_test
```

### Running a Specific Test

```bash
cargo test test_db_init_and_basic_operations
```

### Running Tests with Logging Output

```bash
RUST_LOG=debug cargo test -- --nocapture
```

### Running Tests in Release Mode

```bash
cargo test --release
```

## Writing Tests

### Unit Test Best Practices

1. **Name tests clearly**: Use descriptive names like `test_function_name_condition_result`
2. **Test edge cases**: Include tests for boundary conditions and error cases
3. **Keep tests simple**: Each test should verify one specific behavior
4. **Use test utilities**: Create helper functions for common setup and assertions
5. **Use fixtures**: Define fixed test data for consistent results

### Integration Test Best Practices

1. **Focus on module interactions**: Test how components work together
2. **Use in-memory databases**: Speed up tests by avoiding disk I/O
3. **Clean up resources**: Ensure tests don't leave behind temporary files or databases
4. **Use realistic workflows**: Tests should reflect actual user scenarios
5. **Test error handling**: Verify graceful handling of failures

## Mocking and Test Data

### Mock Framework

Davinci3 Wiki uses `mockall` for creating mock objects in unit tests.

**Example**:
```rust
#[cfg(test)]
mod tests {
    use super::*;
    use mockall::{mock, predicate::*};

    mock! {
        LlmClient {}
        trait LlmInterface {
            async fn generate_text(&self, prompt: &str) -> WikiResult<String>;
        }
    }

    #[tokio::test]
    async fn test_summarize_with_mock_llm() -> WikiResult<()> {
        let mut mock_llm = MockLlmClient::new();
        mock_llm
            .expect_generate_text()
            .with(predicate::contains("Summarize:"))
            .returning(|_| Ok("Mock summary text".to_string()));
        
        let summarizer = Summarizer::new(Box::new(mock_llm));
        let summary = summarizer.summarize("Article text").await?;
        
        assert!(summary.contains("Mock summary text"));
        Ok(())
    }
}
```

### Test Data

Test data is stored in the `/tests/common/mock_data.rs` file.

**Example**:
```rust
// Example article data
pub fn get_test_article() -> Article {
    Article {
        id: Some(1),
        title: "Test Article".to_string(),
        content: "This is a test article with some content.".to_string(),
        categories: vec!["Test".to_string(), "Example".to_string()],
    }
}

// Small XML dump for testing
pub fn get_test_xml_dump() -> &'static str {
    r#"<mediawiki>
      <page>
        <title>Test Page 1</title>
        <revision>
          <text>Test content 1</text>
        </revision>
      </page>
      <page>
        <title>Test Page 2</title>
        <revision>
          <text>Test content 2</text>
        </revision>
      </page>
    </mediawiki>"#
}
```

## Continuous Integration

Davinci3 Wiki uses GitHub Actions for continuous integration.

The CI pipeline runs the following steps:
1. **Build**: Compile the code on multiple platforms
2. **Test**: Run all tests
3. **Lint**: Check code style with `clippy`
4. **Coverage**: Generate code coverage reports

## Code Coverage

Code coverage is tracked using `cargo-tarpaulin`.

### Running Coverage Locally

```bash
# Install cargo-tarpaulin
cargo install cargo-tarpaulin

# Generate coverage report
cargo tarpaulin --out Html

# View the report
open tarpaulin-report.html
```

### Coverage Targets

- **Overall Coverage Target**: 80%
- **Core Module Target**: 90%
- **Utility Module Target**: 70%

## Troubleshooting

### Common Test Failures

#### Database Locks

If tests fail with database lock errors:

1. Ensure you're closing database connections in tests
2. Use unique database file names for each test
3. Add timeouts to database operations

#### Asynchronous Test Issues

If async tests fail or hang:

1. Make sure you're using `#[tokio::test]` for async tests
2. Add timeouts to prevent infinite waiting
3. Check for unresolved futures

#### Resource Cleanup

If tests leave behind resources:

1. Use `tempdir` for temporary file operations
2. Implement `Drop` for test fixtures
3. Use Rust's RAII pattern to ensure cleanup 

## Testing Frontend Error Handling

Testing error handling in the UI is critical to ensure a good user experience under all conditions. This section covers techniques for testing the various error states, loading conditions, and connectivity scenarios.

### UI Error Handling Testing Strategy

1. **Component Tests**: Test individual error handling components in isolation
2. **Integration Tests**: Test error handling in the context of full pages
3. **Offline Mode Tests**: Test behavior when the device is offline
4. **State Transition Tests**: Test transitions between different states (loading, error, success)
5. **Retry Mechanism Tests**: Test that retry functionality works correctly

### Testing Error Display Components

Use the `testWidgets` function to test the `ErrorDisplayWidget` with different configurations:

```dart
testWidgets('ErrorDisplayWidget shows correct content', (WidgetTester tester) async {
  // Build widget
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ErrorDisplayWidget(
        errorType: ErrorType.network,
        message: 'Connection failed',
        title: 'Network Error',
        onRetry: () {}, // Mock callback
      ),
    ),
  ));
  
  // Verify content
  expect(find.text('Network Error'), findsOneWidget);
  expect(find.text('Connection failed'), findsOneWidget);
  expect(find.byIcon(Icons.signal_wifi_off), findsOneWidget);
  expect(find.byType(ElevatedButton), findsOneWidget);
});
```

### Testing Loading States

Test the `LoadingStateWidget` with different configurations:

```dart
testWidgets('LoadingStateWidget shows skeleton loading', (WidgetTester tester) async {
  // Build widget
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: LoadingStateWidget(
        useSkeleton: true,
        skeletonType: SkeletonType.article,
        skeletonItemCount: 3,
      ),
    ),
  ));
  
  // Verify skeleton items are rendered
  expect(find.byType(Shimmer), findsOneWidget);
  // Additional verification of skeleton items...
});
```

### Testing Network-Aware Components

Test the `NetworkAwareWidget` with different connectivity states:

```dart
testWidgets('NetworkAwareWidget shows offline content when disconnected', 
    (WidgetTester tester) async {
  // Create a mock connectivity provider
  final mockConnectivityProvider = MockConnectivityProvider();
  when(mockConnectivityProvider.isConnected).thenReturn(false);
  
  // Build widget with provider
  await tester.pumpWidget(MaterialApp(
    home: ChangeNotifierProvider<ConnectivityProvider>.value(
      value: mockConnectivityProvider,
      child: NetworkAwareWidget(
        enforceConnectivity: true,
        offlineMessage: 'You are offline',
        onlineContent: const Text('Online Content'),
      ),
    ),
  ));
  
  // Verify offline content is shown
  expect(find.text('You are offline'), findsOneWidget);
  expect(find.text('Online Content'), findsNothing);
  
  // Change connectivity state
  when(mockConnectivityProvider.isConnected).thenReturn(true);
  mockConnectivityProvider.notifyListeners();
  await tester.pump();
  
  // Verify online content is now shown
  expect(find.text('You are offline'), findsNothing);
  expect(find.text('Online Content'), findsOneWidget);
});
```

### Testing API Error Handling

Test that API errors are properly handled and displayed:

```dart
testWidgets('Shows error when API call fails', (WidgetTester tester) async {
  // Setup mock service
  final mockWikiService = MockWikiService();
  when(mockWikiService.getArticles(
    any, any, any, 
  )).thenThrow(Exception('API error'));
  
  // Build widget with mocked service
  await tester.pumpWidget(MaterialApp(
    home: Provider<WikiService>.value(
      value: mockWikiService,
      child: const ArticlesPage(),
    ),
  ));
  
  // Wait for API call and error handling
  await tester.pumpAndSettle();
  
  // Verify error is displayed
  expect(find.byType(ErrorDisplayWidget), findsOneWidget);
  expect(find.text('API error'), findsOneWidget);
});
```

### Testing Retry Functionality

Test that retry functionality works correctly:

```dart
testWidgets('Retry button triggers data reload', (WidgetTester tester) async {
  // Setup mock service that fails once then succeeds
  final mockWikiService = MockWikiService();
  var callCount = 0;
  when(mockWikiService.getArticles(any, any, any)).thenAnswer((_) {
    callCount++;
    if (callCount == 1) {
      throw Exception('First call fails');
    }
    return Future.value([MockArticle()]);
  });
  
  // Build widget
  await tester.pumpWidget(MaterialApp(
    home: Provider<WikiService>.value(
      value: mockWikiService,
      child: const ArticlesPage(),
    ),
  ));
  
  // Wait for first call to fail
  await tester.pumpAndSettle();
  expect(find.byType(ErrorDisplayWidget), findsOneWidget);
  
  // Tap retry button
  await tester.tap(find.text('Try Again'));
  await tester.pump();
  
  // Verify loading state
  expect(find.byType(LoadingStateWidget), findsOneWidget);
  
  // Wait for second call to succeed
  await tester.pumpAndSettle();
  
  // Verify content is displayed
  expect(find.byType(ErrorDisplayWidget), findsNothing);
  expect(find.byType(ArticleCard), findsOneWidget);
});
```

### Testing Offline Fallback

Test that the app falls back to cached content when offline:

```dart
testWidgets('Shows cached content when offline', (WidgetTester tester) async {
  // Setup mocks
  final mockWikiService = MockWikiService();
  final mockConnectivityProvider = MockConnectivityProvider();
  final mockCacheService = MockCacheService();
  
  // Configure connectivity as offline
  when(mockConnectivityProvider.isConnected).thenReturn(false);
  
  // Configure cache to return articles
  when(mockCacheService.getCachedArticles(any, any))
      .thenAnswer((_) => Future.value([MockArticle()]));
  
  // Configure service to use cache
  when(mockWikiService.getArticles(
    any, any, connectivityProvider: mockConnectivityProvider,
  )).thenAnswer((_) async {
    throw Exception('Offline');
  });
  
  // Build widget with mocked services
  await tester.pumpWidget(MaterialApp(
    home: MultiProvider(
      providers: [
        Provider<WikiService>.value(value: mockWikiService),
        ChangeNotifierProvider<ConnectivityProvider>.value(
          value: mockConnectivityProvider),
        Provider<CacheService>.value(value: mockCacheService),
      ],
      child: const ArticlesPage(),
    ),
  ));
  
  // Wait for render
  await tester.pumpAndSettle();
  
  // Verify offline banner is shown
  expect(find.text('You are offline'), findsOneWidget);
  
  // Verify cached content is displayed
  expect(find.byType(ArticleCard), findsOneWidget);
});
```

### Error Handling Test Checklist

When testing a new page or component, ensure you test these error handling scenarios:

- [ ] Initial loading state
- [ ] Empty state with appropriate message
- [ ] Network errors (timeout, connection failed)
- [ ] Server errors (500 responses)
- [ ] Client errors (400 responses)
- [ ] Offline state with appropriate message
- [ ] Offline with cached data
- [ ] Retry functionality
- [ ] Error during background operations
- [ ] Canceled operations (e.g., during navigation)

### Mocks for Error Handling Testing

Create these mock classes to facilitate error handling testing:

```dart
class MockConnectivityProvider extends Mock implements ConnectivityProvider {
  @override
  bool get isConnected => super.noSuchMethod(
    Invocation.getter(#isConnected),
    returnValue: true,
    returnValueForMissingStub: true,
  );
  
  @override
  void notifyListeners() {
    super.noSuchMethod(Invocation.method(#notifyListeners, []));
  }
}

class MockWikiService extends Mock implements WikiService {}

class MockCacheService extends Mock implements CacheService {}

class MockArticle extends Mock implements Article {
  @override
  String get id => 'mock-id';
  
  @override
  String get title => 'Mock Article';
  
  @override
  String get summary => 'This is a mock article for testing';
  
  @override
  String get content => 'Mock content';
  
  @override
  List<String> get relatedArticles => [];
}
``` 