use thiserror::Error;
use std::io;

#[derive(Error, Debug)]
pub enum WikiError {
    #[error("IO error: {0}")]
    Io(#[from] io::Error),

    #[error("XML parsing error: {0}")]
    XmlParse(#[from] quick_xml::Error),

    #[error("Database error: {0}")]
    Database(#[from] rusqlite::Error),

    #[error("Vector storage error: {0}")]
    VectorStorage(String),

    #[error("LLM error: {0}")]
    Llm(String),

    #[error("UI error: {0}")]
    Ui(String),

    #[error("Installation error: {0}")]
    Installation(String),

    #[error("Network error: {0}")]
    Network(String),

    #[error("Invalid data: {0}")]
    InvalidData(String),

    #[error("Resource not found: {0}")]
    NotFound(String),

    #[error("Operation failed: {0}")]
    OperationFailed(String),
}

pub type WikiResult<T> = Result<T, WikiError>;

// Helper functions for common error cases
impl WikiError {
    pub fn io(error: io::Error) -> Self {
        WikiError::Io(error)
    }

    pub fn invalid_data<T: Into<String>>(msg: T) -> Self {
        WikiError::InvalidData(msg.into())
    }

    pub fn not_found<T: Into<String>>(msg: T) -> Self {
        WikiError::NotFound(msg.into())
    }

    pub fn operation_failed<T: Into<String>>(msg: T) -> Self {
        WikiError::OperationFailed(msg.into())
    }

    pub fn vector_storage<T: Into<String>>(msg: T) -> Self {
        WikiError::VectorStorage(msg.into())
    }

    pub fn llm<T: Into<String>>(msg: T) -> Self {
        WikiError::Llm(msg.into())
    }

    pub fn ui<T: Into<String>>(msg: T) -> Self {
        WikiError::Ui(msg.into())
    }

    pub fn installation<T: Into<String>>(msg: T) -> Self {
        WikiError::Installation(msg.into())
    }

    pub fn network<T: Into<String>>(msg: T) -> Self {
        WikiError::Network(msg.into())
    }
} 