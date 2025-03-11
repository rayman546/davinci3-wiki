pub mod schema;
pub mod writer;
pub mod reader;
pub mod parallel;

use rusqlite::{Connection, Transaction, params};
use tracing::{debug, info, warn};
use chrono::{DateTime, Utc};

use crate::error_handling::{WikiError, WikiResult};
use crate::parser::{WikiArticle, WikiCategory, WikiImage};

pub use manager::DatabaseManager;
pub use schema::*;
pub use writer::*;
pub use reader::*;
pub use parallel::*;

pub struct DatabaseManager {
    conn: Connection,
}

impl DatabaseManager {
    pub fn new(path: &str) -> WikiResult<Self> {
        let conn = Connection::open(path)?;
        let db = Self { conn };
        db.init()?;
        Ok(db)
    }

    fn init(&self) -> WikiResult<()> {
        schema::init_schema(&self.conn)?;
        Ok(())
    }

    pub fn get_schema_version(&self) -> WikiResult<i32> {
        let version: i32 = self.conn.query_row(
            "SELECT version FROM schema_version LIMIT 1",
            [],
            |row| row.get(0),
        )?;
        Ok(version)
    }

    pub fn begin_transaction(&self) -> WikiResult<Transaction> {
        Ok(self.conn.transaction()?)
    }

    pub fn insert_article(&self, article: &WikiArticle, tx: &Transaction) -> WikiResult<i64> {
        // Insert into articles table
        tx.execute(
            "INSERT INTO articles (title, redirect_to, last_modified, size) VALUES (?1, ?2, ?3, ?4)",
            params![
                article.title,
                article.redirect_to,
                article.last_modified.to_rfc3339(),
                article.size,
            ],
        )?;
        let article_id = tx.last_insert_rowid();

        // Insert into FTS table
        tx.execute(
            "INSERT INTO articles_fts (title, content, last_modified, size) VALUES (?1, ?2, ?3, ?4)",
            params![
                article.title,
                article.content,
                article.last_modified.to_rfc3339(),
                article.size,
            ],
        )?;

        // Insert categories
        for category in &article.categories {
            let category_id = self.insert_category(category, tx)?;
            tx.execute(
                "INSERT INTO article_categories (article_id, category_id) VALUES (?1, ?2)",
                params![article_id, category_id],
            )?;
        }

        // Insert images
        for image in &article.images {
            let image_id = self.insert_image(image, tx)?;
            tx.execute(
                "INSERT INTO article_images (article_id, image_id) VALUES (?1, ?2)",
                params![article_id, image_id],
            )?;
        }

        Ok(article_id)
    }

    pub fn insert_category(&self, name: &str, tx: &Transaction) -> WikiResult<i64> {
        // Try to get existing category first
        if let Ok(id) = tx.query_row(
            "SELECT id FROM categories WHERE name = ?1",
            params![name],
            |row| row.get::<_, i64>(0),
        ) {
            return Ok(id);
        }

        // Insert new category if it doesn't exist
        tx.execute(
            "INSERT INTO categories (name) VALUES (?1)",
            params![name],
        )?;
        Ok(tx.last_insert_rowid())
    }

    pub fn insert_image(&self, image: &WikiImage, tx: &Transaction) -> WikiResult<i64> {
        // Try to get existing image first
        if let Ok(id) = tx.query_row(
            "SELECT id FROM images WHERE filename = ?1",
            params![image.filename],
            |row| row.get::<_, i64>(0),
        ) {
            return Ok(id);
        }

        // Insert new image if it doesn't exist
        tx.execute(
            "INSERT INTO images (filename, path, size, mime_type, hash, caption) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
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

    pub fn search_articles(&self, query: &str) -> WikiResult<Vec<WikiArticle>> {
        let mut stmt = self.conn.prepare(
            "SELECT title, content, last_modified, size FROM articles_fts 
             WHERE articles_fts MATCH ?1 
             ORDER BY rank"
        )?;

        let articles = stmt.query_map(params![query], |row| {
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
} 