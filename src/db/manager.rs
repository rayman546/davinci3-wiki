use std::path::Path;
use rusqlite::Connection;
use tracing::{info, warn};

use crate::error_handling::{WikiError, WikiResult};
use super::schema;

pub struct DatabaseManager {
    conn: Connection,
}

impl DatabaseManager {
    /// Create a new database connection and initialize the schema
    pub fn new<P: AsRef<Path>>(db_path: P) -> WikiResult<Self> {
        info!("Initializing database at {:?}", db_path.as_ref());
        
        let conn = Connection::open(db_path)
            .map_err(|e| WikiError::Database(e))?;

        // Enable foreign key constraints
        conn.execute("PRAGMA foreign_keys = ON", [])
            .map_err(WikiError::from)?;

        // Initialize schema
        schema::init_database(&conn)?;

        info!("Database initialization complete");
        Ok(Self { conn })
    }

    /// Get the current schema version
    pub fn get_schema_version(&self) -> WikiResult<i32> {
        self.conn
            .query_row(
                "SELECT version FROM schema_version LIMIT 1",
                [],
                |row| row.get(0),
            )
            .map_err(WikiError::from)
    }

    /// Get a reference to the underlying connection
    pub fn connection(&self) -> &Connection {
        &self.conn
    }

    /// Begin a transaction
    pub fn transaction(&self) -> WikiResult<rusqlite::Transaction> {
        self.conn.transaction().map_err(WikiError::from)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_database_initialization() -> WikiResult<()> {
        let temp_dir = tempdir().map_err(|e| WikiError::Io(e))?;
        let db_path = temp_dir.path().join("test.db");
        
        let db = DatabaseManager::new(&db_path)?;
        let version = db.get_schema_version()?;
        
        assert_eq!(version, 1);
        Ok(())
    }
} 