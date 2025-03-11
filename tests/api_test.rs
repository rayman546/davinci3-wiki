mod common;

use common::{test_helpers, mock_data};
use davinci3_wiki::{
    error_handling::WikiResult,
    api::{ApiServer, ApiConfig},
    db::DbManager,
    vector::VectorStore,
    llm::LlmClient,
};
use std::path::PathBuf;
use reqwest::Client;
use tokio::time::{sleep, Duration};
use serde_json::Value;

/// Setup test API server
async fn setup_test_api(port: u16) -> WikiResult<(ApiServer, PathBuf, tempfile::TempDir)> {
    // Initialize logging
    test_helpers::init_test_logging();
    
    // Create temporary directory
    let temp_dir = test_helpers::test_temp_dir();
    
    // Create database with test data
    let db_path = temp_dir.path().join("test_api.db");
    let db = DbManager::new(&db_path).await?;
    db.init_schema().await?;
    
    // Insert test articles
    for article in mock_data::get_test_articles() {
        db.insert_article(&article).await?;
    }
    
    // Setup vector store
    let vector_path = temp_dir.path().join("vectors");
    std::fs::create_dir_all(&vector_path)?;
    let vector_store = VectorStore::new(&vector_path).await?;
    
    // Insert test vectors
    for (id, vector) in mock_data::get_test_vectors() {
        vector_store.insert(id, &vector).await?;
    }
    
    // Configure API
    let api_config = ApiConfig {
        port,
        host: "127.0.0.1".to_string(),
        db_path: db_path.clone(),
        vector_path: vector_path.clone(),
        ollama_url: "http://localhost:11434".to_string(),
    };
    
    // Start API server
    let server = ApiServer::new(api_config).await?;
    
    Ok((server, db_path, temp_dir))
}

/// Test basic API endpoints
#[tokio::test]
async fn test_api_article_endpoints() -> WikiResult<()> {
    // Setup API server on random port
    let port = 8081;
    let (server_handle, db_path, _temp_dir) = setup_test_api(port).await?;
    
    // Start server in background
    let server = server_handle.start();
    tokio::spawn(server);
    
    // Wait for server to start
    sleep(Duration::from_secs(1)).await;
    
    // Create HTTP client
    let client = Client::new();
    let base_url = format!("http://127.0.0.1:{}", port);
    
    // Test status endpoint
    let response = client.get(&format!("{}/status", base_url))
        .send()
        .await?;
    
    assert_eq!(response.status().as_u16(), 200);
    let status: Value = response.json().await?;
    assert_eq!(status["status"], "running");
    
    // Test articles list endpoint
    let response = client.get(&format!("{}/articles", base_url))
        .send()
        .await?;
    
    assert_eq!(response.status().as_u16(), 200);
    let articles: Value = response.json().await?;
    assert_eq!(articles["total"].as_i64().unwrap(), 5);
    assert!(!articles["articles"].as_array().unwrap().is_empty());
    
    // Test single article endpoint
    let response = client.get(&format!("{}/articles/1", base_url))
        .send()
        .await?;
    
    assert_eq!(response.status().as_u16(), 200);
    let article: Value = response.json().await?;
    assert!(article["title"].as_str().unwrap().contains("Test Article"));
    
    // Test search endpoint
    let response = client.get(&format!("{}/search?q=science", base_url))
        .send()
        .await?;
    
    assert_eq!(response.status().as_u16(), 200);
    let search_results: Value = response.json().await?;
    assert!(search_results["total"].as_i64().unwrap() > 0);
    
    // Test 404 on non-existent article
    let response = client.get(&format!("{}/articles/999", base_url))
        .send()
        .await?;
    
    assert_eq!(response.status().as_u16(), 404);
    
    Ok(())
}

/// Test semantic search API endpoint
#[tokio::test]
async fn test_api_semantic_search() -> WikiResult<()> {
    // Setup API server on random port
    let port = 8082;
    let (server_handle, db_path, _temp_dir) = setup_test_api(port).await?;
    
    // Start server in background
    let server = server_handle.start();
    tokio::spawn(server);
    
    // Wait for server to start
    sleep(Duration::from_secs(1)).await;
    
    // Create HTTP client
    let client = Client::new();
    let base_url = format!("http://127.0.0.1:{}", port);
    
    // Test semantic search endpoint
    let response = client.get(&format!("{}/semantic-search?q=scientific%20knowledge", base_url))
        .send()
        .await?;
    
    assert_eq!(response.status().as_u16(), 200);
    let search_results: Value = response.json().await?;
    assert!(search_results["results"].as_array().unwrap().len() > 0);
    
    Ok(())
}

/// Test LLM integration API endpoints
#[tokio::test]
async fn test_api_llm_endpoints() -> WikiResult<()> {
    // Skip the test if Ollama is not available
    if test_helpers::skip_if_ollama_unavailable().await {
        return Ok(());
    }
    
    // Setup API server on random port
    let port = 8083;
    let (server_handle, db_path, _temp_dir) = setup_test_api(port).await?;
    
    // Start server in background
    let server = server_handle.start();
    tokio::spawn(server);
    
    // Wait for server to start
    sleep(Duration::from_secs(1)).await;
    
    // Create HTTP client
    let client = Client::new();
    let base_url = format!("http://127.0.0.1:{}", port);
    
    // Test article summary endpoint
    let summary_response = test_helpers::with_timeout(10, async {
        client.get(&format!("{}/articles/1/summary", base_url))
            .send()
            .await
    }).await;
    
    if let Ok(response) = summary_response {
        let response = response?;
        assert_eq!(response.status().as_u16(), 200);
        let summary: Value = response.json().await?;
        assert!(summary["summary"].as_str().is_some());
    } else {
        println!("Skipping LLM test due to timeout");
    }
    
    // Test article question endpoint
    let question_response = test_helpers::with_timeout(10, async {
        client.get(&format!("{}/articles/1/ask?q=What%20is%20this%20article%20about?", base_url))
            .send()
            .await
    }).await;
    
    if let Ok(response) = question_response {
        let response = response?;
        assert_eq!(response.status().as_u16(), 200);
        let answer: Value = response.json().await?;
        assert!(answer["answer"].as_str().is_some());
    } else {
        println!("Skipping LLM question test due to timeout");
    }
    
    Ok(())
}

/// Test API error handling
#[tokio::test]
async fn test_api_error_handling() -> WikiResult<()> {
    // Setup API server on random port
    let port = 8084;
    let (server_handle, db_path, _temp_dir) = setup_test_api(port).await?;
    
    // Start server in background
    let server = server_handle.start();
    tokio::spawn(server);
    
    // Wait for server to start
    sleep(Duration::from_secs(1)).await;
    
    // Create HTTP client
    let client = Client::new();
    let base_url = format!("http://127.0.0.1:{}", port);
    
    // Test invalid search query (too short)
    let response = client.get(&format!("{}/search?q=a", base_url))
        .send()
        .await?;
    
    assert_eq!(response.status().as_u16(), 400);
    let error: Value = response.json().await?;
    assert!(error["error"]["message"].as_str().unwrap().contains("too short"));
    
    // Test invalid page parameter
    let response = client.get(&format!("{}/articles?page=invalid", base_url))
        .send()
        .await?;
    
    assert_eq!(response.status().as_u16(), 400);
    let error: Value = response.json().await?;
    assert!(error["error"]["message"].as_str().unwrap().contains("Invalid page"));
    
    // Test non-existing endpoint
    let response = client.get(&format!("{}/nonexistent", base_url))
        .send()
        .await?;
    
    assert_eq!(response.status().as_u16(), 404);
    
    Ok(())
} 