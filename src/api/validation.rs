use regex::Regex;
use serde::{Deserialize, Serialize};
use warp::{Filter, Rejection, reject, Reply};
use std::sync::Arc;

/// Error response for validation failures
#[derive(Debug, Serialize)]
pub struct ValidationErrorResponse {
    pub status: String,
    pub message: String,
    pub field: Option<String>,
}

/// Custom rejection for validation errors
#[derive(Debug)]
pub struct ValidationError {
    pub message: String,
    pub field: Option<String>,
}

impl reject::Reject for ValidationError {}

/// Create a ValidationError with a message
pub fn validation_error(message: &str, field: Option<&str>) -> ValidationError {
    ValidationError {
        message: message.to_string(),
        field: field.map(|s| s.to_string()),
    }
}

/// Validation rules for search queries
pub struct SearchQueryValidator {
    /// Maximum length allowed for search query
    max_query_length: usize,
    /// Regular expression for validating search query
    query_regex: Regex,
    /// Maximum limit for results
    max_limit: usize,
    /// Maximum offset for pagination
    max_offset: usize,
}

impl Default for SearchQueryValidator {
    fn default() -> Self {
        Self {
            max_query_length: 200,
            query_regex: Regex::new(r"^[a-zA-Z0-9\s\.\,\-\_\'\"\:\;\!\?\(\)\[\]\{\}\<\>\+\*\/\&\%\$\#\@\^\~\`\=]+$").unwrap(),
            max_limit: 100,
            max_offset: 1000,
        }
    }
}

impl SearchQueryValidator {
    /// Create a new SearchQueryValidator with custom parameters
    pub fn new(max_query_length: usize, max_limit: usize, max_offset: usize) -> Self {
        Self {
            max_query_length,
            query_regex: Regex::new(r"^[a-zA-Z0-9\s\.\,\-\_\'\"\:\;\!\?\(\)\[\]\{\}\<\>\+\*\/\&\%\$\#\@\^\~\`\=]+$").unwrap(),
            max_limit,
            max_offset,
        }
    }

    /// Validate a search query string
    pub fn validate_query(&self, query: &str) -> Result<(), ValidationError> {
        // Check query length
        if query.trim().is_empty() {
            return Err(validation_error("Search query cannot be empty", Some("query")));
        }
        
        if query.len() > self.max_query_length {
            return Err(validation_error(
                &format!("Search query exceeds maximum length of {} characters", self.max_query_length),
                Some("query")
            ));
        }
        
        // Check query content with regex for potentially dangerous characters
        if !self.query_regex.is_match(query) {
            return Err(validation_error(
                "Search query contains invalid characters",
                Some("query")
            ));
        }
        
        Ok(())
    }
    
    /// Validate limit parameter
    pub fn validate_limit(&self, limit: Option<usize>) -> Result<(), ValidationError> {
        if let Some(limit) = limit {
            if limit > self.max_limit {
                return Err(validation_error(
                    &format!("Limit exceeds maximum value of {}", self.max_limit),
                    Some("limit")
                ));
            }
            
            if limit == 0 {
                return Err(validation_error(
                    "Limit must be greater than 0",
                    Some("limit")
                ));
            }
        }
        
        Ok(())
    }
    
    /// Validate offset parameter
    pub fn validate_offset(&self, offset: Option<usize>) -> Result<(), ValidationError> {
        if let Some(offset) = offset {
            if offset > self.max_offset {
                return Err(validation_error(
                    &format!("Offset exceeds maximum value of {}", self.max_offset),
                    Some("offset")
                ));
            }
        }
        
        Ok(())
    }
}

/// Path parameter validator for article titles
pub struct TitleValidator {
    /// Maximum length allowed for article title
    max_title_length: usize,
    /// Regular expression for validating article title
    title_regex: Regex,
}

impl Default for TitleValidator {
    fn default() -> Self {
        Self {
            max_title_length: 200,
            title_regex: Regex::new(r"^[a-zA-Z0-9\s\.\,\-\_\'\"\:\;\!\?\(\)\[\]\{\}\<\>\+\*\/\&\%\$\#\@\^\~\`\=]+$").unwrap(),
        }
    }
}

impl TitleValidator {
    /// Create a new TitleValidator with custom parameters
    pub fn new(max_title_length: usize) -> Self {
        Self {
            max_title_length,
            title_regex: Regex::new(r"^[a-zA-Z0-9\s\.\,\-\_\'\"\:\;\!\?\(\)\[\]\{\}\<\>\+\*\/\&\%\$\#\@\^\~\`\=]+$").unwrap(),
        }
    }
    
    /// Validate an article title
    pub fn validate(&self, title: &str) -> Result<(), ValidationError> {
        // Check title length
        if title.trim().is_empty() {
            return Err(validation_error("Article title cannot be empty", Some("title")));
        }
        
        if title.len() > self.max_title_length {
            return Err(validation_error(
                &format!("Article title exceeds maximum length of {} characters", self.max_title_length),
                Some("title")
            ));
        }
        
        // Check title content with regex for potentially dangerous characters
        if !self.title_regex.is_match(title) {
            return Err(validation_error(
                "Article title contains invalid characters",
                Some("title")
            ));
        }
        
        Ok(())
    }
}

/// Create a warp filter for validating search queries
pub fn validate_search_query() -> impl Filter<Extract = (), Error = Rejection> + Clone {
    let validator = Arc::new(SearchQueryValidator::default());
    
    warp::query::<super::SearchQuery>()
        .and_then(move |query: super::SearchQuery| {
            let validator = validator.clone();
            async move {
                // Validate query string
                if let Err(e) = validator.validate_query(&query.query) {
                    return Err(warp::reject::custom(e));
                }
                
                // Validate limit
                if let Err(e) = validator.validate_limit(query.limit) {
                    return Err(warp::reject::custom(e));
                }
                
                // Validate offset
                if let Err(e) = validator.validate_offset(query.offset) {
                    return Err(warp::reject::custom(e));
                }
                
                Ok(())
            }
        })
}

/// Create a warp filter for validating article titles
pub fn validate_article_title() -> impl Filter<Extract = (), Error = Rejection> + Clone {
    let validator = Arc::new(TitleValidator::default());
    
    warp::path::param::<String>()
        .and_then(move |title: String| {
            let validator = validator.clone();
            async move {
                if let Err(e) = validator.validate(&title) {
                    return Err(warp::reject::custom(e));
                }
                
                Ok(())
            }
        })
        .untuple_one()
} 