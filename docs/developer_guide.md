# Davinci3 Wiki Developer Guide

## Introduction

This guide provides detailed information for developers who want to understand, modify, or contribute to the Davinci3 Wiki project. It covers the architecture, project structure, design patterns, and development workflows.

## Project Overview

Davinci3 Wiki is an offline Wikipedia system built with Rust, featuring:

- Wikipedia dump parsing and processing
- SQLite database with FTS5 full-text search
- Vector embeddings for semantic search using LMDB
- LLM integration for question answering and summarization
- Flutter UI for cross-platform user interaction
- Command-line interface for system management

## Architecture

The project follows a modular architecture with clear separation of concerns:

![Architecture Diagram](architecture_diagram.png)

### Core Components

1. **Error Handling Module**: Central error management system with custom error types
2. **Parser Module**: Processes Wikipedia XML dumps into structured data
3. **Database Module**: Manages SQLite database operations, schemas, and FTS indexing
4. **Vector Module**: Handles embedding generation, storage, and semantic search
5. **LLM Module**: Integrates with Ollama for text processing and question answering
6. **Installer Module**: Manages system installation, updates, and uninstallation
7. **UI Module**: Flutter-based user interface with responsive design
8. **API Module**: REST API for programmatic access to the system

### Communication Flow

- **Parsing Flow**: XML Dump → Parser → Database → Vector Store
- **Search Flow**: Query → Database/Vector Store → UI
- **LLM Flow**: Query → Database → LLM → UI

## Project Structure

```
/
├── Cargo.toml             # Rust package configuration
├── Cargo.lock             # Pinned dependencies
├── README.md              # Project overview
├── src/                   # Rust source code
│   ├── main.rs            # Entry point
│   ├── error_handling/    # Error handling module
│   │   └── mod.rs         # Error types and utilities
│   ├── parser/            # Parser module
│   │   ├── mod.rs         # Module definition
│   │   ├── xml.rs         # XML parsing functionality
│   │   └── models.rs      # Data models
│   ├── db/                # Database module
│   │   ├── mod.rs         # Module definition
│   │   ├── schema.rs      # Database schema
│   │   ├── migrations.rs  # Schema migrations
│   │   └── queries.rs     # Database queries
│   ├── vector/            # Vector module
│   │   ├── mod.rs         # Module definition
│   │   ├── embeddings.rs  # Embedding generation
│   │   └── store.rs       # Vector store implementation
│   ├── llm/               # LLM module
│   │   ├── mod.rs         # Module definition
│   │   ├── client.rs      # LLM client implementation
│   │   └── prompts.rs     # Prompt templates
│   ├── installer/         # Installer module
│   │   ├── mod.rs         # Module definition
│   │   ├── download.rs    # Download functionality
│   │   └── setup.rs       # System setup utilities
│   └── api/               # API module
│       ├── mod.rs         # Module definition
│       ├── routes.rs      # API endpoints
│       └── handlers.rs    # Request handlers
├── ui/                    # Flutter UI
│   ├── pubspec.yaml       # Flutter package configuration
│   ├── lib/               # Dart source code
│   │   ├── main.dart      # Entry point
│   │   ├── models/        # Data models
│   │   ├── pages/         # UI pages
│   │   ├── widgets/       # Reusable UI components
│   │   └── services/      # Service layer
│   └── assets/            # Static assets
├── tests/                 # Integration tests
│   ├── parser_tests.rs    # Parser tests
│   ├── db_tests.rs        # Database tests
│   ├── vector_tests.rs    # Vector tests
│   └── api_tests.rs       # API tests
└── docs/                  # Documentation
    ├── user_manual.md     # User manual
    ├── api_documentation.md # API documentation
    └── developer_guide.md # This document
```

## Development Environment Setup

### Prerequisites

- Rust (latest stable)
- Cargo (included with Rust)
- SQLite 3.35.0+
- LMDB 0.9+
- Ollama (latest)
- Flutter 3.0+ (for UI development)
- Git

### Setting Up Development Environment

1. Clone the repository:

```bash
git clone https://github.com/yourusername/davinci3-wiki.git
cd davinci3-wiki
```

2. Install Rust dependencies:

```bash
cargo build
```

3. Set up Flutter (for UI development):

```bash
cd ui
flutter pub get
```

4. Install development tools:

```bash
cargo install cargo-watch  # For auto-reloading during development
cargo install cargo-expand # For macro debugging
cargo install cargo-tarpaulin # For code coverage
```

## Development Workflows

### Building the Project

```bash
# Build in debug mode
cargo build

# Build in release mode
cargo build --release
```

### Running Tests

```bash
# Run all tests
cargo test

# Run specific tests
cargo test parser
cargo test db
cargo test vector

# Run with verbose output
cargo test -- --nocapture
```

### Code Coverage

```bash
cargo tarpaulin --out Html
```

### Development with Auto-reload

```bash
cargo watch -x run
```

### Working on the UI

```bash
cd ui
flutter run -d chrome  # For web development
flutter run -d windows # For Windows desktop
flutter run -d macos   # For macOS desktop
flutter run -d linux   # For Linux desktop
```

## Error Handling

The project uses a custom error handling system defined in the `error_handling` module. All errors implement the `WikiError` trait:

```rust
// Example usage
use crate::error_handling::{Result, WikiError};

fn some_function() -> Result<()> {
    // Do something that might fail
    if something_fails {
        return Err(WikiError::DatabaseError("Specific error message".to_string()));
    }
    Ok(())
}
```

Error types include:
- `WikiError::ParseError`: XML parsing errors
- `WikiError::DatabaseError`: Database operation errors
- `WikiError::VectorError`: Vector store errors
- `WikiError::NetworkError`: Network-related errors
- `WikiError::LLMError`: LLM-related errors
- `WikiError::InstallerError`: Installation-related errors

## Database Design

The system uses SQLite with the following schema:

```sql
-- Articles table
CREATE TABLE articles (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- FTS virtual table for full-text search
CREATE VIRTUAL TABLE articles_fts USING fts5(
    title, 
    content, 
    content='articles', 
    content_rowid='id'
);

-- Categories table
CREATE TABLE categories (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

-- Article-Category relationship
CREATE TABLE article_categories (
    article_id INTEGER NOT NULL,
    category_id INTEGER NOT NULL,
    PRIMARY KEY (article_id, category_id),
    FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);
```

Migrations are handled in the `db/migrations.rs` file.

## Vector Store

The vector store uses LMDB with a custom serialization format:

1. Article ID: 8 bytes (u64)
2. Vector: 4 bytes (u32) for vector length + N*4 bytes for vector components (f32)

Each article's embedding is stored with the article ID as the key.

## LLM Integration

The LLM module communicates with Ollama using its HTTP API. Prompt templates are defined in `llm/prompts.rs`.

Example prompt template for question answering:

```rust
const QA_PROMPT_TEMPLATE: &str = r#"
Article: {article_content}

Question: {question}

Answer the question based only on the information provided in the article.
"#;
```

## Adding a New Feature

### Example: Adding a Bookmarking Feature

1. Update the database schema in `db/schema.rs`:

```rust
// Add bookmarks table
pub fn create_bookmarks_table(conn: &Connection) -> Result<()> {
    conn.execute(
        "CREATE TABLE IF NOT EXISTS bookmarks (
            id INTEGER PRIMARY KEY,
            article_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE
        )",
        [],
    )?;
    Ok(())
}
```

2. Add bookmark operations in `db/queries.rs`:

```rust
pub fn add_bookmark(conn: &Connection, article_id: u64, title: &str) -> Result<u64> {
    conn.execute(
        "INSERT INTO bookmarks (article_id, title) VALUES (?1, ?2)",
        params![article_id, title],
    )?;
    Ok(conn.last_insert_rowid() as u64)
}

pub fn get_bookmarks(conn: &Connection) -> Result<Vec<Bookmark>> {
    // Implementation
}

pub fn delete_bookmark(conn: &Connection, bookmark_id: u64) -> Result<()> {
    // Implementation
}
```

3. Add API endpoints in `api/routes.rs`:

```rust
pub fn configure_bookmark_routes(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/bookmarks")
            .route("", web::get().to(get_all_bookmarks))
            .route("", web::post().to(create_bookmark))
            .route("/{id}", web::delete().to(delete_bookmark)),
    );
}
```

4. Implement the UI components in the Flutter project.

## Coding Standards

### Rust Coding Standards

- Follow the [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
- Use meaningful variable and function names
- Add documentation comments (`///`) for public APIs
- Write unit tests for new functionality
- Use the `Result` type for error handling
- Avoid unwrap() and expect() in production code
- Use Clippy to catch common mistakes

### Flutter Coding Standards

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use the provider pattern for state management
- Separate business logic from UI code
- Create reusable widgets
- Add comments for complex UI components

## Testing Strategy

### Unit Tests

Each module should have unit tests covering its functionality. Test files should be placed alongside the module files with a `_test.rs` suffix.

Example unit test:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_article() {
        let xml = r#"<page>
            <title>Example</title>
            <revision>
                <text>Example content</text>
            </revision>
        </page>"#;
        
        let article = parse_article(xml).unwrap();
        assert_eq!(article.title, "Example");
        assert_eq!(article.content, "Example content");
    }
}
```

### Integration Tests

Integration tests in the `tests/` directory verify that modules work together correctly.

Example integration test:

```rust
use davinci3_wiki::{parser, db};

#[test]
fn test_parse_and_store() {
    let conn = db::create_in_memory_db().unwrap();
    let xml = r#"<page>
        <title>Test</title>
        <revision>
            <text>Test content</text>
        </revision>
    </page>"#;
    
    let article = parser::parse_article(xml).unwrap();
    let id = db::store_article(&conn, &article).unwrap();
    
    let retrieved = db::get_article(&conn, id).unwrap();
    assert_eq!(retrieved.title, article.title);
    assert_eq!(retrieved.content, article.content);
}
```

### UI Tests

The Flutter UI is tested using Flutter's built-in testing framework.

Example widget test:

```dart
void main() {
  testWidgets('Article card displays title and snippet', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ArticleCard(
        title: 'Test Article',
        snippet: 'This is a test article',
        id: '123',
      ),
    ));

    expect(find.text('Test Article'), findsOneWidget);
    expect(find.text('This is a test article'), findsOneWidget);
  });
}
```

## Performance Considerations

### Database Optimization

- Use prepared statements for frequently executed queries
- Create appropriate indexes for search patterns
- Use transactions for batch operations
- Consider using WAL mode for better concurrency

### Memory Management

- Process large XML dumps in chunks
- Use streaming parsers for XML processing
- Implement pagination for search results
- Use memory-mapped files for vector storage

### Parallel Processing

- Use Tokio for asynchronous operations
- Implement worker pools for parallel processing
- Use channels for communication between threads

## Security Implementation

### Rate Limiting

The system implements a sliding window rate limiter to prevent abuse and ensure system stability:

```rust
pub struct RateLimiter {
    windows: Arc<Mutex<HashMap<String, SlidingWindow>>>,
    limits: HashMap<EndpointCategory, (u32, Duration)>,
}

impl RateLimiter {
    pub fn new() -> Self {
        let mut limits = HashMap::new();
        // Define rate limits for different endpoint categories
        limits.insert(EndpointCategory::Standard, (100, Duration::from_secs(60))); // 100 req/min
        limits.insert(EndpointCategory::Restricted, (20, Duration::from_secs(60))); // 20 req/min
        limits.insert(EndpointCategory::LLM, (5, Duration::from_secs(60))); // 5 req/min
        
        RateLimiter {
            windows: Arc::new(Mutex::new(HashMap::new())),
            limits,
        }
    }
    
    pub async fn check(&self, ip: &str, category: EndpointCategory) -> Result<u32, RateLimitError> {
        // Implementation details
    }
}
```

The rate limiter is integrated into the API as middleware:

```rust
async fn rate_limit_middleware(
    req: Request,
    next: Next,
) -> Result<Response, Rejection> {
    let ip = get_client_ip(&req).unwrap_or_else(|| "unknown".to_string());
    let path = req.path().to_string();
    let category = get_endpoint_category(&path);
    
    match RATE_LIMITER.check(&ip, category).await {
        Ok(remaining) => {
            let resp = next.run(req).await;
            Ok(resp.header("X-RateLimit-Remaining", &remaining.to_string()))
        },
        Err(e) => {
            let status = StatusCode::TOO_MANY_REQUESTS;
            let retry_after = e.retry_after.as_secs();
            
            let json = json!({
                "status": "error",
                "message": "Rate limit exceeded. Please try again later.",
                "retry_after": retry_after
            });
            
            Ok(Response::builder()
                .status(status)
                .header("Content-Type", "application/json")
                .header("Retry-After", retry_after.to_string())
                .body(json.to_string().into())
                .unwrap())
        }
    }
}
```

### Input Validation

The system implements comprehensive input validation using a combination of built-in validation in the web framework and custom validators:

```rust
// Example of a query parameter validation
#[derive(Debug, Deserialize, Validate)]
pub struct SearchQuery {
    #[validate(length(min = 1, max = 200))]
    #[validate(regex = r"^[a-zA-Z0-9\s\.,\-_:;'\"\?!]+$")]
    pub q: String,
    
    #[validate(range(min = 1, max = 100))]
    #[serde(default = "default_limit")]
    pub limit: u32,
    
    #[validate(range(min = 0, max = 1000))]
    #[serde(default)]
    pub offset: u32,
}

// Example of path parameter validation
fn validate_title(title: String) -> Result<String, Rejection> {
    if title.len() > 200 {
        return Err(reject::custom(ValidationError::new(
            "Title exceeds maximum length of 200 characters"
        )));
    }
    
    let re = Regex::new(r"^[a-zA-Z0-9\s\.,\-_:;'\"\?!]+$").unwrap();
    if !re.is_match(&title) {
        return Err(reject::custom(ValidationError::new(
            "Title contains invalid characters"
        )));
    }
    
    Ok(title)
}
```

The validation is integrated into the request handlers:

```rust
pub async fn search(
    query: Query<SearchQuery>,
) -> Result<impl Reply, Rejection> {
    // Validate the query parameters
    query.validate().map_err(|e| reject::custom(ValidationError::from(e)))?;
    
    // Process the search request
    // ...
}

pub async fn get_article_by_title(
    title: Path<String>,
) -> Result<impl Reply, Rejection> {
    // Validate the path parameter
    let title = validate_title(title.into_inner())?;
    
    // Process the get article request
    // ...
}
```

### Security Headers

The API applies security headers to all responses using middleware:

```rust
async fn security_headers(
    req: Request,
    next: Next,
) -> Result<Response, Rejection> {
    let mut resp = next.run(req).await;
    
    resp.headers_mut().insert(
        "X-Content-Type-Options", 
        HeaderValue::from_static("nosniff")
    );
    resp.headers_mut().insert(
        "X-Frame-Options", 
        HeaderValue::from_static("DENY")
    );
    resp.headers_mut().insert(
        "Content-Security-Policy", 
        HeaderValue::from_static("default-src 'self'")
    );
    resp.headers_mut().insert(
        "X-XSS-Protection", 
        HeaderValue::from_static("1; mode=block")
    );
    
    Ok(resp)
}
```

### Error Handling for Security Events

Security-related errors are logged with an increased severity level:

```rust
fn log_security_event(event_type: SecurityEventType, details: &str, ip: Option<&str>) {
    let ip_str = ip.unwrap_or("unknown");
    match event_type {
        SecurityEventType::RateLimitExceeded => {
            warn!("[SECURITY] Rate limit exceeded from IP {}: {}", ip_str, details);
        },
        SecurityEventType::ValidationFailure => {
            warn!("[SECURITY] Validation failure from IP {}: {}", ip_str, details);
        },
        SecurityEventType::UnauthorizedAccess => {
            error!("[SECURITY] Unauthorized access attempt from IP {}: {}", ip_str, details);
        },
    }
}
```

### Testing Security Measures

The project includes specific tests for security features:

```rust
#[tokio::test]
async fn test_rate_limiting() {
    let rate_limiter = RateLimiter::new();
    let ip = "127.0.0.1";
    let category = EndpointCategory::Standard;
    
    // Make 100 requests (the limit for Standard category)
    for _ in 0..100 {
        let result = rate_limiter.check(ip, category).await;
        assert!(result.is_ok());
    }
    
    // The 101st request should fail
    let result = rate_limiter.check(ip, category).await;
    assert!(result.is_err());
    
    // Wait for the window to slide
    tokio::time::sleep(Duration::from_secs(30)).await;
    
    // Should be able to make some requests again
    let result = rate_limiter.check(ip, category).await;
    assert!(result.is_ok());
}

#[test]
fn test_input_validation() {
    // Test valid input
    let query = SearchQuery {
        q: "valid search".to_string(),
        limit: 50,
        offset: 0,
    };
    assert!(query.validate().is_ok());
    
    // Test invalid search query (too long)
    let query = SearchQuery {
        q: "a".repeat(201),
        limit: 50,
        offset: 0,
    };
    assert!(query.validate().is_err());
    
    // Test invalid limit
    let query = SearchQuery {
        q: "valid search".to_string(),
        limit: 101,
        offset: 0,
    };
    assert!(query.validate().is_err());
}
```

## Deployment

### Building for Release

```bash
cargo build --release
```

### Cross-compilation

For cross-compiling to different platforms, consider using cross:

```bash
cargo install cross
cross build --target x86_64-unknown-linux-musl --release
```

### Creating a Release Package

1. Build the binary
2. Include configuration files
3. Package UI assets
4. Create installation scripts

## Contributing Guidelines

### Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`cargo test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Review Checklist

- Does the code follow project coding standards?
- Are there appropriate tests?
- Is the documentation updated?
- Are there any performance concerns?
- Does the code handle errors appropriately?

## Troubleshooting Common Development Issues

### Rust Compiler Errors

- **Borrow checker issues**: Review ownership rules and consider using references or cloning data
- **Lifetime errors**: Add explicit lifetime annotations or restructure code
- **Type errors**: Use the `dbg!` macro to inspect types during compilation

### Database Issues

- **Migration failures**: Check the database schema version and ensure migrations are applied in order
- **Performance issues**: Review query execution plans with SQLite's EXPLAIN

### UI Development Issues

- **Flutter hot reload not working**: Check for syntax errors in Dart code
- **UI not updating**: Verify state management and widget rebuilding

## Glossary

- **FTS5**: SQLite's full-text search engine
- **LMDB**: Lightning Memory-Mapped Database
- **Ollama**: Local LLM server
- **Embedding**: Vector representation of text for semantic search
- **Tokio**: Asynchronous runtime for Rust
- **Flutter**: UI framework for cross-platform applications

## Further Reading

- [Rust Book](https://doc.rust-lang.org/book/)
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [LMDB Documentation](http://www.lmdb.tech/doc/)
- [Ollama Documentation](https://ollama.ai/docs)
- [Flutter Documentation](https://flutter.dev/docs) 