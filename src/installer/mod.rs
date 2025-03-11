use std::path::{Path, PathBuf};
use tokio::fs;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn, error};
use std::process::Command;
use tokio::io::AsyncWriteExt;
use bzip2::bufread::BzDecoder;
use std::io::Read;
use tokio::process::Command as TokioCommand;

use crate::error_handling::{WikiError, WikiResult};
use crate::parser::{WikiXmlParser, models::WikiArticle};
use crate::db::schema;
use crate::db::writer::DatabaseWriter;
use crate::vector::VectorStore;

const OLLAMA_VERSION: &str = "0.1.27";
const OLLAMA_MODEL: &str = "llama2";
const WIKIDUMP_URL: &str = "https://dumps.wikimedia.org/simplewiki/latest/simplewiki-latest-pages-articles1.xml.bz2";
const BATCH_SIZE: usize = 100; // Number of articles to process at once

#[derive(Debug, Serialize, Deserialize)]
pub struct InstallConfig {
    pub data_dir: PathBuf,
    pub cache_dir: PathBuf,
    pub vector_store_dir: PathBuf,
    pub ollama_url: String,
    pub max_image_size: usize,
    pub max_batch_size: usize,
}

impl Default for InstallConfig {
    fn default() -> Self {
        Self {
            data_dir: PathBuf::from("data"),
            cache_dir: PathBuf::from("cache"),
            vector_store_dir: PathBuf::from("vectors"),
            ollama_url: "http://localhost:11434".to_string(),
            max_image_size: 10 * 1024 * 1024, // 10MB
            max_batch_size: 32,
        }
    }
}

pub struct InstallManager {
    config: InstallConfig,
    client: Client,
}

impl InstallManager {
    pub fn new(config: InstallConfig) -> Self {
        Self {
            config,
            client: Client::new(),
        }
    }

    pub async fn install(&self) -> WikiResult<()> {
        info!("Starting installation...");

        // Create directories
        self.create_directories().await?;

        // Check and install Ollama
        self.install_ollama().await?;

        // Pull required models
        self.pull_models().await?;

        // Download Wikipedia dump
        let dump_path = self.download_wikidump().await?;

        // Process Wikipedia dump and store in database
        let db_path = self.config.data_dir.join("wiki.db");
        self.process_wikidump(&dump_path, &db_path).await?;

        // Generate embeddings for articles
        self.generate_embeddings(&db_path).await?;

        info!("Installation completed successfully!");
        Ok(())
    }

    async fn create_directories(&self) -> WikiResult<()> {
        info!("Creating directories...");
        fs::create_dir_all(&self.config.data_dir).await?;
        fs::create_dir_all(&self.config.cache_dir).await?;
        fs::create_dir_all(&self.config.vector_store_dir).await?;
        Ok(())
    }

    async fn install_ollama(&self) -> WikiResult<()> {
        info!("Checking Ollama installation...");

        if self.check_ollama_installed().await? {
            info!("Ollama is already installed");
            return Ok(());
        }

        info!("Installing Ollama...");
        
        #[cfg(target_os = "windows")]
        {
            let installer_url = format!(
                "https://github.com/jmorganca/ollama/releases/download/v{}/ollama-windows.exe",
                OLLAMA_VERSION
            );
            let response = self.client.get(&installer_url).send().await?;
            let bytes = response.bytes().await?;
            
            let installer_path = self.config.cache_dir.join("ollama-installer.exe");
            fs::write(&installer_path, &bytes).await?;

            let status = Command::new(installer_path)
                .arg("/VERYSILENT")
                .status()
                .map_err(|e| WikiError::Installation(format!("Failed to run Ollama installer: {}", e)))?;

            if !status.success() {
                return Err(WikiError::Installation("Ollama installation failed".to_string()));
            }
        }

        #[cfg(target_os = "linux")]
        {
            let status = Command::new("curl")
                .args(["-fsSL", "https://ollama.ai/install.sh"])
                .stdout(std::process::Stdio::piped())
                .spawn()
                .map_err(|e| WikiError::Installation(format!("Failed to download Ollama installer: {}", e)))?
                .wait()
                .map_err(|e| WikiError::Installation(format!("Failed to run Ollama installer: {}", e)))?;

            if !status.success() {
                return Err(WikiError::Installation("Ollama installation failed".to_string()));
            }
        }

        #[cfg(target_os = "macos")]
        {
            let status = Command::new("brew")
                .args(["install", "ollama"])
                .status()
                .map_err(|e| WikiError::Installation(format!("Failed to install Ollama: {}", e)))?;

            if !status.success() {
                return Err(WikiError::Installation("Ollama installation failed".to_string()));
            }
        }

        info!("Ollama installed successfully");
        Ok(())
    }

    async fn check_ollama_installed(&self) -> WikiResult<bool> {
        let status = Command::new("ollama")
            .arg("--version")
            .status()
            .map_err(|_| WikiError::Installation("Failed to check Ollama version".to_string()))?;

        Ok(status.success())
    }

    async fn pull_models(&self) -> WikiResult<()> {
        info!("Pulling required models...");

        let status = Command::new("ollama")
            .args(["pull", OLLAMA_MODEL])
            .status()
            .map_err(|e| WikiError::Installation(format!("Failed to pull model {}: {}", OLLAMA_MODEL, e)))?;

        if !status.success() {
            return Err(WikiError::Installation(format!("Failed to pull model {}", OLLAMA_MODEL)));
        }

        info!("Models pulled successfully");
        Ok(())
    }

    async fn download_wikidump(&self) -> WikiResult<PathBuf> {
        let dump_path = self.config.data_dir.join("wiki-dump.xml.bz2");
        
        info!("Downloading Wikipedia dump from {}", WIKIDUMP_URL);
        
        // Create a progress indicator
        let response = self.client.get(WIKIDUMP_URL)
            .send()
            .await
            .map_err(|e| WikiError::Installation(format!("Failed to download Wikipedia dump: {}", e)))?;
        
        if !response.status().is_success() {
            return Err(WikiError::Installation(format!(
                "Failed to download Wikipedia dump, status code: {}", 
                response.status()
            )));
        }
        
        let total_size = response.content_length().unwrap_or(0);
        info!("Download size: {} bytes", total_size);
        
        let mut file = fs::File::create(&dump_path).await?;
        let mut downloaded: u64 = 0;
        let mut stream = response.bytes_stream();
        
        use futures_util::StreamExt;
        while let Some(item) = stream.next().await {
            let chunk = item.map_err(|e| WikiError::Installation(format!("Error while downloading: {}", e)))?;
            file.write_all(&chunk).await?;
            
            downloaded += chunk.len() as u64;
            
            // Log progress every 5MB
            if downloaded % (5 * 1024 * 1024) == 0 {
                if total_size > 0 {
                    let percent = (downloaded as f64 / total_size as f64) * 100.0;
                    info!("Downloaded: {:.2}% ({} / {} bytes)", percent, downloaded, total_size);
                } else {
                    info!("Downloaded: {} bytes", downloaded);
                }
            }
        }
        
        info!("Download completed: {} bytes", downloaded);
        Ok(dump_path)
    }
    
    async fn process_wikidump(&self, dump_path: &Path, db_path: &Path) -> WikiResult<()> {
        info!("Processing Wikipedia dump...");
        
        // Initialize database
        info!("Initializing database at {}", db_path.display());
        let mut db_conn = rusqlite::Connection::open(db_path)?;
        schema::init_database(&db_conn)?;
        let mut db_writer = DatabaseWriter::new(&mut db_conn);
        
        // Create parser
        let parser = WikiXmlParser::new();
        
        // Process the dump file
        info!("Decompressing and parsing dump file...");
        
        // Read the bz2 file in a blocking task to avoid blocking the async runtime
        let dump_path_clone = dump_path.to_path_buf();
        let articles = tokio::task::spawn_blocking(move || -> WikiResult<Vec<WikiArticle>> {
            // Open the BZ2 file
            let file = std::fs::File::open(dump_path_clone)?;
            let buf_reader = std::io::BufReader::new(file);
            let mut decompressor = BzDecoder::new(buf_reader);
            
            // Read the decompressed content
            let mut xml_content = String::new();
            decompressor.read_to_string(&mut xml_content)?;
            
            // Parse the XML content
            let mut parser = WikiXmlParser::new();
            parser.parse(&xml_content)
        }).await.map_err(|e| WikiError::OperationFailed(format!("Failed to process dump file: {}", e)))??;
        
        info!("Parsed {} articles", articles.len());
        
        // Insert articles into database
        info!("Inserting articles into database...");
        
        // Process articles in batches to avoid holding the transaction too long
        for (batch_idx, batch) in articles.chunks(100).enumerate() {
            info!("Processing batch {} with {} articles", batch_idx, batch.len());
            
            // Create a new transaction for each batch
            let tx = db_writer.begin_transaction()?;
            
            for article in batch {
                // Clone the article for the transaction
                db_writer.write_article(article, &tx)?;
            }
            
            // Commit the transaction
            tx.commit()?;
            
            info!("Inserted {} articles in batch {}", batch.len(), batch_idx);
        }
        
        info!("All articles inserted successfully");
        
        Ok(())
    }
    
    async fn generate_embeddings(&self, db_path: &Path) -> WikiResult<()> {
        info!("Generating embeddings for articles...");
        
        // Open database connection
        let db_conn = rusqlite::Connection::open(db_path)?;
        let db_reader = crate::db::DatabaseReader::new(&db_conn);
        
        // Initialize vector store
        let vector_store = VectorStore::new(
            &self.config.vector_store_dir,
            &self.config.ollama_url
        )?;
        
        // Get all articles
        let articles = db_reader.get_articles(1000)?;
        info!("Found {} articles for embedding generation", articles.len());
        
        // Generate embeddings in batches
        for (i, article) in articles.iter().enumerate() {
            // Generate embedding for article title and content
            let text = format!("Title: {}\n\nContent: {}", article.title, article.content);
            let embedding = vector_store.generate_embedding(&text).await?;
            
            // Store embedding with article title as key
            vector_store.store_embedding(&article.title, &embedding)?;
            
            if (i + 1) % 10 == 0 || i + 1 == articles.len() {
                info!("Generated embeddings for {}/{} articles", i + 1, articles.len());
            }
        }
        
        info!("All embeddings generated successfully");
        Ok(())
    }

    pub async fn uninstall(&self) -> WikiResult<()> {
        info!("Starting uninstallation...");

        // Remove data files
        let wiki_dump_path = self.config.data_dir.join("wiki-dump.xml.bz2");
        if wiki_dump_path.exists() {
            info!("Removing Wikipedia dump file...");
            fs::remove_file(&wiki_dump_path).await?;
        }

        let db_path = self.config.data_dir.join("wiki.db");
        if db_path.exists() {
            info!("Removing SQLite database...");
            fs::remove_file(&db_path).await?;
        }

        // Remove directories
        if self.config.data_dir.exists() {
            info!("Removing data directory...");
            fs::remove_dir_all(&self.config.data_dir).await?;
        }
        if self.config.cache_dir.exists() {
            info!("Removing cache directory...");
            fs::remove_dir_all(&self.config.cache_dir).await?;
        }
        if self.config.vector_store_dir.exists() {
            info!("Removing vector store directory...");
            fs::remove_dir_all(&self.config.vector_store_dir).await?;
        }

        // Uninstall Ollama
        info!("Uninstalling Ollama...");
        #[cfg(target_os = "windows")]
        {
            let status = Command::new("ollama")
                .args(["uninstall"])
                .status()
                .map_err(|e| WikiError::Installation(format!("Failed to uninstall Ollama: {}", e)))?;

            if !status.success() {
                warn!("Ollama uninstallation failed, status: {}", status);
                // Continue with uninstallation even if this fails
            }
        }

        #[cfg(any(target_os = "linux", target_os = "macos"))]
        {
            let status = Command::new("which")
                .arg("ollama")
                .output()
                .map_err(|e| WikiError::Installation(format!("Failed to locate Ollama: {}", e)))?;

            if status.status.success() {
                let ollama_path = String::from_utf8_lossy(&status.stdout);
                match fs::remove_file(ollama_path.trim()).await {
                    Ok(_) => info!("Removed Ollama binary"),
                    Err(e) => warn!("Failed to remove Ollama binary: {}", e),
                }
            }
        }

        info!("Uninstallation completed successfully!");
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[tokio::test]
    async fn test_install_manager() -> WikiResult<()> {
        let temp_dir = TempDir::new()?;
        let config = InstallConfig {
            data_dir: temp_dir.path().join("data"),
            cache_dir: temp_dir.path().join("cache"),
            vector_store_dir: temp_dir.path().join("vectors"),
            ..Default::default()
        };

        let installer = InstallManager::new(config);

        // Test installation
        installer.install().await?;

        // Verify directories were created
        assert!(installer.config.data_dir.exists());
        assert!(installer.config.cache_dir.exists());
        assert!(installer.config.vector_store_dir.exists());

        // Verify Ollama is installed
        assert!(installer.check_ollama_installed().await?);

        // Test uninstallation
        installer.uninstall().await?;

        // Verify directories were removed
        assert!(!installer.config.data_dir.exists());
        assert!(!installer.config.cache_dir.exists());
        assert!(!installer.config.vector_store_dir.exists());

        Ok(())
    }
} 