use rusqlite::{Connection, Transaction};
use std::sync::mpsc::{channel, Sender};
use std::thread;
use tracing::{debug, info};

use crate::error_handling::WikiResult;
use crate::parser::models::WikiArticle;
use crate::db::writer::DatabaseWriter;

pub struct ParallelImporter {
    num_threads: usize,
    batch_size: usize,
}

impl ParallelImporter {
    pub fn new(num_threads: usize, batch_size: usize) -> Self {
        Self {
            num_threads,
            batch_size,
        }
    }

    pub fn import_articles<I>(&self, articles: I, conn: &Connection) -> WikiResult<usize>
    where
        I: Iterator<Item = WikiArticle> + Send + 'static,
    {
        let (tx, rx) = channel();
        let mut total_imported = 0;

        // Spawn worker threads
        let mut handles = Vec::new();
        for thread_id in 0..self.num_threads {
            let thread_conn = Connection::open(conn.path().unwrap())?;
            let thread_tx = tx.clone();
            
            let handle = thread::spawn(move || -> WikiResult<()> {
                let mut writer = DatabaseWriter::new(&thread_conn);
                let mut batch = Vec::new();
                
                loop {
                    match thread_tx.send(()) {
                        Ok(_) => {
                            // Ready for more work
                            debug!("Worker {} ready", thread_id);
                        }
                        Err(_) => {
                            // Channel closed, main thread is done
                            debug!("Worker {} shutting down", thread_id);
                            break;
                        }
                    }
                }
                
                Ok(())
            });
            
            handles.push(handle);
        }
        
        // Process articles in batches
        let mut current_batch = Vec::with_capacity(self.batch_size);
        for article in articles {
            current_batch.push(article);
            
            if current_batch.len() >= self.batch_size {
                // Wait for an available worker
                rx.recv().unwrap();
                
                // Process batch
                self.process_batch(&current_batch, conn)?;
                total_imported += current_batch.len();
                
                info!("Imported {} articles", total_imported);
                current_batch.clear();
            }
        }
        
        // Process remaining articles
        if !current_batch.is_empty() {
            rx.recv().unwrap();
            self.process_batch(&current_batch, conn)?;
            total_imported += current_batch.len();
        }
        
        // Signal workers to shut down
        drop(tx);
        
        // Wait for workers to finish
        for handle in handles {
            handle.join().unwrap()?;
        }
        
        Ok(total_imported)
    }
    
    fn process_batch(&self, batch: &[WikiArticle], conn: &Connection) -> WikiResult<()> {
        let mut writer = DatabaseWriter::new(conn);
        let tx = writer.begin_transaction()?;
        
        for article in batch {
            writer.write_article(article, &tx)?;
        }
        
        DatabaseWriter::commit_transaction(tx)?;
        Ok(())
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
        let importer = ParallelImporter::new(4, 10);
        let total = importer.import_articles(articles.into_iter(), &conn)?;
        assert_eq!(total, 100);
        
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