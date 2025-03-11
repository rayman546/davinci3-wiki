pub mod error;
pub mod logging;

use thiserror::Error;
use std::io;

#[derive(Error, Debug)]
pub enum WikiError {
    #[error("IO error: {0}")]
    Io(#[from] io::Error),

    #[error("Database error: {0}")]
    Database(#[from] rusqlite::Error),

    #[error("XML parsing error: {0}")]
    XmlParsing(#[from] quick_xml::Error),

    #[error("Image error: {0}")]
    Image(#[from] image::ImageError),

    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),

    #[error("Image too large: size {0} exceeds maximum {1} bytes")]
    ImageTooLarge(usize, usize),

    #[error("Invalid image format: {0}")]
    InvalidImageFormat(String),

    #[error("Image download failed: {0}")]
    ImageDownloadFailed(String),

    #[error("Image processing failed: {0}")]
    ImageProcessingFailed(String),

    #[error("LMDB error: {0}")]
    Lmdb(String),

    #[error("Vector store error: {0}")]
    VectorStore(String),

    #[error("Embedding generation failed: {0}")]
    EmbeddingGeneration(String),

    #[error("Invalid vector dimension: expected {0}, got {1}")]
    InvalidVectorDimension(usize, usize),

    #[error("Vector similarity calculation failed: {0}")]
    VectorSimilarity(String),

    #[error("Operation failed: {0}")]
    OperationFailed(String),

    #[error("Parse error: {0}")]
    Parse(String),

    #[error("Installation error: {0}")]
    Installation(String),

    #[error("Configuration error: {0}")]
    Configuration(String),
}

impl From<heed::Error> for WikiError {
    fn from(err: heed::Error) -> Self {
        WikiError::Lmdb(err.to_string())
    }
}

pub type WikiResult<T> = Result<T, WikiError>;

pub use logging::{init_debug_logging, init_logging, init_production_logging};