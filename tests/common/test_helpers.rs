use std::{path::PathBuf, sync::Once};
use tempfile::TempDir;

static INIT: Once = Once::new();

/// Initialize logging for tests
pub fn init_test_logging() {
    INIT.call_once(|| {
        if std::env::var("RUST_LOG").is_err() {
            std::env::set_var("RUST_LOG", "info");
        }
        tracing_subscriber::fmt::init();
    });
}

/// Create a temporary directory for test data
pub fn test_temp_dir() -> TempDir {
    TempDir::new().expect("Failed to create temp directory")
}

/// Get a path to a temporary file within a temporary directory
pub fn temp_db_path(temp_dir: &TempDir) -> PathBuf {
    temp_dir.path().join("test_wiki.db")
}

/// Get a path to a temporary vector store within a temporary directory
pub fn temp_vector_path(temp_dir: &TempDir) -> PathBuf {
    temp_dir.path().join("vectors")
}

/// Create a small test database for unit tests
pub async fn create_test_db(db_path: &PathBuf) -> davinci3_wiki::db::DbManager {
    use davinci3_wiki::db::DbManager;
    use davinci3_wiki::error_handling::WikiResult;
    
    let db = DbManager::new(db_path).await.expect("Failed to create test DB");
    
    // Initialize schema
    db.init_schema().await.expect("Failed to initialize schema");
    
    // Add some test data
    for article in crate::common::mock_data::get_test_articles() {
        db.insert_article(&article).await.expect("Failed to insert test article");
    }
    
    db
}

/// Create a test vector store for unit tests
pub async fn create_test_vector_store(vector_path: &PathBuf) -> davinci3_wiki::vector::VectorStore {
    use davinci3_wiki::vector::VectorStore;
    
    let store = VectorStore::new(vector_path).await.expect("Failed to create test vector store");
    
    // Add some test vectors
    for (id, vector) in crate::common::mock_data::get_test_vectors() {
        store.insert(id, &vector).await.expect("Failed to insert test vector");
    }
    
    store
}

/// Wait for Ollama to respond
pub async fn wait_for_ollama(url: &str, timeout_secs: u64) -> bool {
    use tokio::time::{timeout, Duration};
    use reqwest::Client;
    
    let client = Client::new();
    
    match timeout(
        Duration::from_secs(timeout_secs),
        client.get(&format!("{}/api/tags", url)).send()
    ).await {
        Ok(Ok(response)) => response.status().is_success(),
        _ => false,
    }
}

/// Helper to run a test that depends on Ollama being available
pub async fn skip_if_ollama_unavailable() -> bool {
    use davinci3_wiki::llm::DEFAULT_OLLAMA_URL;
    
    if !wait_for_ollama(DEFAULT_OLLAMA_URL, 2).await {
        println!("Skipping test: Ollama is not available");
        return true;
    }
    
    false
}

/// Helper to run a function with a timeout
pub async fn with_timeout<F, T>(timeout_secs: u64, f: F) -> Result<T, String>
where
    F: std::future::Future<Output = T>,
{
    use tokio::time::{timeout, Duration};
    
    timeout(Duration::from_secs(timeout_secs), f)
        .await
        .map_err(|_| format!("Operation timed out after {} seconds", timeout_secs))
} 