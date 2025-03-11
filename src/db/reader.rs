use rusqlite::{Connection, params};
use tracing::{debug, info};
use chrono::{DateTime, Utc};

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
        let result = self.conn.query_row(
            "SELECT title, content, last_modified, size FROM articles WHERE title = ?1",
            params![title],
            |row| {
                Ok(WikiArticle {
                    title: row.get(0)?,
                    content: row.get(1)?,
                    categories: Default::default(),
                    last_modified: DateTime::parse_from_rfc3339(&row.get::<_, String>(2)?)
                        .map_err(|e| rusqlite::Error::FromSqlConversionFailure(
                            0,
                            rusqlite::types::Type::Text,
                            Box::new(e),
                        ))?
                        .with_timezone(&Utc),
                    size: row.get(3)?,
                    redirect_to: None,
                    images: Vec::new(),
                })
            },
        );

        match result {
            Ok(article) => {
                // Load categories
                let mut categories = Vec::new();
                let mut stmt = self.conn.prepare(
                    "SELECT c.name FROM categories c
                     JOIN article_categories ac ON c.id = ac.category_id
                     WHERE ac.article_id = (SELECT rowid FROM articles WHERE title = ?1)"
                )?;
                let mut rows = stmt.query(params![title])?;
                while let Some(row) = rows.next()? {
                    categories.push(row.get::<_, String>(0)?);
                }

                // Load images
                let mut images = Vec::new();
                let mut stmt = self.conn.prepare(
                    "SELECT i.filename, i.path, i.size, i.mime_type, i.hash, i.caption
                     FROM images i
                     JOIN article_images ai ON i.id = ai.image_id
                     WHERE ai.article_id = (SELECT rowid FROM articles WHERE title = ?1)"
                )?;
                let mut rows = stmt.query(params![title])?;
                while let Some(row) = rows.next()? {
                    images.push(WikiImage {
                        filename: row.get(0)?,
                        path: row.get(1)?,
                        size: row.get(2)?,
                        mime_type: row.get(3)?,
                        hash: row.get(4)?,
                        caption: row.get(5)?,
                    });
                }

                // Update article with loaded data
                let mut article = article;
                article.categories = categories.into_iter().collect();
                article.images = images;
                Ok(Some(article))
            }
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(WikiError::from(e)),
        }
    }

    pub fn get_articles(&self, limit: usize) -> WikiResult<Vec<WikiArticle>> {
        let mut stmt = self.conn.prepare(
            "SELECT title, content, last_modified, size FROM articles LIMIT ?1"
        )?;

        let articles = stmt.query_map(params![limit as i64], |row| {
            Ok(WikiArticle {
                title: row.get(0)?,
                content: row.get(1)?,
                categories: Default::default(),
                last_modified: DateTime::parse_from_rfc3339(&row.get::<_, String>(2)?)
                    .map_err(|e| rusqlite::Error::FromSqlConversionFailure(
                        0,
                        rusqlite::types::Type::Text,
                        Box::new(e),
                    ))?
                    .with_timezone(&Utc),
                size: row.get(3)?,
                redirect_to: None,
                images: Vec::new(),
            })
        })?
        .collect::<Result<Vec<_>, _>>()?;

        Ok(articles)
    }

    pub fn search_articles(&self, query: &str, limit: usize) -> WikiResult<Vec<WikiArticle>> {
        let mut stmt = self.conn.prepare(
            "SELECT title, content, last_modified, size FROM articles 
             WHERE articles MATCH ?1 
             ORDER BY rank
             LIMIT ?2"
        )?;

        let articles = stmt.query_map(params![query, limit as i64], |row| {
            Ok(WikiArticle {
                title: row.get(0)?,
                content: row.get(1)?,
                categories: Default::default(),
                last_modified: DateTime::parse_from_rfc3339(&row.get::<_, String>(2)?)
                    .map_err(|e| rusqlite::Error::FromSqlConversionFailure(
                        0,
                        rusqlite::types::Type::Text,
                        Box::new(e),
                    ))?
                    .with_timezone(&Utc),
                size: row.get(3)?,
                redirect_to: None,
                images: Vec::new(),
            })
        })?
        .collect::<Result<Vec<_>, _>>()?;

        Ok(articles)
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
    use crate::db::schema::init_database;
    use crate::db::writer::DatabaseWriter;
    use tempfile::NamedTempFile;

    fn create_test_db() -> (Connection, NamedTempFile) {
        let temp_file = NamedTempFile::new().unwrap();
        let conn = Connection::open(temp_file.path()).unwrap();
        init_database(&conn).unwrap();
        (conn, temp_file)
    }

    #[test]
    fn test_get_article() -> WikiResult<()> {
        let (mut conn, _temp_file) = create_test_db();
        
        // Insert test article
        let mut writer = DatabaseWriter::new(&mut conn);
        let tx = writer.begin_transaction()?;
        
        let mut article = WikiArticle::new(
            "Test Article".to_string(),
            "This is a test article.".to_string(),
        );
        article.add_category("Test Category".to_string());
        article.update_size();
        
        writer.write_article(&article, &tx)?;
        DatabaseWriter::commit_transaction(tx)?;
        
        // Test retrieval
        let reader = DatabaseReader::new(&conn);
        let retrieved = reader.get_article("Test Article")?;
        
        assert!(retrieved.is_some());
        let retrieved = retrieved.unwrap();
        assert_eq!(retrieved.title, "Test Article");
        assert_eq!(retrieved.content, "This is a test article.");
        
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