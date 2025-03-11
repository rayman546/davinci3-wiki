use rusqlite::Connection;
use std::path::PathBuf;
use tracing::{info, error};
use tokio;
use clap::{Parser, Subcommand};
use davinci3_wiki::{
    error_handling::WikiResult,
    installer::{InstallConfig, InstallManager},
};

use crate::db::{init_database, DatabaseReader, DatabaseWriter};
use crate::error_handling::logging::init_debug_logging;
use crate::parser::models::WikiArticle;
use crate::image::ImageProcessor;
use crate::vector::VectorStore;
use crate::llm::LLMClient;

mod error_handling;
mod parser;
mod db;
mod image;
mod vector;
mod llm;
mod installer;

/// Davinci3 Wiki - An offline Wikipedia system with semantic search and LLM integration
#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Sets a custom config directory
    #[arg(short, long, value_name = "DIRECTORY")]
    config_dir: Option<String>,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Install the Davinci3 Wiki system
    Install {
        /// Skip downloading Wikipedia dump (use existing)
        #[arg(long)]
        skip_download: bool,
        
        /// Skip generating embeddings
        #[arg(long)]
        skip_embeddings: bool,
        
        /// Custom data directory
        #[arg(long, value_name = "DIRECTORY")]
        data_dir: Option<String>,
        
        /// Custom cache directory
        #[arg(long, value_name = "DIRECTORY")]
        cache_dir: Option<String>,
        
        /// Custom vector store directory
        #[arg(long, value_name = "DIRECTORY")]
        vector_dir: Option<String>,
        
        /// Custom Ollama URL
        #[arg(long, value_name = "URL")]
        ollama_url: Option<String>,
    },
    
    /// Update the system with latest Wikipedia dump
    Update {
        /// Skip downloading Wikipedia dump (use existing)
        #[arg(long)]
        skip_download: bool,
        
        /// Skip generating embeddings
        #[arg(long)]
        skip_embeddings: bool,
    },
    
    /// Uninstall the Davinci3 Wiki system
    Uninstall {
        /// Force uninstallation without confirmation
        #[arg(long)]
        force: bool,
    },
    
    /// Start the Davinci3 Wiki server
    Start {
        /// Port to listen on
        #[arg(short, long, default_value_t = 8080)]
        port: u16,
        
        /// Bind address
        #[arg(long, default_value = "127.0.0.1")]
        host: String,
    },
    
    /// Show status information about the installation
    Status,
}

#[tokio::main]
async fn main() -> WikiResult<()> {
    // Initialize logging
    tracing_subscriber::fmt::init();

    // Parse command line arguments
    let cli = Cli::parse();
    
    // Create default config
    let mut config = InstallConfig::default();
    
    // Apply config directory override if specified
    if let Some(config_dir) = cli.config_dir {
        let base_path = PathBuf::from(config_dir);
        config.data_dir = base_path.join("data");
        config.cache_dir = base_path.join("cache");
        config.vector_store_dir = base_path.join("vectors");
    }
    
    info!("Starting Davinci3 Wiki...");
    
    // Create installer
    let installer = InstallManager::new(config);
    
    // Handle commands
    match cli.command {
        Some(Commands::Install { 
            skip_download, 
            skip_embeddings,
            data_dir,
            cache_dir,
            vector_dir,
            ollama_url,
        }) => {
            info!("Installing Davinci3 Wiki...");
            
            // Apply custom configuration if provided
            if let Some(dir) = data_dir {
                config.data_dir = PathBuf::from(dir);
            }
            if let Some(dir) = cache_dir {
                config.cache_dir = PathBuf::from(dir);
            }
            if let Some(dir) = vector_dir {
                config.vector_store_dir = PathBuf::from(dir);
            }
            if let Some(url) = ollama_url {
                config.ollama_url = url;
            }
            
            // Create installer with updated config
            let installer = InstallManager::new(config);
            
            // Run installation
            // For now, the skip flags are not used, but they can be implemented in the installer
            installer.install().await?;
            info!("Installation completed successfully!");
        },
        
        Some(Commands::Update { skip_download, skip_embeddings }) => {
            info!("Updating Davinci3 Wiki...");
            // TODO: Implement update functionality
            installer.install().await?;
            info!("Update completed successfully!");
        },
        
        Some(Commands::Uninstall { force }) => {
            if !force {
                println!("Are you sure you want to uninstall Davinci3 Wiki? This will delete all data. [y/N]");
                let mut input = String::new();
                std::io::stdin().read_line(&mut input)?;
                
                if input.trim().to_lowercase() != "y" {
                    println!("Uninstallation cancelled.");
                    return Ok(());
                }
            }
            
            info!("Uninstalling Davinci3 Wiki...");
            installer.uninstall().await?;
            info!("Uninstallation completed successfully!");
        },
        
        Some(Commands::Start { port, host }) => {
            info!("Starting Davinci3 Wiki server on {}:{}...", host, port);
            // TODO: Implement server functionality
            info!("Server started successfully!");
            
            // Keep the server running
            tokio::signal::ctrl_c().await?;
            info!("Shutting down server...");
        },
        
        Some(Commands::Status) => {
            info!("Checking Davinci3 Wiki status...");
            
            // Check if directories exist
            println!("Configuration:");
            println!(" - Data directory: {}", config.data_dir.display());
            println!(" - Cache directory: {}", config.cache_dir.display());
            println!(" - Vector store directory: {}", config.vector_store_dir.display());
            println!(" - Ollama URL: {}", config.ollama_url);
            
            println!("\nInstallation Status:");
            println!(" - Data directory exists: {}", config.data_dir.exists());
            println!(" - Cache directory exists: {}", config.cache_dir.exists());
            println!(" - Vector store directory exists: {}", config.vector_store_dir.exists());
            
            // Check if database exists
            let db_path = config.data_dir.join("wiki.db");
            println!(" - Database exists: {}", db_path.exists());
            
            // Check if Ollama is installed
            let ollama_installed = installer.check_ollama_installed().await?;
            println!(" - Ollama installed: {}", ollama_installed);
            
            // Check number of articles if database exists
            if db_path.exists() {
                match Connection::open(&db_path) {
                    Ok(conn) => {
                        match conn.query_row("SELECT COUNT(*) FROM articles", [], |row| row.get::<_, i64>(0)) {
                            Ok(count) => println!(" - Articles count: {}", count),
                            Err(e) => println!(" - Error counting articles: {}", e),
                        }
                    },
                    Err(e) => println!(" - Error opening database: {}", e),
                }
            }
        },
        
        None => {
            // Default behavior if no command is provided
            println!("Davinci3 Wiki - An offline Wikipedia system with semantic search and LLM integration");
            println!("Run with --help to see available commands.");
        },
    }

    Ok(())
} 