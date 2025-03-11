use rusqlite::{Connection, Result as SqlResult};
use tracing::info;

pub const SCHEMA_VERSION: i32 = 1;

pub fn init_database(conn: &Connection) -> SqlResult<()> {
    info!("Initializing database schema v{}", SCHEMA_VERSION);
    
    // Create schema version table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER NOT NULL
        )",
        [],
    )?;

    // Create articles table with FTS5
    conn.execute(
        "CREATE VIRTUAL TABLE IF NOT EXISTS articles USING fts5(
            title,
            content,
            size UNINDEXED,
            last_modified UNINDEXED
        )",
        [],
    )?;

    // Create categories table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL UNIQUE
        )",
        [],
    )?;

    // Create article_categories junction table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS article_categories (
            article_id INTEGER NOT NULL,
            category_id INTEGER NOT NULL,
            PRIMARY KEY (article_id, category_id),
            FOREIGN KEY (category_id) REFERENCES categories(id)
        )",
        [],
    )?;

    // Create images table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS images (
            id INTEGER PRIMARY KEY,
            filename TEXT NOT NULL,
            path TEXT NOT NULL,
            size INTEGER NOT NULL DEFAULT 0,
            mime_type TEXT NOT NULL,
            hash TEXT NOT NULL,
            caption TEXT
        )",
        [],
    )?;

    // Create article_images junction table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS article_images (
            article_id INTEGER NOT NULL,
            image_id INTEGER NOT NULL,
            PRIMARY KEY (article_id, image_id),
            FOREIGN KEY (image_id) REFERENCES images(id)
        )",
        [],
    )?;

    // Create redirects table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS redirects (
            from_title TEXT PRIMARY KEY,
            to_title TEXT NOT NULL
        )",
        [],
    )?;

    // Create indexes
    conn.execute("CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name)", [])?;
    conn.execute("CREATE INDEX IF NOT EXISTS idx_images_filename ON images(filename)", [])?;
    conn.execute("CREATE INDEX IF NOT EXISTS idx_images_hash ON images(hash)", [])?;
    conn.execute("CREATE INDEX IF NOT EXISTS idx_redirects_to ON redirects(to_title)", [])?;

    // Set schema version
    conn.execute("INSERT OR REPLACE INTO schema_version (version) VALUES (?1)", [SCHEMA_VERSION])?;

    info!("Database schema initialized successfully");
    Ok(())
}

pub fn check_schema_version(conn: &Connection) -> SqlResult<bool> {
    let version: i32 = conn.query_row(
        "SELECT version FROM schema_version LIMIT 1",
        [],
        |row| row.get(0),
    ).unwrap_or(0);

    Ok(version == SCHEMA_VERSION)
} 