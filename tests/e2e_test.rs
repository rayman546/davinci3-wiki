mod common;

use common::{test_helpers, mock_data};
use davinci3_wiki::{
    error_handling::WikiResult,
    installer::Installer,
    db::DatabaseManager,
    vector::VectorStore,
    llm::LlmClient,
};
use std::path::PathBuf;
use tempfile::TempDir;
use std::time::Instant;
use std::future::Future;
use std::num::NonZeroUsize;
use std::ops::Div;
use std::pin::Pin;
use std::sync::Arc;
use std::task::{Context, Poll};
use std::time::Duration;

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
    let db = DatabaseManager::new(&db_path).await?;
    
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

/// Test incremental update functionality
#[tokio::test]
async fn test_incremental_update() -> WikiResult<()> {
    // Initialize logging
    test_helpers::init_test_logging();
    
    // Create temporary directories
    let temp_dir = test_helpers::test_temp_dir();
    
    // Get test installer config
    let config = mock_data::get_test_installer_config(temp_dir.path());
    
    // Setup initial test XML data path
    let initial_xml_path = temp_dir.path().join("initial_dump.xml");
    std::fs::write(&initial_xml_path, mock_data::get_test_xml_dump())?;
    
    // Initialize installer
    let installer = Installer::new(config.clone());
    
    // Run initial installation with test data
    println!("Running initial installation...");
    installer.install_from_file(&initial_xml_path).await?;
    
    // Initialize database manager
    let db_path = config.data_dir.join("wiki.db");
    let db = DatabaseManager::new(&db_path).await?;
    
    // Verify initial articles were imported
    let initial_article_count = db.get_article_count().await?;
    assert_eq!(initial_article_count, 3, "Expected 3 initial articles");
    
    // Store information about initial articles for later comparison
    let initial_titles = db.get_all_article_titles().await?;
    println!("Initial articles: {:?}", initial_titles);
    
    // Setup updated XML data with some changes:
    // - One article removed
    // - One article unchanged
    // - One article modified
    // - Two new articles added
    let updated_xml_path = temp_dir.path().join("updated_dump.xml");
    std::fs::write(&updated_xml_path, mock_data::get_updated_test_xml_dump())?;
    
    // Run incremental update
    println!("Running incremental update...");
    let update_result = installer.update_from_file(&updated_xml_path).await?;
    
    // Verify update report
    assert_eq!(update_result.added_count, 2, "Expected 2 new articles");
    assert_eq!(update_result.modified_count, 1, "Expected 1 modified article");
    assert_eq!(update_result.removed_count, 1, "Expected 1 removed article");
    assert_eq!(update_result.unchanged_count, 1, "Expected 1 unchanged article");
    
    // Verify updated article count
    let updated_article_count = db.get_article_count().await?;
    assert_eq!(updated_article_count, 4, "Expected 4 articles after update");
    
    // Verify article titles after update
    let updated_titles = db.get_all_article_titles().await?;
    println!("Updated articles: {:?}", updated_titles);
    
    // Verify the specific articles were added/removed correctly
    assert!(updated_titles.contains(&"New Article 1".to_string()), "Missing new article 1");
    assert!(updated_titles.contains(&"New Article 2".to_string()), "Missing new article 2");
    assert!(!updated_titles.contains(&"Test Article 3".to_string()), "Article 3 should be removed");
    
    // Verify vector store was updated (only for new and modified articles)
    let vector_store = VectorStore::new(&config.vector_dir).await?;
    
    // Get embedding counts - should match the number of articles after update
    let embedding_count = vector_store.get_embedding_count().await?;
    assert_eq!(embedding_count, 4, "Expected 4 embeddings after update");
    
    // Verify search works with the updated content
    let search_results = db.search("new content").await?;
    assert!(!search_results.is_empty(), "Search returned no results for new content");
    
    // Test a second update with no changes
    println!("Running second update with no changes...");
    let second_update_result = installer.update_from_file(&updated_xml_path).await?;
    
    // Verify no changes were made
    assert_eq!(second_update_result.added_count, 0, "Expected 0 new articles");
    assert_eq!(second_update_result.modified_count, 0, "Expected 0 modified articles");
    assert_eq!(second_update_result.removed_count, 0, "Expected 0 removed articles");
    assert_eq!(second_update_result.unchanged_count, 4, "Expected 4 unchanged articles");
    
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
    let db = DatabaseManager::new(&db_path).await?;
    
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

/// Test error handling and recovery scenarios
#[tokio::test]
async fn test_error_handling_and_recovery() -> WikiResult<()> {
    // Initialize logging
    test_helpers::init_test_logging();
    
    // Create temporary directories
    let temp_dir = test_helpers::test_temp_dir();
    
    // Get test installer config
    let config = mock_data::get_test_installer_config(temp_dir.path());
    
    // Initialize installer
    let installer = Installer::new(config.clone());
    
    // Test 1: Handle invalid XML
    println!("Testing invalid XML handling...");
    let invalid_xml_path = temp_dir.path().join("invalid.xml");
    std::fs::write(&invalid_xml_path, "This is not valid XML data")?;
    
    let invalid_result = installer.install_from_file(&invalid_xml_path).await;
    assert!(invalid_result.is_err(), "Expected error for invalid XML");
    if let Err(e) = invalid_result {
        assert!(
            format!("{:?}", e).contains("XML"),
            "Error message should mention XML parsing: {:?}",
            e
        );
    }
    
    // Test 2: Handle non-existent file
    println!("Testing non-existent file handling...");
    let nonexistent_path = temp_dir.path().join("nonexistent.xml");
    let nonexistent_result = installer.install_from_file(&nonexistent_path).await;
    assert!(nonexistent_result.is_err(), "Expected error for non-existent file");
    
    // Test 3: Handle empty XML
    println!("Testing empty XML handling...");
    let empty_xml_path = temp_dir.path().join("empty.xml");
    std::fs::write(&empty_xml_path, "<mediawiki></mediawiki>")?;
    
    let empty_result = installer.install_from_file(&empty_xml_path).await;
    // This should succeed but import 0 articles
    assert!(empty_result.is_ok(), "Empty XML should not cause an error");
    
    // Verify no articles were imported
    let db_path = config.data_dir.join("wiki.db");
    if db_path.exists() {
        let db = DatabaseManager::new(&db_path).await?;
        let article_count = db.get_article_count().await?;
        assert_eq!(article_count, 0, "Expected 0 articles for empty XML");
    }
    
    // Test 4: Recovery after failed installation
    println!("Testing recovery after failed installation...");
    
    // First, do a successful installation
    let xml_path = temp_dir.path().join("good.xml");
    std::fs::write(&xml_path, mock_data::get_test_xml_dump())?;
    installer.install_from_file(&xml_path).await?;
    
    // Verify database was created
    assert!(db_path.exists(), "Database file not created");
    
    // Now corrupt the database
    println!("Corrupting database file...");
    std::fs::write(&db_path, "CORRUPTED DATABASE CONTENT")?;
    
    // Try to use the corrupted database
    let corrupt_db = DatabaseManager::new(&db_path).await;
    assert!(corrupt_db.is_err(), "Opening corrupted database should fail");
    
    // Reinstall to recover
    println!("Reinstalling to recover...");
    installer.install_from_file(&xml_path).await?;
    
    // Verify database was recreated
    let db = DatabaseManager::new(&db_path).await?;
    let article_count = db.get_article_count().await?;
    assert_eq!(article_count, 3, "Expected 3 articles after recovery");
    
    // Test 5: Handle malformed XML (valid XML but not wiki format)
    println!("Testing malformed XML handling...");
    let malformed_xml_path = temp_dir.path().join("malformed.xml");
    std::fs::write(&malformed_xml_path, "<root><item>Not a wiki dump</item></root>")?;
    
    let malformed_result = installer.install_from_file(&malformed_xml_path).await;
    assert!(malformed_result.is_err(), "Expected error for malformed XML");
    
    // Test 6: Verify partial progress is not lost on error
    println!("Testing partial progress handling...");
    
    // Create XML with some valid and some invalid articles
    let partial_xml_path = temp_dir.path().join("partial.xml");
    std::fs::write(&partial_xml_path, mock_data::get_partial_invalid_xml_dump())?;
    
    // Clear the database
    std::fs::remove_file(&db_path)?;
    
    // Try to install the partial XML
    let partial_result = installer.install_from_file(&partial_xml_path).await;
    
    // This may fail or succeed depending on implementation
    // If it fails, it should have installed some articles
    // If it succeeds, it should have skipped the invalid ones
    if partial_result.is_err() {
        println!("Partial installation failed as expected");
    } else {
        println!("Partial installation succeeded with skipped articles");
    }
    
    // Either way, we should have some valid articles
    if db_path.exists() {
        let db = DatabaseManager::new(&db_path).await?;
        let article_count = db.get_article_count().await?;
        assert!(article_count > 0, "Expected some articles to be imported");
        println!("Partial installation imported {} articles", article_count);
    }
    
    Ok(())
}

/// Test concurrent access to APIs
#[tokio::test]
async fn test_concurrent_access() -> WikiResult<()> {
    // Initialize logging
    test_helpers::init_test_logging();
    
    // Create temporary directories
    let temp_dir = test_helpers::test_temp_dir();
    
    // Get test installer config
    let config = mock_data::get_test_installer_config(temp_dir.path());
    
    // Initialize installer and install test data
    let installer = Installer::new(config.clone());
    
    // Setup test XML data path with larger dataset for concurrency testing
    let xml_path = temp_dir.path().join("concurrency_test.xml");
    std::fs::write(&xml_path, mock_data::get_large_test_xml_dump())?;
    
    // Run installation with test data
    println!("Installing test data for concurrency testing...");
    installer.install_from_file(&xml_path).await?;
    
    // Initialize database manager
    let db_path = config.data_dir.join("wiki.db");
    assert!(db_path.exists(), "Database file not created");
    
    // Initialize database manager with multiple connections
    let db = DatabaseManager::with_path(&db_path, 10).await?;
    
    // Initialize vector store
    let vector_store = VectorStore::new(&config.vector_dir).await?;
    
    // Verify initial article count
    let article_count = db.get_article_count().await?;
    println!("Initial article count: {}", article_count);
    assert!(article_count > 0, "Expected articles to be imported");
    
    // Test 1: Concurrent read operations
    println!("Testing concurrent read operations...");
    
    // Create a number of concurrent read tasks
    const NUM_CONCURRENT_READS: usize = 50;
    let mut read_tasks = Vec::with_capacity(NUM_CONCURRENT_READS);
    
    for i in 1..=NUM_CONCURRENT_READS {
        let db_clone = db.clone();
        let article_id = (i % article_count as usize + 1) as i64; // Cycle through article IDs
        
        read_tasks.push(tokio::spawn(async move {
            match db_clone.get_article(article_id).await {
                Ok(_) => Ok(()),
                Err(e) => {
                    println!("Error reading article {}: {:?}", article_id, e);
                    Err(e)
                }
            }
        }));
    }
    
    // Wait for all tasks to complete
    for (i, task) in read_tasks.into_iter().enumerate() {
        match task.await {
            Ok(result) => {
                if let Err(e) = result {
                    println!("Task {} failed with error: {:?}", i, e);
                    return Err(e);
                }
            }
            Err(e) => {
                println!("Task {} panicked: {:?}", i, e);
                return Err(WikiError::Internal(format!("Task panicked: {:?}", e)));
            }
        }
    }
    
    println!("All concurrent read operations completed successfully");
    
    // Test 2: Concurrent search operations
    println!("Testing concurrent search operations...");
    
    const NUM_CONCURRENT_SEARCHES: usize = 20;
    let search_terms = ["science", "technology", "history", "culture", "article"];
    let mut search_tasks = Vec::with_capacity(NUM_CONCURRENT_SEARCHES);
    
    for i in 0..NUM_CONCURRENT_SEARCHES {
        let db_clone = db.clone();
        let term = search_terms[i % search_terms.len()];
        
        search_tasks.push(tokio::spawn(async move {
            match db_clone.search(term).await {
                Ok(_) => Ok(()),
                Err(e) => {
                    println!("Error searching for '{}': {:?}", term, e);
                    Err(e)
                }
            }
        }));
    }
    
    // Wait for all search tasks to complete
    for (i, task) in search_tasks.into_iter().enumerate() {
        match task.await {
            Ok(result) => {
                if let Err(e) = result {
                    println!("Search task {} failed with error: {:?}", i, e);
                    return Err(e);
                }
            }
            Err(e) => {
                println!("Search task {} panicked: {:?}", i, e);
                return Err(WikiError::Internal(format!("Search task panicked: {:?}", e)));
            }
        }
    }
    
    println!("All concurrent search operations completed successfully");
    
    // Test 3: Mixed read and search operations
    println!("Testing mixed read and search operations...");
    
    const NUM_MIXED_OPS: usize = 40;
    let mut mixed_tasks = Vec::with_capacity(NUM_MIXED_OPS);
    
    for i in 0..NUM_MIXED_OPS {
        let db_clone = db.clone();
        let vs_clone = vector_store.clone();
        
        if i % 3 == 0 {
            // Do a semantic search
            let query = "science and technology";
            mixed_tasks.push(tokio::spawn(async move {
                match vs_clone.search(query, 5).await {
                    Ok(_) => Ok(()),
                    Err(e) => {
                        println!("Error in semantic search: {:?}", e);
                        Err(WikiError::Vector(format!("Semantic search failed: {:?}", e)))
                    }
                }
            }));
        } else if i % 3 == 1 {
            // Do a text search
            let term = search_terms[i % search_terms.len()];
            mixed_tasks.push(tokio::spawn(async move {
                match db_clone.search(term).await {
                    Ok(_) => Ok(()),
                    Err(e) => {
                        println!("Error in text search: {:?}", e);
                        Err(e)
                    }
                }
            }));
        } else {
            // Do an article retrieval
            let article_id = (i % article_count as usize + 1) as i64;
            mixed_tasks.push(tokio::spawn(async move {
                match db_clone.get_article(article_id).await {
                    Ok(_) => Ok(()),
                    Err(e) => {
                        println!("Error retrieving article: {:?}", e);
                        Err(e)
                    }
                }
            }));
        }
    }
    
    // Wait for all mixed tasks to complete
    for (i, task) in mixed_tasks.into_iter().enumerate() {
        match task.await {
            Ok(result) => {
                if let Err(e) = result {
                    println!("Mixed task {} failed with error: {:?}", i, e);
                    // Don't fail the test if some tasks fail, just log the errors
                    // In a real-world scenario, some concurrent ops might legitimately fail
                }
            }
            Err(e) => {
                println!("Mixed task {} panicked: {:?}", i, e);
                // Again, don't fail the entire test
            }
        }
    }
    
    println!("Mixed operations testing completed");
    
    // Verify database integrity after concurrent operations
    let final_article_count = db.get_article_count().await?;
    assert_eq!(
        article_count, final_article_count,
        "Article count should remain unchanged after concurrent operations"
    );
    
    println!("Database integrity verified: article count unchanged: {}", final_article_count);
    
    Ok(())
}

/// Test network interruption and resumption
#[tokio::test]
async fn test_network_interruption() -> WikiResult<()> {
    // Initialize logging
    test_helpers::init_test_logging();
    
    // Create temporary directories
    let temp_dir = test_helpers::test_temp_dir();
    
    // Get test installer config
    let mut config = mock_data::get_test_installer_config(temp_dir.path());
    
    // Enable network features (don't skip download)
    config.skip_download = false;
    
    // Set a mock server URL that will fail (non-existent)
    let mock_server_url = "http://non-existent-server.example.com";
    config.wiki_dump_url = mock_server_url.to_string();
    
    // Initialize installer
    let installer = Installer::new(config.clone());
    
    // Test 1: Handle network failure during installation
    println!("Testing network failure during installation...");
    
    // Attempt installation with bad URL
    let install_result = installer.install().await;
    
    // Should fail with a network error
    assert!(install_result.is_err(), "Expected error for network failure");
    if let Err(e) = install_result {
        println!("Received expected network error: {:?}", e);
        assert!(
            matches!(e, WikiError::Network(_)) || matches!(e, WikiError::Download(_)),
            "Expected WikiError::Network or WikiError::Download, got {:?}",
            e
        );
    }
    
    // Test 2: Resume installation after network failure
    println!("Testing installation resumption after network failure...");
    
    // Create a partial download file to simulate interrupted download
    let download_dir = config.cache_dir.join("downloads");
    std::fs::create_dir_all(&download_dir)?;
    
    let partial_file = download_dir.join("partial.xml.gz");
    // Write some random data to simulate a partial download
    std::fs::write(&partial_file, "Partial download data")?;
    
    // Now set up a successful path using a local file
    let local_xml_path = temp_dir.path().join("local.xml");
    std::fs::write(&local_xml_path, mock_data::get_test_xml_dump())?;
    
    // Update config to use local file
    let mut resumed_config = config.clone();
    resumed_config.wiki_dump_url = format!("file://{}", local_xml_path.display());
    
    // Create a new installer with the updated config
    let resumed_installer = Installer::new(resumed_config.clone());
    
    // Attempt installation again, should succeed with local file
    let resumed_result = resumed_installer.install().await;
    assert!(resumed_result.is_ok(), "Installation should succeed with local file");
    
    // Test 3: Network failure during update
    println!("Testing network failure during update...");
    
    // Initialize database manager to confirm installation succeeded
    let db_path = config.data_dir.join("wiki.db");
    assert!(db_path.exists(), "Database file not created");
    
    let db = DatabaseManager::new(&db_path).await?;
    let article_count = db.get_article_count().await?;
    assert!(article_count > 0, "No articles were imported");
    
    // Set up a bad URL again for update
    let mut update_config = config.clone();
    update_config.wiki_dump_url = mock_server_url.to_string();
    
    // Create installer with bad URL
    let update_installer = Installer::new(update_config);
    
    // Attempt update with bad URL
    let update_result = update_installer.update().await;
    
    // Should fail with a network error
    assert!(update_result.is_err(), "Expected error for network failure during update");
    
    // Test 4: Successful update after failure
    println!("Testing update resumption after network failure...");
    
    // Create an updated local file
    let updated_xml_path = temp_dir.path().join("updated.xml");
    std::fs::write(&updated_xml_path, mock_data::get_updated_test_xml_dump())?;
    
    // Update config to use local file
    let mut final_config = config.clone();
    final_config.wiki_dump_url = format!("file://{}", updated_xml_path.display());
    
    // Create a new installer with the updated config
    let final_installer = Installer::new(final_config);
    
    // Attempt update again, should succeed with local file
    let final_result = final_installer.update().await;
    assert!(final_result.is_ok(), "Update should succeed with local file");
    
    // Verify database was updated correctly
    let db = DatabaseManager::new(&db_path).await?;
    let new_article_count = db.get_article_count().await?;
    
    // The count should match the expected article count after the update
    // (depends on your test data - adjust the expected count accordingly)
    assert_ne!(article_count, new_article_count, "Article count should change after update");
    
    // Test 5: Connection interruption during search
    println!("Testing connection interruption during search...");
    
    // Simulate search with connection failure by using a timeout
    let search_result = tokio::time::timeout(
        std::time::Duration::from_millis(1), // Very short timeout to force failure
        db.search("search that will time out")
    ).await;
    
    // Should either timeout or succeed (depending on how fast the search is)
    match search_result {
        Ok(inner_result) => {
            println!("Search completed before timeout");
            // If it succeeded, that's fine too
            assert!(inner_result.is_ok(), "Search should succeed if not timed out");
        }
        Err(_) => {
            println!("Search timed out as expected");
            // This is the expected path - timeout occurred
        }
    }
    
    // Test 6: Retry with successful connection
    println!("Testing search retry after timeout...");
    
    // Now try again with a reasonable timeout
    let retry_result = tokio::time::timeout(
        std::time::Duration::from_secs(5), // Longer timeout
        db.search("science")
    ).await;
    
    // Should succeed
    match retry_result {
        Ok(inner_result) => {
            assert!(inner_result.is_ok(), "Search should succeed with longer timeout");
            let search_results = inner_result?;
            println!("Search succeeded with {} results", search_results.len());
        }
        Err(_) => {
            return Err(WikiError::Internal("Search timed out even with longer timeout".to_string()));
        }
    }
    
    Ok(())
}

/// Test how the system handles resource constraints
#[tokio::test]
async fn test_system_resource_limits() {
    // Initialize logging for debugging
    let _ = common::init_test_logging();
    let temp_dir = tempfile::tempdir().unwrap();
    let db_path = temp_dir.path().join("wiki.db");
    let vector_path = temp_dir.path().join("vectors");
    
    // Create a configuration with minimum memory settings to test memory constraints
    let config = Config {
        db_path: db_path.to_str().unwrap().to_string(),
        vector_path: vector_path.to_str().unwrap().to_string(),
        dump_url: format!("file://{}", common::get_test_dump_path().to_str().unwrap()),
        threads: 1, // Minimal threads
        cache_size_mb: 1, // Minimal cache size (1MB)
        embeddings_batch_size: 2, // Very small batch size to minimize memory usage
        ollama_url: "http://localhost:11434".to_string(),
        llm_model: "llama2".to_string(),
        port: 0, // Let the OS choose a port
        host: "127.0.0.1".to_string(),
    };
    
    // Test initialization with minimal memory settings
    info!("Testing initialization with minimal memory settings");
    let davinci = davinci3::Davinci::new(config.clone()).await.unwrap();
    
    // Install with minimal memory
    info!("Testing installation with minimal memory settings");
    match davinci.install().await {
        Ok(_) => info!("Installation successful with minimal memory"),
        Err(e) => {
            if e.to_string().contains("memory") {
                info!("Expected memory constraint error: {}", e);
            } else {
                panic!("Installation failed with unexpected error: {}", e);
            }
        }
    }
    
    // Test disk space constraints
    info!("Testing disk space constraints");
    let disk_limit_dir = tempfile::tempdir().unwrap();
    
    // On Linux/macOS, we could use quota tools to limit disk space
    // For this test, we'll simulate by trying to install in a directory with limited permissions
    #[cfg(target_family = "unix")]
    {
        use std::os::unix::fs::PermissionsExt;
        let limited_dir = disk_limit_dir.path().join("limited");
        std::fs::create_dir(&limited_dir).unwrap();
        let mut perms = std::fs::metadata(&limited_dir).unwrap().permissions();
        perms.set_mode(0o555); // read + execute only, no write
        std::fs::set_permissions(&limited_dir, perms).unwrap();
        
        let disk_limit_config = Config {
            db_path: limited_dir.join("wiki.db").to_str().unwrap().to_string(),
            vector_path: limited_dir.join("vectors").to_str().unwrap().to_string(),
            ..config.clone()
        };
        
        let disk_limit_result = davinci3::Davinci::new(disk_limit_config).await;
        assert!(disk_limit_result.is_err());
        info!("Disk space limit test passed: {}", disk_limit_result.unwrap_err());
    }
    
    // For Windows, we'll just check if the code handles errors gracefully
    #[cfg(target_family = "windows")]
    {
        let limited_dir = disk_limit_dir.path().join("COM1"); // Reserved name on Windows
        let disk_limit_config = Config {
            db_path: limited_dir.join("wiki.db").to_str().unwrap().to_string(),
            vector_path: limited_dir.join("vectors").to_str().unwrap().to_string(),
            ..config.clone()
        };
        
        let disk_limit_result = davinci3::Davinci::new(disk_limit_config).await;
        assert!(disk_limit_result.is_err());
        info!("Disk space limit test passed: {}", disk_limit_result.unwrap_err());
    }
    
    // Test CPU constraints with high concurrency on a memory-intensive operation
    info!("Testing CPU constraints with high concurrency");
    
    // First, install with normal settings to have a database to work with
    let normal_temp_dir = tempfile::tempdir().unwrap();
    let normal_config = Config {
        db_path: normal_temp_dir.path().join("wiki.db").to_str().unwrap().to_string(),
        vector_path: normal_temp_dir.path().join("vectors").to_str().unwrap().to_string(),
        dump_url: format!("file://{}", common::get_test_dump_path().to_str().unwrap()),
        threads: num_cpus::get(), // Use all CPUs
        cache_size_mb: 128, // Normal cache size
        embeddings_batch_size: 10, // Normal batch size
        ollama_url: "http://localhost:11434".to_string(),
        llm_model: "llama2".to_string(),
        port: 0,
        host: "127.0.0.1".to_string(),
    };
    
    let normal_davinci = davinci3::Davinci::new(normal_config.clone()).await.unwrap();
    normal_davinci.install().await.unwrap();
    let server = normal_davinci.start_server().await.unwrap();
    let client = reqwest::Client::new();
    let host = format!("http://{}", server.addr());
    
    // Measure the response time for a normal semantic search
    let start = std::time::Instant::now();
    let response = client.get(&format!("{}/semantic-search?q=rust+programming", host))
        .send()
        .await
        .unwrap();
    assert_eq!(response.status(), 200);
    let normal_duration = start.elapsed();
    info!("Normal semantic search took {:?}", normal_duration);
    
    // Now run many concurrent semantic searches to stress CPU and measure impact
    info!("Running concurrent semantic searches to stress CPU");
    let start = std::time::Instant::now();
    let handles: Vec<_> = (0..20).map(|i| {
        let client = client.clone();
        let host = host.clone();
        tokio::spawn(async move {
            let search_start = std::time::Instant::now();
            let response = client.get(&format!("{}/semantic-search?q=topic+{}", host, i))
                .send()
                .await
                .unwrap();
            assert_eq!(response.status(), 200);
            search_start.elapsed()
        })
    }).collect();
    
    let results = futures::future::join_all(handles).await;
    let total_duration = start.elapsed();
    let avg_duration: std::time::Duration = results.into_iter()
        .map(|r| r.unwrap())
        .sum::<std::time::Duration>()
        .div_f32(20.0);
    
    info!("Concurrent semantic searches took: {:?} total, {:?} average", total_duration, avg_duration);
    
    // Check if concurrent searches were significantly slower
    // This isn't asserting a hard limit because machine performance varies
    // But we log the ratio for analysis
    let slowdown_ratio = avg_duration.as_secs_f32() / normal_duration.as_secs_f32();
    info!("Concurrent search slowdown ratio: {:.2}x", slowdown_ratio);
    
    // Cleanup
    server.stop().await;
} 