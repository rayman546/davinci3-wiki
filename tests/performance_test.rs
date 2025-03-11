mod common;

use common::{test_helpers, mock_data};
use davinci3_wiki::{
    error_handling::WikiResult,
    db::DbManager,
    vector::VectorStore,
    parser::XmlParser,
};
use std::time::{Instant, Duration};
use std::path::PathBuf;
use std::io::Cursor;
use tokio::time::timeout;
use tempfile::TempDir;

/// Test database search performance with increasingly large datasets
#[tokio::test]
async fn test_search_performance_scaling() -> WikiResult<()> {
    // Initialize logging
    test_helpers::init_test_logging();
    
    // Create temporary directory
    let temp_dir = test_helpers::test_temp_dir();
    let db_path = temp_dir.path().join("perf_test.db");
    
    // Initialize database
    let db = DbManager::new(&db_path).await?;
    db.init_schema().await?;
    
    // Dataset sizes to test
    let sizes = [100, 500, 1000, 5000];
    let mut search_times = Vec::new();
    
    for size in sizes {
        println!("Testing search performance with {} articles", size);
        
        // Generate and insert articles
        for i in 1..=size {
            let article = generate_test_article(i);
            db.insert_article(&article).await?;
        }
        
        // Run search multiple times to get average
        let mut times = Vec::new();
        for _ in 0..5 {
            let start = Instant::now();
            let _ = db.search("science technology").await?;
            times.push(start.elapsed());
        }
        
        // Calculate average
        let avg_time = times.iter().sum::<Duration>() / times.len() as u32;
        search_times.push((size, avg_time));
        
        println!("Average search time for {} articles: {:?}", size, avg_time);
        
        // Check against performance requirement
        assert!(
            avg_time < Duration::from_millis(500),
            "Search time exceeds 500ms with {} articles: {:?}",
            size,
            avg_time
        );
    }
    
    Ok(())
}

/// Test vector store performance with increasingly large datasets
#[tokio::test]
async fn test_vector_store_performance_scaling() -> WikiResult<()> {
    // Initialize logging
    test_helpers::init_test_logging();
    
    // Create temporary directory
    let temp_dir = test_helpers::test_temp_dir();
    let vector_path = temp_dir.path().join("perf_vectors");
    std::fs::create_dir_all(&vector_path)?;
    
    // Initialize vector store
    let store = VectorStore::new(&vector_path).await?;
    
    // Dataset sizes to test
    let sizes = [100, 500, 1000, 5000];
    let mut search_times = Vec::new();
    
    // Vector dimension
    let dim = 384; // Using a common embedding dimension
    
    for size in sizes {
        println!("Testing vector search performance with {} vectors", size);
        
        // Generate and insert vectors
        for i in 1..=size {
            let vector = generate_test_vector(i, dim);
            store.insert(i as u64, &vector).await?;
        }
        
        // Create query vector
        let query = generate_test_vector(0, dim);
        
        // Run search multiple times to get average
        let mut times = Vec::new();
        for _ in 0..5 {
            let start = Instant::now();
            let _ = store.find_similar(&query, 10).await?;
            times.push(start.elapsed());
        }
        
        // Calculate average
        let avg_time = times.iter().sum::<Duration>() / times.len() as u32;
        search_times.push((size, avg_time));
        
        println!("Average vector search time for {} vectors: {:?}", size, avg_time);
        
        // Check against performance requirement
        assert!(
            avg_time < Duration::from_millis(500),
            "Vector search time exceeds 500ms with {} vectors: {:?}",
            size,
            avg_time
        );
    }
    
    Ok(())
}

/// Test XML parsing performance with large dumps
#[tokio::test]
async fn test_xml_parsing_performance() -> WikiResult<()> {
    // Initialize logging
    test_helpers::init_test_logging();
    
    // Create temporary directory
    let temp_dir = test_helpers::test_temp_dir();
    
    // Generate a large XML dump
    let large_xml = generate_large_xml_dump(10000);
    
    // Initialize parser
    let parser = XmlParser::new();
    
    // Measure parsing time
    let start = Instant::now();
    let reader = Cursor::new(large_xml);
    let articles = parser.parse(reader, |_| true).await?;
    let parse_time = start.elapsed();
    
    println!("Parsed {} articles in {:?}", articles.len(), parse_time);
    
    // Calculate parsing rate (articles per second)
    let articles_per_second = articles.len() as f64 / parse_time.as_secs_f64();
    println!("Parsing rate: {:.2} articles/second", articles_per_second);
    
    // Assert reasonable performance
    assert!(
        articles_per_second > 100.0,
        "Parsing rate below 100 articles/second: {:.2}",
        articles_per_second
    );
    
    Ok(())
}

/// Test memory usage during large operations
#[tokio::test]
async fn test_memory_usage() -> WikiResult<()> {
    // Initialize logging
    test_helpers::init_test_logging();
    
    // Create temporary directory
    let temp_dir = test_helpers::test_temp_dir();
    let db_path = temp_dir.path().join("memory_test.db");
    
    // Initialize database
    let db = DbManager::new(&db_path).await?;
    db.init_schema().await?;
    
    // Generate and insert a large number of articles in batches
    let batch_size = 1000;
    let total_articles = 10000;
    
    println!("Inserting {} articles in batches of {}", total_articles, batch_size);
    
    for batch in 0..(total_articles / batch_size) {
        let start_id = batch * batch_size + 1;
        let end_id = (batch + 1) * batch_size;
        
        let start = Instant::now();
        
        // Begin transaction for batch insert
        db.begin_transaction().await?;
        
        for i in start_id..=end_id {
            let article = generate_test_article(i);
            db.insert_article_in_transaction(&article).await?;
        }
        
        // Commit transaction
        db.commit_transaction().await?;
        
        let batch_time = start.elapsed();
        println!(
            "Batch {}/{} ({}-{}) inserted in {:?}",
            batch + 1,
            total_articles / batch_size,
            start_id,
            end_id,
            batch_time
        );
    }
    
    // Test search performance after bulk insert
    let start = Instant::now();
    let results = db.search("science technology").await?;
    let search_time = start.elapsed();
    
    println!(
        "Search after bulk insert: found {} results in {:?}",
        results.len(),
        search_time
    );
    
    // Assert search still meets performance requirements
    assert!(
        search_time < Duration::from_millis(500),
        "Search time after bulk insert exceeds 500ms: {:?}",
        search_time
    );
    
    Ok(())
}

// Helper function to generate test articles with unique content
fn generate_test_article(id: usize) -> davinci3_wiki::parser::Article {
    let categories = match id % 5 {
        0 => vec!["Science".to_string(), "Physics".to_string()],
        1 => vec!["Technology".to_string(), "Computing".to_string()],
        2 => vec!["History".to_string(), "Medieval".to_string()],
        3 => vec!["Geography".to_string(), "Europe".to_string()],
        _ => vec!["Culture".to_string(), "Literature".to_string()],
    };
    
    davinci3_wiki::parser::Article {
        id: None,
        title: format!("Performance Test Article {}", id),
        content: format!(
            "This is test article {} with content related to {} and {}. \
            It contains various keywords for search testing including science, \
            technology, research, physics, computing, and other terms. \
            This article is generated for performance testing purposes to benchmark \
            the search and retrieval capabilities of the system with \
            large datasets of varying sizes.",
            id, categories[0], categories[1]
        ),
        categories,
    }
}

// Helper function to generate test vectors
fn generate_test_vector(id: usize, dim: usize) -> Vec<f32> {
    let mut vector = Vec::with_capacity(dim);
    let base = (id % 100) as f32 / 100.0;
    
    for i in 0..dim {
        let val = (base + (i as f32 / dim as f32)) % 1.0;
        vector.push(val);
    }
    
    // Normalize vector
    let magnitude = vector.iter().map(|x| x * x).sum::<f32>().sqrt();
    vector.iter_mut().for_each(|x| *x /= magnitude);
    
    vector
}

// Helper function to generate a large XML dump
fn generate_large_xml_dump(size: usize) -> String {
    let mut result = String::from("<mediawiki>\n");
    
    for i in 1..=size {
        let categories = match i % 5 {
            0 => "Science,Physics",
            1 => "Technology,Computing",
            2 => "History,Medieval",
            3 => "Geography,Europe",
            _ => "Culture,Literature",
        };
        
        result.push_str(&format!(
            r#"  <page>
    <title>Performance Test Page {}</title>
    <ns>0</ns>
    <revision>
      <text>This is test article {} with content related to {} for performance testing.
      It contains various keywords for search testing including science, technology, 
      research, physics, computing, and other terms.</text>
    </revision>
  </page>
"#,
            i, i, categories
        ));
    }
    
    result.push_str("</mediawiki>");
    result
} 