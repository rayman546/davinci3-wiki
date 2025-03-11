use super::*;
use tempfile::NamedTempFile;
use chrono::Utc;

#[test]
fn test_database_init() -> WikiResult<()> {
    let temp_file = NamedTempFile::new()?;
    let db = DatabaseManager::new(temp_file.path().to_str().unwrap())?;
    assert_eq!(db.get_schema_version()?, schema::SCHEMA_VERSION);
    Ok(())
}

#[test]
fn test_article_insertion() -> WikiResult<()> {
    let temp_file = NamedTempFile::new()?;
    let db = DatabaseManager::new(temp_file.path().to_str().unwrap())?;
    let tx = db.begin_transaction()?;

    let article = WikiArticle {
        title: "Test Article".to_string(),
        content: "This is a test article.".to_string(),
        categories: vec!["Test Category".to_string()].into_iter().collect(),
        last_modified: Utc::now(),
        size: 0,
        redirect_to: None,
        images: vec![],
    };

    let article_id = db.insert_article(&article, &tx)?;
    assert!(article_id > 0);
    tx.commit()?;

    // Test search
    let results = db.search_articles("test")?;
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].title, "Test Article");
    Ok(())
}

#[test]
fn test_category_insertion() -> WikiResult<()> {
    let temp_file = NamedTempFile::new()?;
    let db = DatabaseManager::new(temp_file.path().to_str().unwrap())?;
    let tx = db.begin_transaction()?;

    let category_name = "Test Category";
    let category_id = db.insert_category(category_name, &tx)?;
    assert!(category_id > 0);

    // Test duplicate insertion
    let duplicate_id = db.insert_category(category_name, &tx)?;
    assert_eq!(category_id, duplicate_id);

    tx.commit()?;
    Ok(())
}

#[test]
fn test_image_insertion() -> WikiResult<()> {
    let temp_file = NamedTempFile::new()?;
    let db = DatabaseManager::new(temp_file.path().to_str().unwrap())?;
    let tx = db.begin_transaction()?;

    let image = WikiImage {
        filename: "test.jpg".to_string(),
        path: "/path/to/test.jpg".to_string(),
        size: 1024,
        mime_type: "image/jpeg".to_string(),
        hash: "abcdef123456".to_string(),
        caption: Some("Test Caption".to_string()),
    };

    let image_id = db.insert_image(&image, &tx)?;
    assert!(image_id > 0);

    // Test duplicate insertion
    let duplicate_id = db.insert_image(&image, &tx)?;
    assert_eq!(image_id, duplicate_id);

    tx.commit()?;
    Ok(())
}

#[test]
fn test_full_article_with_relations() -> WikiResult<()> {
    let temp_file = NamedTempFile::new()?;
    let db = DatabaseManager::new(temp_file.path().to_str().unwrap())?;
    let tx = db.begin_transaction()?;

    let image = WikiImage {
        filename: "test.jpg".to_string(),
        path: "/path/to/test.jpg".to_string(),
        size: 1024,
        mime_type: "image/jpeg".to_string(),
        hash: "abcdef123456".to_string(),
        caption: Some("Test Caption".to_string()),
    };

    let mut article = WikiArticle {
        title: "Test Article".to_string(),
        content: "This is a test article with an image.".to_string(),
        categories: vec!["Test Category".to_string(), "Another Category".to_string()]
            .into_iter()
            .collect(),
        last_modified: Utc::now(),
        size: 0,
        redirect_to: None,
        images: vec![image],
    };

    article.update_size();
    let article_id = db.insert_article(&article, &tx)?;
    assert!(article_id > 0);

    tx.commit()?;

    // Test search with content
    let results = db.search_articles("image")?;
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].title, "Test Article");
    Ok(())
} 