# Davinci3 Wiki User Manual

## Table of Contents

1. [Introduction](#introduction)
2. [System Requirements](#system-requirements)
3. [Installation](#installation)
   - [Standard Installation](#standard-installation)
   - [Custom Installation](#custom-installation)
   - [Troubleshooting](#troubleshooting)
4. [Using the Command Line Interface](#using-the-command-line-interface)
   - [Command Overview](#command-overview)
   - [Installation Commands](#installation-commands)
   - [Management Commands](#management-commands)
5. [Using the Desktop Application](#using-the-desktop-application)
   - [Browsing Articles](#browsing-articles)
   - [Searching for Content](#searching-for-content)
   - [Reading Articles](#reading-articles)
   - [Using Semantic Search](#using-semantic-search)
   - [Ask Questions About Articles](#ask-questions-about-articles)
   - [Settings and Configuration](#settings-and-configuration)
6. [Advanced Usage](#advanced-usage)
   - [API Integration](#api-integration)
   - [Performance Tuning](#performance-tuning)
   - [Adding Custom Content](#adding-custom-content)
7. [Maintenance](#maintenance)
   - [Updating Content](#updating-content)
   - [Database Maintenance](#database-maintenance)
   - [Backup and Restore](#backup-and-restore)
8. [Troubleshooting](#troubleshooting-1)
   - [Common Issues](#common-issues)
   - [Error Messages](#error-messages)
   - [Getting Help](#getting-help)
9. [Legal](#legal)

## Introduction

Davinci3 Wiki is an offline Wikipedia system that provides access to Wikipedia content without requiring an internet connection. Once installed, you can search, read, and interact with articles entirely offline. The system features both traditional keyword search and advanced semantic search powered by vector embeddings, as well as LLM-based features like article summarization and question answering.

Key features:
- Complete offline access to Wikipedia content
- Fast full-text search
- Semantic search using AI-powered embeddings
- Article summarization and question answering using LLM
- Modern, cross-platform user interface
- Low resource requirements

## System Requirements

### Minimum Requirements
- Operating System: Windows 10/11, macOS 10.15+, or Linux (Ubuntu 20.04+)
- CPU: Dual-core 2 GHz processor
- RAM: 4 GB
- Storage: 10 GB free space (depends on the size of Wikipedia dump)
- Display: 1366 x 768 resolution

### Recommended Requirements
- CPU: Quad-core 3 GHz processor
- RAM: 8 GB
- Storage: 20+ GB free space
- Display: 1920 x 1080 resolution

### Required Software
- Rust (for building from source)
- SQLite 3.35.0+ (installed automatically)
- Ollama (installed automatically)
- Flutter (only for UI development)

## Installation

### Standard Installation

#### Using Pre-built Binaries

1. Download the latest release for your platform from the [Releases page](https://github.com/yourusername/davinci3-wiki/releases).
2. Extract the archive to a directory of your choice.
3. Open a terminal or command prompt and navigate to the extracted directory.
4. Run the installation command:

```bash
# On Windows
davinci3-wiki.exe install

# On macOS/Linux
./davinci3-wiki install
```

The installer will:
- Create necessary directories for data storage
- Install Ollama if not already installed
- Download and process a Wikipedia dump
- Generate vector embeddings for semantic search
- Set up the database with full-text search

This process may take some time depending on your system's performance and the size of the Wikipedia dump.

#### Building from Source

1. Ensure you have Rust installed. If not, install it from [rustup.rs](https://rustup.rs/).
2. Clone the repository:

```bash
git clone https://github.com/yourusername/davinci3-wiki.git
cd davinci3-wiki
```

3. Build the project:

```bash
cargo build --release
```

4. Run the installer:

```bash
./target/release/davinci3-wiki install
```

### Custom Installation

You can customize the installation with various command-line options:

```bash
# Install with custom data directory
davinci3-wiki install --data-dir /path/to/data

# Install with custom cache directory
davinci3-wiki install --cache-dir /path/to/cache

# Install with custom vector store directory
davinci3-wiki install --vector-dir /path/to/vectors

# Use a specific Ollama URL
davinci3-wiki install --ollama-url http://custom-ollama-server:11434

# Skip downloading the Wikipedia dump (if you already have one)
davinci3-wiki install --skip-download

# Skip generating embeddings (useful for faster installation)
davinci3-wiki install --skip-embeddings
```

### Troubleshooting

#### Installation Fails to Download Wikipedia Dump

If the download fails due to network issues:

1. Try downloading the dump manually from [Wikipedia dumps](https://dumps.wikimedia.org/simplewiki/latest/simplewiki-latest-pages-articles1.xml.bz2).
2. Place the downloaded file in the data directory (default: `./data/wiki-dump.xml.bz2`).
3. Run the installation with the `--skip-download` flag:

```bash
davinci3-wiki install --skip-download
```

#### Ollama Installation Issues

If Ollama fails to install automatically:

1. Install Ollama manually following the instructions at [ollama.ai](https://ollama.ai/).
2. Verify Ollama is running with:

```bash
ollama --version
```

3. Run the installation with the correct Ollama URL:

```bash
davinci3-wiki install --ollama-url http://localhost:11434
```

## Using the Command Line Interface

### Command Overview

Davinci3 Wiki provides a comprehensive command-line interface for managing the installation:

```bash
davinci3-wiki [OPTIONS] [COMMAND]
```

Options:
- `--config-dir <DIRECTORY>`: Sets a custom config directory

Commands:
- `install`: Install the Davinci3 Wiki system
- `update`: Update the system with latest Wikipedia dump
- `uninstall`: Uninstall the Davinci3 Wiki system
- `start`: Start the Davinci3 Wiki server
- `status`: Show status information about the installation

To get help on a specific command:

```bash
davinci3-wiki [COMMAND] --help
```

### Installation Commands

#### Install

```bash
davinci3-wiki install [OPTIONS]
```

Options:
- `--skip-download`: Skip downloading Wikipedia dump (use existing)
- `--skip-embeddings`: Skip generating embeddings
- `--data-dir <DIRECTORY>`: Custom data directory
- `--cache-dir <DIRECTORY>`: Custom cache directory
- `--vector-dir <DIRECTORY>`: Custom vector store directory
- `--ollama-url <URL>`: Custom Ollama URL

#### Update

```bash
davinci3-wiki update [OPTIONS]
```

Options:
- `--skip-download`: Skip downloading Wikipedia dump (use existing)
- `--skip-embeddings`: Skip generating embeddings

#### Uninstall

```bash
davinci3-wiki uninstall [OPTIONS]
```

Options:
- `--force`: Force uninstallation without confirmation

### Management Commands

#### Start

```bash
davinci3-wiki start [OPTIONS]
```

Options:
- `--port <PORT>`: Port to listen on (default: 8080)
- `--host <HOST>`: Bind address (default: 127.0.0.1)

#### Status

```bash
davinci3-wiki status
```

Shows information about the installation status, including:
- Configuration settings
- Directory paths
- Database status
- Article count
- Ollama status

## Using the Desktop Application

### Browsing Articles

1. Launch the desktop application:

```bash
# Navigate to the UI directory
cd ui

# Run the UI
flutter run -d windows  # or macos, linux
```

2. The main screen displays a list of articles. Scroll through the list to browse.
3. Articles are loaded in batches as you scroll for efficient memory usage.

### Searching for Content

1. Click on the Search tab in the navigation rail on the left.
2. Enter your search query in the search box.
3. The results will display matching articles sorted by relevance.
4. You can toggle between standard search and semantic search using the toggle at the top.

### Reading Articles

1. Click on any article from the browse view or search results to open it.
2. The article is displayed in a readable format with proper text formatting.
3. Related articles are shown in the sidebar for further exploration.
4. You can use the back button to return to the previous view.

### Using Semantic Search

Semantic search finds articles based on meaning rather than just keywords:

1. Navigate to the Search tab.
2. Enable the "Semantic Search" toggle.
3. Enter your query describing the topic you're interested in.
4. Results will be ranked by semantic similarity to your query.

Example: Searching for "space exploration challenges" might return articles about NASA, SpaceX, astronaut training, and other related topics, even if they don't contain those exact keywords.

### Ask Questions About Articles

When reading an article, you can ask questions about its content:

1. Open an article from the browse view or search results.
2. Scroll to the bottom of the article.
3. Enter your question in the "Ask a question" box.
4. The system will use the LLM to generate an answer based on the article content.

### Settings and Configuration

1. Click on the Settings tab in the navigation rail.
2. Here you can:
   - Clear the cache to free up space
   - Configure display preferences
   - View system information

## Advanced Usage

### API Integration

The system provides a HTTP API for integration with other applications:

- `GET /articles?page=<page>&limit=<limit>`: List articles with pagination
- `GET /articles/<id>`: Get article by ID
- `GET /search?q=<query>`: Keyword search
- `GET /semantic-search?q=<query>`: Semantic search
- `GET /answer?q=<question>&article_id=<id>`: Ask question about article

Example usage with curl:

```bash
# Start the server
davinci3-wiki start

# Get a list of articles
curl http://localhost:8080/articles?page=1&limit=10

# Search for articles
curl http://localhost:8080/search?q=quantum%20physics

# Get a specific article
curl http://localhost:8080/articles/12345

# Get an answer to a question about an article
curl http://localhost:8080/answer?q=What%20is%20the%20main%20topic%3F&article_id=12345
```

### Performance Tuning

#### Reducing Memory Usage

If your system has limited memory:

1. Start the server with a smaller batch size:
   ```bash
   davinci3-wiki start --batch-size 10
   ```

2. Limit the number of concurrent requests:
   ```bash
   davinci3-wiki start --max-connections 5
   ```

#### Improving Search Performance

For faster search performance:

1. Ensure your system has enough RAM to cache frequently accessed articles.
2. Consider using an SSD for storage of the database files.
3. If possible, precompute embeddings for all articles during installation.

### Adding Custom Content

You can add custom content to the system:

1. Prepare your content in XML format following the MediaWiki schema.
2. Place the XML file in the data directory.
3. Run the update command with the custom file:
   ```bash
   davinci3-wiki update --custom-file /path/to/custom.xml
   ```

## Maintenance

### Updating Content

To update the system with the latest Wikipedia dump:

```bash
davinci3-wiki update
```

This will:
1. Download the latest Wikipedia dump
2. Process and update the database
3. Generate new embeddings as needed

### Database Maintenance

For optimal performance, periodically maintain the database:

```bash
davinci3-wiki maintenance --optimize-db
```

This will:
1. Analyze and optimize the database structure
2. Remove any corrupt entries
3. Rebuild indexes for faster searching

### Backup and Restore

#### Creating a Backup

To create a backup of your installation:

```bash
davinci3-wiki backup --output /path/to/backup
```

This will create a compressed archive containing:
- Database files
- Vector embeddings
- Configuration settings

#### Restoring from Backup

To restore from a backup:

```bash
davinci3-wiki restore --input /path/to/backup
```

## Troubleshooting

### Common Issues

#### Application Won't Start

If the application fails to start:

1. Check if the server is running:
   ```bash
   davinci3-wiki status
   ```

2. Ensure Ollama is running:
   ```bash
   ollama --version
   ```

3. Check for port conflicts:
   ```bash
   netstat -ano | findstr 8080  # On Windows
   lsof -i :8080                # On macOS/Linux
   ```

#### Slow Search Performance

If search is slow:

1. Check your system resources (CPU, memory usage).
2. Optimize the database:
   ```bash
   davinci3-wiki maintenance --optimize-db
   ```
3. Consider using a faster storage device for the database files.

#### Missing Articles

If articles are missing:

1. Verify your installation has completed successfully:
   ```bash
   davinci3-wiki status
   ```
2. Check the article count shown in the status output.
3. If needed, reinstall or update the system:
   ```bash
   davinci3-wiki update
   ```

### Error Messages

#### "Failed to connect to Ollama"

This indicates Ollama is not running or not accessible:

1. Check if Ollama is installed:
   ```bash
   ollama --version
   ```
2. Start Ollama if it's not running.
3. Verify the Ollama URL in your configuration:
   ```bash
   davinci3-wiki status
   ```

#### "Database error: table articles not found"

This indicates a corrupted or missing database:

1. Try repairing the database:
   ```bash
   davinci3-wiki maintenance --repair-db
   ```
2. If that fails, reinstall the system:
   ```bash
   davinci3-wiki install
   ```

### Getting Help

If you encounter issues not covered in this manual:

1. Check the [GitHub Issues](https://github.com/yourusername/davinci3-wiki/issues) for similar problems.
2. Submit a new issue with details about your problem.
3. Include the output of:
   ```bash
   davinci3-wiki status --verbose
   ```

## Legal

### Copyright and Licensing

- Davinci3 Wiki is licensed under the MIT License.
- Wikipedia content is licensed under the Creative Commons Attribution-ShareAlike License.
- Ollama has its own licensing terms. Please refer to the [Ollama website](https://ollama.ai/) for details.

### Privacy

- Davinci3 Wiki operates entirely offline and does not collect or transmit any user data.
- No personal information is gathered during installation or usage.
- If you enable features that require internet access (such as updates), only anonymous connection to Wikipedia servers is made. 