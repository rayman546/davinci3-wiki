use rusqlite::{Connection, Transaction, params};
use std::collections::HashMap;
use tracing::{debug, info};

use crate::error_handling::{WikiError, WikiResult};
use crate::parser::models::{WikiArticle, WikiImage};

pub struct DatabaseWriter<'a> {
    conn: &'a Connection,
    category_cache: HashMap<String, i64>,
}

impl<'a> DatabaseWriter<'a> {
    pub fn new(conn: &'a Connection) -> Self {
        Self {
            conn,
            category_cache: HashMap::new(),
        }
    }

    pub fn create_tables(&self) -> WikiResult<()> {
        self.conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS articles (title TEXT PRIMARY KEY, content TEXT, size INTEGER, last_modified TEXT);
             CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY, name TEXT UNIQUE);
             CREATE TABLE IF NOT EXISTS article_categories (article_id INTEGER, category_id INTEGER, 
                PRIMARY KEY (article_id, category_id),
                FOREIGN KEY (article_id) REFERENCES articles(rowid),
                FOREIGN KEY (category_id) REFERENCES categories(id));
             CREATE TABLE IF NOT EXISTS images (id INTEGER PRIMARY KEY, filename TEXT, path TEXT, 
                size INTEGER, mime_type TEXT, hash TEXT UNIQUE, caption TEXT);
             CREATE TABLE IF NOT EXISTS article_images (article_id INTEGER, image_id INTEGER,
                PRIMARY KEY (article_id, image_id),
                FOREIGN KEY (article_id) REFERENCES articles(rowid),
                FOREIGN KEY (image_id) REFERENCES images(id));
             CREATE TABLE IF NOT EXISTS redirects (from_title TEXT PRIMARY KEY, to_title TEXT);
             CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(title, content, content='articles', content_rowid='rowid');"
        ).map_err(WikiError::from)
    }

    pub fn begin_transaction(&self) -> WikiResult<Transaction> {
        self.conn.transaction().map_err(WikiError::from)
    }

    pub fn write_article(&self, article: &WikiArticle, tx: &Transaction) -> WikiResult<()> {
        // Insert into articles FTS table
        tx.execute(
            "INSERT INTO articles (title, content, size, last_modified) VALUES (?1, ?2, ?3, ?4)",
            params![
                article.title,
                article.content,
                article.size,
                article.last_modified.to_rfc3339(),
            ],
        )?;

        // Handle redirect if present
        if let Some(ref redirect_to) = article.redirect_to {
            tx.execute(
                "INSERT INTO redirects (from_title, to_title) VALUES (?1, ?2)",
                params![article.title, redirect_to],
            )?;
            return Ok(());
        }

        // Process categories
        for category in &article.categories {
            let category_id = self.get_or_create_category(category, tx)?;
            tx.execute(
                "INSERT INTO article_categories (article_id, category_id) VALUES (
                    (SELECT rowid FROM articles WHERE title = ?1),
                    ?2
                )",
                params![article.title, category_id],
            )?;
        }

        // Process images
        for image in &article.images {
            let image_id = self.write_image(image, tx)?;
            tx.execute(
                "INSERT INTO article_images (article_id, image_id) VALUES (
                    (SELECT rowid FROM articles WHERE title = ?1),
                    ?2
                )",
                params![article.title, image_id],
            )?;
        }

        Ok(())
    }

    fn get_or_create_category(&self, category: &str, tx: &Transaction) -> WikiResult<i64> {
        // Try to get existing category
        match tx.query_row(
            "SELECT id FROM categories WHERE name = ?1",
            params![category],
            |row| row.get(0),
        ) {
            Ok(id) => Ok(id),
            Err(rusqlite::Error::QueryReturnedNoRows) => {
                // Create new category
                tx.execute(
                    "INSERT INTO categories (name) VALUES (?1)",
                    params![category],
                )?;
                Ok(tx.last_insert_rowid())
            }
            Err(e) => Err(WikiError::from(e)),
        }
    }

    fn write_image(&self, image: &WikiImage, tx: &Transaction) -> WikiResult<i64> {
        // Check if image already exists by hash
        if let Ok(id) = tx.query_row(
            "SELECT id FROM images WHERE hash = ?1",
            params![image.hash],
            |row| row.get::<_, i64>(0),
        ) {
            return Ok(id);
        }

        // Insert new image
        tx.execute(
            "INSERT INTO images (filename, path, size, mime_type, hash, caption) 
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                image.filename,
                image.path,
                image.size,
                image.mime_type,
                image.hash,
                image.caption,
            ],
        )?;

        Ok(tx.last_insert_rowid())
    }

    pub fn commit_transaction(tx: Transaction) -> WikiResult<()> {
        tx.commit().map_err(WikiError::from)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parser::models::WikiArticle;
    use chrono::Utc;
    use std::collections::HashSet;
    use tempfile::NamedTempFile;
    use crate::db::schema::init_database;

    fn create_test_db() -> (Connection, NamedTempFile) {
        let temp_file = NamedTempFile::new().unwrap();
        let conn = Connection::open(temp_file.path()).unwrap();
        init_database(&conn).unwrap();
        (conn, temp_file)
    }

    #[test]
    fn test_write_simple_article() -> WikiResult<()> {
        let (conn, _temp_file) = create_test_db();
        let writer = DatabaseWriter::new(&conn);
        let tx = writer.begin_transaction()?;

        let mut article = WikiArticle::new(
            "Test Article".to_string(),
            "This is a test article.".to_string(),
        );
        article.add_category("Test Category".to_string());
        article.update_size();

        writer.write_article(&article, &tx)?;
        DatabaseWriter::commit_transaction(tx)?;

        // Verify article was written
        let count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM articles WHERE title = ?1",
            params!["Test Article"],
            |row| row.get(0),
        )?;
        assert_eq!(count, 1);

        // Verify category was written
        let count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM categories WHERE name = ?1",
            params!["Test Category"],
            |row| row.get(0),
        )?;
        assert_eq!(count, 1);

        Ok(())
    }

    #[test]
    fn test_write_redirect() -> WikiResult<()> {
        let (conn, _temp_file) = create_test_db();
        let writer = DatabaseWriter::new(&conn);
        let tx = writer.begin_transaction()?;

        let mut article = WikiArticle::new(
            "Redirect Source".to_string(),
            "#REDIRECT [[Target Article]]".to_string(),
        );
        article.redirect_to = Some("Target Article".to_string());
        article.update_size();

        writer.write_article(&article, &tx)?;
        DatabaseWriter::commit_transaction(tx)?;

        // Verify redirect was written
        let count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM redirects WHERE from_title = ?1 AND to_title = ?2",
            params!["Redirect Source", "Target Article"],
            |row| row.get(0),
        )?;
        assert_eq!(count, 1);

        Ok(())
    }
} 