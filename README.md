# Davinci3 Wiki

An offline Wikipedia system with semantic search capabilities and LLM integration.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

Davinci3 Wiki is a comprehensive offline Wikipedia solution that allows you to:

- Download and process Wikipedia dumps
- Search articles using both keyword and semantic search
- Generate summaries and answer questions about articles using LLM
- Access content through a modern Flutter UI
- Run completely offline once installed

The system is built with performance in mind and meets the following requirements:
- Search latency < 500ms
- Article load time < 1 sec
- LLM response < 3 sec
- Initial load < 5 sec
- Memory usage < 2GB

## Features

- **Efficient Data Processing**: Parse and index Wikipedia XML dumps
- **Full-Text Search**: Fast keyword search using SQLite FTS5
- **Semantic Search**: Find semantically similar articles using vector embeddings
- **LLM Integration**: Generate summaries, answer questions, and more
- **Modern UI**: Cross-platform Flutter interface with dark mode support
- **Offline Operation**: Everything runs locally after installation
- **Command-Line Interface**: Simple installation and management

## Installation

### Prerequisites

- Rust (latest stable)
- SQLite 3.35.0+
- Ollama (will be installed automatically if not present)
- Flutter 3.0+ (for UI only)

### Using Cargo

```bash
# Clone the repository
git clone https://github.com/yourusername/davinci3-wiki.git
cd davinci3-wiki

# Build the project
cargo build --release

# Install with default settings
./target/release/davinci3-wiki install
```

### Custom Installation

You can customize the installation with various command-line options:

```bash
# Install with custom data directory
./target/release/davinci3-wiki install --data-dir /path/to/data

# Skip downloading the Wikipedia dump if you already have one
./target/release/davinci3-wiki install --skip-download

# Skip generating embeddings (useful for faster installation)
./target/release/davinci3-wiki install --skip-embeddings
```

### Running the UI

```bash
# Navigate to the UI directory
cd ui

# Install Flutter dependencies
flutter pub get

# Run the UI
flutter run -d windows  # or macos, linux
```

## Usage

### Command-Line Interface

```bash
# Show status of installation
./target/release/davinci3-wiki status

# Start the server
./target/release/davinci3-wiki start

# Update with the latest Wikipedia dump
./target/release/davinci3-wiki update

# Uninstall
./target/release/davinci3-wiki uninstall
```

### API Reference

The system provides a HTTP API for integration with other applications:

- `GET /articles`: List all articles
- `GET /articles/{id}`: Get article by ID
- `GET /search?q={query}`: Keyword search
- `GET /semantic-search?q={query}`: Semantic search
- `GET /answer?q={question}&article_id={id}`: Ask question about article

## Architecture

The project follows a modular architecture:

- **Error Handling**: Comprehensive error types and logging
- **Parser**: XML parsing and article extraction
- **Database**: SQLite storage with FTS5 for full-text search
- **Vector**: Vector embeddings for semantic search
- **LLM**: Integration with Ollama for text generation
- **Installer**: Installation and update management
- **UI**: Cross-platform Flutter interface

## Development

### Project Structure

```
/src
  /error_handling - Error types and logging
  /parser - Wikipedia XML parsing
  /db - Database operations
  /vector - Vector embeddings
  /llm - LLM integration
  /installer - Installation management
/ui - Flutter application
/tests - Integration tests
```

### Running Tests

```bash
# Run unit tests
cargo test

# Run integration tests (skipping LLM tests that require Ollama)
cargo test --test installer_test --test parser_test --test db_test
```

### Building Documentation

```bash
cargo doc --no-deps --open
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Wikipedia for providing the data dumps
- The Rust community for excellent libraries
- The Flutter team for the UI framework
- The Ollama project for local LLM support 