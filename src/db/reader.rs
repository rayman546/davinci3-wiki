use rusqlite::{Connection, params};
use std::collections::HashSet;
use tracing::debug;

use crate::error_handling::{WikiError, WikiResult};
use crate::parser::models::{WikiArticle, WikiImage};

pub struct DatabaseReader<'a> {
    conn: &'a Connection,
}

impl<'a> DatabaseReader<'a> {
    pub fn new(conn: &'a Connection) -> Self {
        Self { conn }
    }

    pub fn get_article(&self, title: &str) -> WikiResult<Option<WikiArticle>> {
        // Check for redirect first
        if let Some(redirect_to) = self.get_redirect(title)? {
            debug!("Article '{}' is a redirect to '{}'", title, redirect_to);
            return self.get_article(&redirect_to);
        }

        let article = match self.conn.query_row(
            "SELECT title, content, size, last_modified FROM articles WHERE title = ?1",
            params![title],
            |row| {
                let title: String = row.get(0)?;
                let content: String = row.get(1)?;
                let size: usize = row.get(2)?;
                let last_modified: String = row.get(3)?;
                
                Ok(WikiArticle {
                    title,
                    content,
                    size,
                    last_modified: last_modified.parse().unwrap(),
                    categories: HashSet::new(),
                    redirect_to: None,
                    images: Vec::new(),
                })
            },
        ) {
            Ok(mut article) => article,
            Err(rusqlite::Error::QueryReturnedNoRows) => return Ok(None),
            Err(e) => return Err(WikiError::from(e)),
        };

        // Load categories
        let mut stmt = self.conn.prepare(
            "SELECT c.name FROM categories c
             JOIN article_categories ac ON c.id = ac.category_id
             WHERE ac.article_id = (SELECT rowid FROM articles WHERE title = ?1)"
        )?;
        let categories = stmt.query_map(params![title], |row| {
            row.get::<_, String>(0)
        })?;
        for category in categories {
            article.add_category(category?);
        }

        // Load images
        let mut stmt = self.conn.prepare(
            "SELECT i.filename, i.path, i.size, i.mime_type, i.hash, i.caption
             FROM images i
             JOIN article_images ai ON i.id = ai.image_id
             WHERE ai.article_id = (SELECT rowid FROM articles WHERE title = ?1)"
        )?;
        let images = stmt.query_map(params![title], |row| {
            Ok(WikiImage::new(
                row.get(0)?,
                row.get(1)?,
                row.get(3)?,
                row.get(4)?,
            )
            .with_size(row.get(2)?)
            .with_caption(row.get(5)?))
        })?;
        for image in images {
            article.add_image(image?);
        }

        Ok(Some(article))
    }

    pub fn get_redirect(&self, title: &str) -> WikiResult<Option<String>> {
        match self.conn.query_row(
            "SELECT to_title FROM redirects WHERE from_title = ?1",
            params![title],
            |row| row.get(0),
        ) {
            Ok(redirect) => Ok(Some(redirect)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(WikiError::from(e)),
        }
    }

    pub fn search_articles(&self, query: &str) -> WikiResult<Vec<WikiArticle>> {
        let mut stmt = self.conn.prepare(
            "SELECT title, content, size, last_modified 
             FROM articles 
             WHERE articles MATCH ?1
             ORDER BY rank"
        )?;

        let articles = stmt.query_map(params![query], |row| {
            Ok(WikiArticle {
                title: row.get(0)?,
                content: row.get(1)?,
                size: row.get(2)?,
                last_modified: row.get::<_, String>(3)?.parse().unwrap(),
                categories: HashSet::new(),
                redirect_to: None,
                images: Vec::new(),
            })
        })?;

        let mut results = Vec::new();
        for article in articles {
            let mut article = article?;
            if let Some(full_article) = self.get_article(&article.title)? {
                article.categories = full_article.categories;
                article.images = full_article.images;
            }
            results.push(article);
        }

        Ok(results)
    }

    pub fn list_categories(&self) -> WikiResult<Vec<String>> {
        let mut stmt = self.conn.prepare("SELECT name FROM categories ORDER BY name")?;
        let categories = stmt.query_map([], |row| row.get(0))?;
        
        let mut results = Vec::new();
        for category in categories {
            results.push(category?);
        }
        
        Ok(results)
    }

    pub fn get_articles_in_category(&self, category: &str) -> WikiResult<Vec<String>> {
        let mut stmt = self.conn.prepare(
            "SELECT a.title 
             FROM articles a
             JOIN article_categories ac ON ac.article_id = a.rowid
             JOIN categories c ON c.id = ac.category_id
             WHERE c.name = ?1
             ORDER BY a.title"
        )?;
        
        let titles = stmt.query_map(params![category], |row| row.get(0))?;
        
        let mut results = Vec::new();
        for title in titles {
            results.push(title?);
        }
        
        Ok(results)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::writer::DatabaseWriter;
    use crate::db::schema::init_database;
    use tempfile::NamedTempFile;
    use chrono::Utc;

    fn create_test_db() -> (Connection, NamedTempFile) {
        let temp_file = NamedTempFile::new().unwrap();
        let conn = Connection::open(temp_file.path()).unwrap();
        init_database(&conn).unwrap();
        (conn, temp_file)
    }

    #[test]
    fn test_read_article() -> WikiResult<()> {
        let (conn, _temp_file) = create_test_db();
        let mut writer = DatabaseWriter::new(&conn);
        let tx = writer.begin_transaction()?;

        // Write test article
        let mut article = WikiArticle::new(
            "Test Article".to_string(),
            "This is a test article.".to_string(),
        );
        article.add_category("Test Category".to_string());
        article.update_size();

        writer.write_article(&article, &tx)?;
        DatabaseWriter::commit_transaction(tx)?;

        // Read and verify
        let reader = DatabaseReader::new(&conn);
        let retrieved = reader.get_article("Test Article")?.unwrap();
        
        assert_eq!(retrieved.title, "Test Article");
        assert_eq!(retrieved.content, "This is a test article.");
        assert!(retrieved.categories.contains("Test Category"));

        Ok(())
    }

    #[test]
    fn test_follow_redirect() -> WikiResult<()> {
        let (conn, _temp_file) = create_test_db();
        let mut writer = DatabaseWriter::new(&conn);
        let tx = writer.begin_transaction()?;

        // Write target article
        let target = WikiArticle::new(
            "Target Article".to_string(),
            "This is the target article.".to_string(),
        );
        writer.write_article(&target, &tx)?;

        // Write redirect
        let mut redirect = WikiArticle::new(
            "Redirect Source".to_string(),
            "#REDIRECT [[Target Article]]".to_string(),
        );
        redirect.redirect_to = Some("Target Article".to_string());
        writer.write_article(&redirect, &tx)?;

        DatabaseWriter::commit_transaction(tx)?;

        // Read and verify redirect is followed
        let reader = DatabaseReader::new(&conn);
        let retrieved = reader.get_article("Redirect Source")?.unwrap();
        
        assert_eq!(retrieved.title, "Target Article");
        assert_eq!(retrieved.content, "This is the target article.");

        Ok(())
    }
} 