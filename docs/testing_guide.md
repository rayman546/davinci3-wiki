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