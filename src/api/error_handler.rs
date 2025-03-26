use std::convert::Infallible;
use warp::{Rejection, Reply, http::StatusCode};

use super::validation::{ValidationError, ValidationErrorResponse};

/// Handle rejections, including custom validation errors
pub async fn handle_rejection(err: Rejection) -> Result<impl Reply, Infallible> {
    let code;
    let message;
    let status;
    let field;
    
    if err.is_not_found() {
        code = StatusCode::NOT_FOUND;
        message = "Not Found".to_string();
        status = "error".to_string();
        field = None;
    } else if let Some(e) = err.find::<ValidationError>() {
        code = StatusCode::BAD_REQUEST;
        message = e.message.clone();
        status = "error".to_string();
        field = e.field.clone();
    } else if let Some(e) = err.find::<warp::filters::body::BodyDeserializeError>() {
        code = StatusCode::BAD_REQUEST;
        message = format!("Invalid request data: {}", e);
        status = "error".to_string();
        field = None;
    } else if let Some(_) = err.find::<warp::reject::MethodNotAllowed>() {
        code = StatusCode::METHOD_NOT_ALLOWED;
        message = "Method not allowed".to_string();
        status = "error".to_string();
        field = None;
    } else {
        // Unexpected error
        code = StatusCode::INTERNAL_SERVER_ERROR;
        message = "Internal Server Error".to_string();
        status = "error".to_string();
        field = None;
        
        // Log unexpected errors
        eprintln!("Unhandled rejection: {:?}", err);
    }
    
    // Create JSON response
    let json = warp::reply::json(&ValidationErrorResponse {
        status,
        message,
        field,
    });
    
    Ok(warp::reply::with_status(json, code))
} 