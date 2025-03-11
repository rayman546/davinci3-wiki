use rusqlite::Connection;
use std::path::PathBuf;
use tracing::info;
use tokio;
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

#[tokio::main]
async fn main() -> WikiResult<()> {
    // Initialize logging
    tracing_subscriber::fmt::init();

    info!("Starting Davinci3 Wiki...");

    // Create default config
    let config = InstallConfig::default();

    // Create and run installer
    let installer = InstallManager::new(config);
    installer.install().await?;

    info!("Davinci3 Wiki started successfully!");
    Ok(())
} 