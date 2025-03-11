mod common;

use common::{test_helpers, mock_data};
use davinci3_wiki::{
    error_handling::WikiResult,
    installer::Installer,
    db::DbManager,
    vector::VectorStore,
    llm::LlmClient,
};
use std::path::PathBuf;
use tempfile::TempDir;
use std::time::Instant;

/// Full installation and basic operations test
#[tokio::test]
async fn test_full_workflow() -> WikiResult<()> {
    // Initialize logging
    test_helpers::init_test_logging();
    
    // Create temporary directories
    let temp_dir = test_helpers::test_temp_dir();
    
    // Get test installer config
    let mut config = mock_data::get_test_installer_config(temp_dir.path());
    
    // Setup test XML data path
    let xml_path = temp_dir.path().join("test_dump.xml");
    std::fs::write(&xml_path, mock_data::get_test_xml_dump())?;
    
    // Initialize installer
    let installer = Installer::new(config.clone());
    
    // Run installation with test data
    installer.install_from_file(&xml_path).await?;
    
    // Verify database was created
    let db_path = config.data_dir.join("wiki.db");
    assert!(db_path.exists(), "Database file not created");
    
    // Initialize database manager
    let db = DbManager::new(&db_path).await?;
    
    // Verify articles were imported
    let article_count = db.get_article_count().await?;
    assert_eq!(article_count, 3, "Expected 3 articles (namespace 0 pages only)");
    
    // Test search functionality
    let search_results = db.search("content").await?;
    assert!(!search_results.is_empty(), "Search returned no results");
    
    // Verify vector store was created
    let vector_path = config.vector_dir.clone();
    assert!(vector_path.exists(), "Vector store not created");
    
    // Initialize vector store
    let vector_store = VectorStore::new(&vector_path).await?;
    
    // Skip the rest of the test if Ollama is not available
    if test_helpers::skip_if_ollama_unavailable().await {
        return Ok(());
    }
    
    // Initialize LLM client
    let llm = LlmClient::new(&config.ollama_url).await?;
    
    // Test LLM functionality with timeout
    let article = db.get_article(1).await?;
    let prompt = mock_data::get_test_summary_prompt(&article.content);
    
    let summary = test_helpers::with_timeout(10, llm.generate_text(&prompt)).await;
    assert!(summary.is_ok(), "LLM request failed or timed out");
    assert!(!summary.unwrap().is_empty(), "LLM returned empty response");
    
    Ok(())
}

/// Full performance test
#[tokio::test]
async fn test_system_performance() -> WikiResult<()> {
    // Initialize logging
    test_helpers::init_test_logging();
    
    // Create temporary directories
    let temp_dir = test_helpers::test_temp_dir();
    
    // Get test installer config
    let mut config = mock_data::get_test_installer_config(temp_dir.path());
    
    // Setup test XML data path with large dataset
    let xml_path = temp_dir.path().join("large_test_dump.xml");
    std::fs::write(&xml_path, mock_data::get_large_test_xml_dump())?;
    
    // Initialize installer
    let installer = Installer::new(config.clone());
    
    // Measure installation time
    let start = Instant::now();
    installer.install_from_file(&xml_path).await?;
    let install_duration = start.elapsed();
    
    println!("Installation took: {:?}", install_duration);
    
    // Initialize database manager
    let db_path = config.data_dir.join("wiki.db");
    let db = DbManager::new(&db_path).await?;
    
    // Verify large number of articles were imported
    let article_count = db.get_article_count().await?;
    assert_eq!(article_count, 1000, "Expected 1000 articles");
    
    // Measure search performance
    let start = Instant::now();
    let search_results = db.search("science technology").await?;
    let search_duration = start.elapsed();
    
    println!("Search took: {:?}", search_duration);
    assert!(search_duration.as_millis() < 500, "Search took longer than 500ms");
    
    // Measure article retrieval performance
    let start = Instant::now();
    let _article = db.get_article(500).await?;
    let article_duration = start.elapsed();
    
    println!("Article retrieval took: {:?}", article_duration);
    assert!(article_duration.as_millis() < 100, "Article retrieval took longer than 100ms");
    
    Ok(())
}

/// Test uninstallation functionality
#[tokio::test]
async fn test_uninstall() -> WikiResult<()> {
    // Initialize logging
    test_helpers::init_test_logging();
    
    // Create temporary directories
    let temp_dir = test_helpers::test_temp_dir();
    
    // Get test installer config
    let config = mock_data::get_test_installer_config(temp_dir.path());
    
    // Create test directories and files
    std::fs::create_dir_all(&config.data_dir)?;
    std::fs::create_dir_all(&config.cache_dir)?;
    std::fs::create_dir_all(&config.vector_dir)?;
    
    let db_path = config.data_dir.join("wiki.db");
    std::fs::write(&db_path, "test content")?;
    
    // Initialize installer
    let installer = Installer::new(config.clone());
    
    // Run uninstallation
    installer.uninstall().await?;
    
    // Verify directories were removed
    assert!(!config.data_dir.exists(), "Data directory not removed");
    assert!(!config.cache_dir.exists(), "Cache directory not removed");
    assert!(!config.vector_dir.exists(), "Vector directory not removed");
    
    Ok(())
} 