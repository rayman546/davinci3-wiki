use davinci3_wiki::{
    error_handling::WikiResult,
    vector::VectorStore,
};
use tempfile::TempDir;
use std::path::Path;

#[tokio::test]
async fn test_vector_store_init() -> WikiResult<()> {
    // Create a temporary directory for vector store
    let temp_dir = TempDir::new()?;
    let vector_path = temp_dir.path();
    
    // Initialize vector store
    let vector_store = VectorStore::new(vector_path, "http://localhost:11434").await?;
    
    // Verify the vector store was initialized
    assert!(vector_path.exists());
    
    Ok(())
}

#[tokio::test]
async fn test_vector_store_simple_operations() -> WikiResult<()> {
    // Skip this test if Ollama is not available
    // This is an integration test that requires Ollama to be running
    match tokio::process::Command::new("ollama")
        .arg("--version")
        .output()
        .await {
        Ok(_) => {}, // Ollama is installed, continue with the test
        Err(_) => {
            println!("Skipping test_vector_store_simple_operations because Ollama is not installed");
            return Ok(());
        }
    }
    
    // Create a temporary directory for vector store
    let temp_dir = TempDir::new()?;
    let vector_path = temp_dir.path();
    
    // Initialize vector store
    let vector_store = VectorStore::new(vector_path, "http://localhost:11434").await?;
    
    // Test storing and retrieving embeddings
    let test_id = "test_id";
    let test_text = "This is a test text for generating embeddings.";
    
    // Generate embedding
    let embedding = vector_store.generate_embedding(test_text).await?;
    
    // Verify embedding is the right size
    assert_eq!(embedding.data.len(), vector_store.vector_size());
    
    // Store embedding
    vector_store.store_embedding(test_id, &embedding).await?;
    
    // Retrieve embedding
    let retrieved_embedding = vector_store.get_embedding(test_id).await?;
    
    // Verify retrieved embedding matches original
    assert_eq!(embedding.data.len(), retrieved_embedding.data.len());
    for (a, b) in embedding.data.iter().zip(retrieved_embedding.data.iter()) {
        assert!((a - b).abs() < 1e-6);
    }
    
    Ok(())
}

#[tokio::test]
async fn test_vector_store_find_similar() -> WikiResult<()> {
    // Skip this test if Ollama is not available
    match tokio::process::Command::new("ollama")
        .arg("--version")
        .output()
        .await {
        Ok(_) => {}, // Ollama is installed, continue with the test
        Err(_) => {
            println!("Skipping test_vector_store_find_similar because Ollama is not installed");
            return Ok(());
        }
    }
    
    // Create a temporary directory for vector store
    let temp_dir = TempDir::new()?;
    let vector_path = temp_dir.path();
    
    // Initialize vector store
    let vector_store = VectorStore::new(vector_path, "http://localhost:11434").await?;
    
    // Create test data
    let texts = vec![
        "Rust is a systems programming language focused on safety and performance.",
        "Python is a high-level programming language known for its readability.",
        "JavaScript is a scripting language used primarily for web development.",
        "C++ is a general-purpose programming language with a bias toward systems programming.",
        "Go is a statically typed, compiled language designed at Google.",
    ];
    
    let ids = vec!["rust", "python", "javascript", "cpp", "go"];
    
    // Generate and store embeddings for all texts
    for (id, text) in ids.iter().zip(texts.iter()) {
        let embedding = vector_store.generate_embedding(text).await?;
        vector_store.store_embedding(id, &embedding).await?;
    }
    
    // Test similarity search
    let query = "Which programming language is best for systems programming?";
    let query_embedding = vector_store.generate_embedding(query).await?;
    
    let similar = vector_store.find_similar(&query_embedding, 2).await?;
    
    // We expect Rust and C++ to be most similar to the query
    assert_eq!(similar.len(), 2);
    
    // Check if the results contain the expected IDs (order may vary)
    let result_ids: Vec<&str> = similar.iter().map(|r| r.id.as_str()).collect();
    assert!(result_ids.contains(&"rust") || result_ids.contains(&"cpp"));
    
    Ok(())
}

#[tokio::test]
async fn test_vector_store_batch_operations() -> WikiResult<()> {
    // Skip this test if Ollama is not available
    match tokio::process::Command::new("ollama")
        .arg("--version")
        .output()
        .await {
        Ok(_) => {}, // Ollama is installed, continue with the test
        Err(_) => {
            println!("Skipping test_vector_store_batch_operations because Ollama is not installed");
            return Ok(());
        }
    }
    
    // Create a temporary directory for vector store
    let temp_dir = TempDir::new()?;
    let vector_path = temp_dir.path();
    
    // Initialize vector store
    let vector_store = VectorStore::new(vector_path, "http://localhost:11434").await?;
    
    // Create batch of texts
    let texts: Vec<String> = (1..=10).map(|i| format!("This is test text number {}.", i)).collect();
    
    // Generate embeddings in batch
    let embeddings = vector_store.generate_embeddings_batch(&texts).await?;
    
    // Verify we got the right number of embeddings
    assert_eq!(embeddings.len(), texts.len());
    
    // Store all embeddings
    for (i, embedding) in embeddings.iter().enumerate() {
        vector_store.store_embedding(&format!("batch_{}", i), embedding).await?;
    }
    
    // Retrieve and verify all embeddings
    for i in 0..texts.len() {
        let id = format!("batch_{}", i);
        let retrieved = vector_store.get_embedding(&id).await?;
        assert_eq!(retrieved.data.len(), vector_store.vector_size());
    }
    
    Ok(())
} 