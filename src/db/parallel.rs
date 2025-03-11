use rusqlite::Connection;
use std::sync::mpsc::{channel, Receiver};
use std::thread;
use std::path::Path;

use crate::error_handling::WikiResult;
use crate::parser::models::WikiArticle;
use crate::db::writer::DatabaseWriter;

pub struct ParallelDatabaseWriter {
    thread_count: usize,
}

impl ParallelDatabaseWriter {
    pub fn new(thread_count: usize) -> Self {
        ParallelDatabaseWriter {
            thread_count: thread_count.max(1),
        }
    }

    pub fn process_articles<P: AsRef<Path>>(
        &self,
        articles: Vec<WikiArticle>,
        db_path: P,
    ) -> WikiResult<()> {
        let db_path = db_path.as_ref().to_path_buf();
        let chunk_size = (articles.len() + self.thread_count - 1) / self.thread_count;
        let (tx, rx) = channel();

        let mut handles = Vec::new();

        for chunk in articles.chunks(chunk_size) {
            let chunk = chunk.to_vec();
            let db_path = db_path.clone();
            let tx = tx.clone();

            let handle = thread::spawn(move || -> WikiResult<()> {
                let conn = Connection::open(&db_path)?;
                let mut writer = DatabaseWriter::new(&conn);
                let mut batch = Vec::new();

                for article in chunk {
                    batch.push(article);

                    if batch.len() >= 100 {
                        Self::process_batch(&batch, &db_path)?;
                        batch.clear();
                    }
                }

                if !batch.is_empty() {
                    Self::process_batch(&batch, &db_path)?;
                }

                tx.send(chunk.len()).unwrap_or_default();
                Ok(())
            });

            handles.push(handle);
        }

        drop(tx);
        self.monitor_progress(rx, articles.len());

        for handle in handles {
            handle.join().unwrap()?;
        }

        Ok(())
    }

    fn process_batch<P: AsRef<Path>>(batch: &[WikiArticle], db_path: P) -> WikiResult<()> {
        let conn = Connection::open(db_path.as_ref())?;
        let mut writer = DatabaseWriter::new(&conn);
        let tx = writer.begin_transaction()?;

        for article in batch {
            writer.write_article(article, &tx)?;
        }

        tx.commit()?;
        Ok(())
    }

    fn monitor_progress(&self, rx: Receiver<usize>, total: usize) {
        let mut processed = 0;
        while let Ok(count) = rx.recv() {
            processed += count;
            println!("Processed {}/{} articles ({}%)", 
                processed, 
                total, 
                (processed as f64 / total as f64 * 100.0) as usize
            );
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::schema::init_database;
    use crate::db::reader::DatabaseReader;
    use std::collections::HashSet;
    use tempfile::NamedTempFile;
    
    #[test]
    fn test_parallel_import() -> WikiResult<()> {
        let temp_file = NamedTempFile::new().unwrap();
        let conn = Connection::open(temp_file.path()).unwrap();
        init_database(&conn)?;
        
        // Create test articles
        let articles: Vec<_> = (0..100).map(|i| {
            let mut article = WikiArticle::new(
                format!("Article {}", i),
                format!("Content of article {}", i),
            );
            article.add_category(format!("Category {}", i % 5));
            article.update_size();
            article
        }).collect();
        
        // Import articles
        let importer = ParallelDatabaseWriter::new(4);
        importer.process_articles(articles, temp_file.path())?;
        
        // Verify imports
        let reader = DatabaseReader::new(&conn);
        let categories = reader.list_categories()?;
        assert_eq!(categories.len(), 5);
        
        let mut titles = HashSet::new();
        for i in 0..100 {
            let article = reader.get_article(&format!("Article {}", i))?.unwrap();
            titles.insert(article.title);
        }
        assert_eq!(titles.len(), 100);
        
        Ok(())
    }
} 