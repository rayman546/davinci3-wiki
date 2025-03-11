use davinci3_wiki::{
    error_handling::WikiResult,
    db::{init_database, DatabaseWriter, DatabaseReader},
    parser::models::WikiArticle,
};
use std::path::Path;
use tempfile::TempDir;

#[test]
fn test_db_init_and_basic_operations() -> WikiResult<()> {
    // Create a temporary directory for test database
    let temp_dir = TempDir::new()?;
    let db_path = temp_dir.path().join("test.db");
    
    // Initialize database
    let db_conn = init_database(&db_path)?;
    
    // Create writer and reader
    let db_writer = DatabaseWriter::new(db_conn);
    let db_conn2 = rusqlite::Connection::open(&db_path)?;
    let db_reader = DatabaseReader::new(db_conn2);
    
    // Create test articles
    let article1 = WikiArticle {
        id: "1".to_string(),
        title: "Test Article 1".to_string(),
        text: "This is test article 1 content.".to_string(),
        categories: vec!["Category 1".to_string(), "Category 2".to_string()],
        timestamp: chrono::Utc::now(),
    };
    
    let article2 = WikiArticle {
        id: "2".to_string(),
        title: "Test Article 2".to_string(),
        text: "This is test article 2 content.".to_string(),
        categories: vec!["Category 2".to_string(), "Category 3".to_string()],
        timestamp: chrono::Utc::now(),
    };
    
    // Insert articles
    db_writer.insert_article(&article1)?;
    db_writer.insert_article(&article2)?;
    
    // Test fetch by ID
    let fetched_article1 = db_reader.get_article("1")?;
    let fetched_article2 = db_reader.get_article("2")?;
    
    // Verify fetched articles match the inserted ones
    assert_eq!(fetched_article1.id, article1.id);
    assert_eq!(fetched_article1.title, article1.title);
    assert_eq!(fetched_article1.text, article1.text);
    
    assert_eq!(fetched_article2.id, article2.id);
    assert_eq!(fetched_article2.title, article2.title);
    assert_eq!(fetched_article2.text, article2.text);
    
    // Test get_all_articles
    let all_articles = db_reader.get_all_articles()?;
    assert_eq!(all_articles.len(), 2);
    
    // Test search
    let search_results = db_reader.search("test article")?;
    assert_eq!(search_results.len(), 2);
    
    let search_results = db_reader.search("article 1")?;
    assert_eq!(search_results.len(), 1);
    assert_eq!(search_results[0].id, "1");
    
    // Test get_articles_by_category
    let category_articles = db_reader.get_articles_by_category("Category 2")?;
    assert_eq!(category_articles.len(), 2);
    
    let category_articles = db_reader.get_articles_by_category("Category 3")?;
    assert_eq!(category_articles.len(), 1);
    assert_eq!(category_articles[0].id, "2");
    
    Ok(())
}

#[test]
fn test_db_article_update() -> WikiResult<()> {
    // Create a temporary directory for test database
    let temp_dir = TempDir::new()?;
    let db_path = temp_dir.path().join("update_test.db");
    
    // Initialize database
    let db_conn = init_database(&db_path)?;
    
    // Create writer and reader
    let db_writer = DatabaseWriter::new(db_conn);
    let db_conn2 = rusqlite::Connection::open(&db_path)?;
    let db_reader = DatabaseReader::new(db_conn2);
    
    // Create test article
    let article = WikiArticle {
        id: "1".to_string(),
        title: "Original Title".to_string(),
        text: "Original content.".to_string(),
        categories: vec!["Category 1".to_string()],
        timestamp: chrono::Utc::now(),
    };
    
    // Insert article
    db_writer.insert_article(&article)?;
    
    // Update the article
    let updated_article = WikiArticle {
        id: "1".to_string(),
        title: "Updated Title".to_string(),
        text: "Updated content.".to_string(),
        categories: vec!["Category 1".to_string(), "Category 2".to_string()],
        timestamp: chrono::Utc::now(),
    };
    
    db_writer.insert_article(&updated_article)?;
    
    // Fetch the article and verify it was updated
    let fetched_article = db_reader.get_article("1")?;
    
    assert_eq!(fetched_article.id, "1");
    assert_eq!(fetched_article.title, "Updated Title");
    assert_eq!(fetched_article.text, "Updated content.");
    
    // Verify categories were updated
    let category_articles = db_reader.get_articles_by_category("Category 2")?;
    assert_eq!(category_articles.len(), 1);
    assert_eq!(category_articles[0].id, "1");
    
    Ok(())
}

#[test]
fn test_db_transaction() -> WikiResult<()> {
    // Create a temporary directory for test database
    let temp_dir = TempDir::new()?;
    let db_path = temp_dir.path().join("transaction_test.db");
    
    // Initialize database
    let db_conn = init_database(&db_path)?;
    
    // Create writer
    let db_writer = DatabaseWriter::new(db_conn);
    
    // Create test articles
    let articles: Vec<_> = (1..=100).map(|i| {
        WikiArticle {
            id: i.to_string(),
            title: format!("Article {}", i),
            text: format!("Content of article {}.", i),
            categories: vec!["Test".to_string()],
            timestamp: chrono::Utc::now(),
        }
    }).collect();
    
    // Insert articles in bulk
    db_writer.insert_articles(&articles)?;
    
    // Verify all articles were inserted
    let db_conn2 = rusqlite::Connection::open(&db_path)?;
    let db_reader = DatabaseReader::new(db_conn2);
    
    let all_articles = db_reader.get_all_articles()?;
    assert_eq!(all_articles.len(), 100);
    
    Ok(())
} 