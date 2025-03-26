use std::sync::Arc;
use tokio::sync::Mutex;
use warp::{Filter, Rejection, Reply, filters::BoxedFilter};
use serde::{Deserialize, Serialize};
use rusqlite::Connection;

use crate::error_handling::WikiResult;
use crate::db::DatabaseReader;
use crate::vector::VectorStore;
use crate::llm::LlmService;

mod rate_limiter;
use rate_limiter::{RateLimiter, with_rate_limiting};

mod validation;
use validation::{validate_article_title, validate_search_query};

mod error_handler;
use error_handler::handle_rejection;

pub struct ApiServer {
    db_path: String,
    vector_store: Arc<VectorStore>,
    llm_service: Arc<LlmService>,
    allowed_origins: Vec<String>,
    rate_limiters: ApiRateLimiters,
}

/// Rate limiters for different API endpoints with different limits
#[derive(Clone)]
pub struct ApiRateLimiters {
    /// Standard rate limiter for most endpoints (100 requests per minute)
    standard: RateLimiter,
    /// More restrictive rate limiter for computationally expensive endpoints (20 requests per minute)
    restricted: RateLimiter,
    /// Very restrictive rate limiter for LLM endpoints (5 requests per minute)
    llm: RateLimiter,
}

impl Default for ApiRateLimiters {
    fn default() -> Self {
        Self {
            // 100 requests per minute
            standard: RateLimiter::new(100, 60),
            // 20 requests per minute
            restricted: RateLimiter::new(20, 60),
            // 5 requests per minute
            llm: RateLimiter::new(5, 60),
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SearchQuery {
    pub query: String,
    pub limit: Option<usize>,
    pub offset: Option<usize>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ArticleResponse {
    pub title: String,
    pub content: String,
    pub categories: Vec<String>,
    pub last_modified: String,
    pub size: usize,
}

impl ApiServer {
    pub fn new(db_path: &str, vector_store: Arc<VectorStore>, llm_service: Arc<LlmService>) -> Self {
        Self::with_origins(db_path, vector_store, llm_service, vec![
            "http://localhost".to_string(),
            "http://localhost:8080".to_string(),
            "http://127.0.0.1".to_string(),
            "http://127.0.0.1:8080".to_string(),
        ])
    }

    pub fn with_origins(
        db_path: &str, 
        vector_store: Arc<VectorStore>, 
        llm_service: Arc<LlmService>,
        allowed_origins: Vec<String>
    ) -> Self {
        Self {
            db_path: db_path.to_string(),
            vector_store,
            llm_service,
            allowed_origins,
            rate_limiters: ApiRateLimiters::default(),
        }
    }

    pub async fn run(&self, port: u16) -> WikiResult<()> {
        let db_path = self.db_path.clone();
        let vector_store = self.vector_store.clone();
        let llm_service = self.llm_service.clone();
        let allowed_origins = self.allowed_origins.clone();
        let rate_limiters = self.rate_limiters.clone();

        // Start cleanup tasks for rate limiters
        rate_limiters.standard.clone().start_cleanup(60).await;
        rate_limiters.restricted.clone().start_cleanup(60).await;
        rate_limiters.llm.clone().start_cleanup(60).await;

        // Create connection pool
        let db = Arc::new(Mutex::new(Connection::open(&db_path)?));

        // Define routes
        let api = warp::path("api");
        
        // GET /api/articles
        let articles_route = api
            .and(warp::path("articles"))
            .and(warp::get())
            .and(with_db(db.clone()))
            .and_then(handle_get_articles)
            .boxed();
        
        // Apply standard rate limiting
        let articles_route = with_rate_limiting(&rate_limiters.standard, articles_route);

        // GET /api/articles/:title
        let article_route = api
            .and(warp::path("articles"))
            .and(validate_article_title())
            .and(warp::path::param::<String>())
            .and(warp::get())
            .and(with_db(db.clone()))
            .and_then(handle_get_article)
            .boxed();
        
        // Apply standard rate limiting
        let article_route = with_rate_limiting(&rate_limiters.standard, article_route);

        // GET /api/search
        let search_route = api
            .and(warp::path("search"))
            .and(warp::get())
            .and(validate_search_query())
            .and(warp::query::<SearchQuery>())
            .and(with_db(db.clone()))
            .and_then(handle_search)
            .boxed();
        
        // Apply standard rate limiting
        let search_route = with_rate_limiting(&rate_limiters.standard, search_route);

        // GET /api/semantic-search
        let semantic_search_route = api
            .and(warp::path("semantic-search"))
            .and(warp::get())
            .and(validate_search_query())
            .and(warp::query::<SearchQuery>())
            .and(with_db(db.clone()))
            .and(with_vector_store(vector_store.clone()))
            .and_then(handle_semantic_search)
            .boxed();
        
        // Apply restricted rate limiting for computationally expensive endpoint
        let semantic_search_route = with_rate_limiting(&rate_limiters.restricted, semantic_search_route);

        // GET /api/articles/:title/summary
        let summary_route = api
            .and(warp::path("articles"))
            .and(validate_article_title())
            .and(warp::path::param::<String>())
            .and(warp::path("summary"))
            .and(warp::get())
            .and(with_db(db.clone()))
            .and(with_llm(llm_service.clone()))
            .and_then(handle_article_summary)
            .boxed();
        
        // Apply LLM rate limiting for the most expensive endpoint
        let summary_route = with_rate_limiting(&rate_limiters.llm, summary_route);

        // GET /api/status
        let status_route = api
            .and(warp::path("status"))
            .and(warp::get())
            .and_then(handle_status)
            .boxed();
        
        // Status endpoint has no rate limiting

        // Configure CORS with specific allowed origins
        let cors = warp::cors()
            .allow_methods(vec!["GET", "POST", "OPTIONS"])
            .allow_headers(vec!["Content-Type", "Authorization"])
            .max_age(86400) // 24 hours in seconds
            .allow_origins(allowed_origins.iter().map(|s| s.as_str()).collect::<Vec<&str>>());

        // Combine all routes
        let routes = articles_route
            .or(article_route)
            .or(search_route)
            .or(semantic_search_route)
            .or(summary_route)
            .or(status_route)
            .with(cors)
            .recover(handle_rejection); // Add error handling

        // Start the server
        warp::serve(routes).run(([127, 0, 0, 1], port)).await;
        
        Ok(())
    }
}

// Helper functions to provide context to handlers
fn with_db(db: Arc<Mutex<Connection>>) -> impl Filter<Extract = (Arc<Mutex<Connection>>,), Error = std::convert::Infallible> + Clone {
    warp::any().map(move || db.clone())
}

fn with_vector_store(store: Arc<VectorStore>) -> impl Filter<Extract = (Arc<VectorStore>,), Error = std::convert::Infallible> + Clone {
    warp::any().map(move || store.clone())
}

fn with_llm(llm: Arc<LlmService>) -> impl Filter<Extract = (Arc<LlmService>,), Error = std::convert::Infallible> + Clone {
    warp::any().map(move || llm.clone())
}

// Handler functions
async fn handle_get_articles(db: Arc<Mutex<Connection>>) -> Result<impl Reply, Rejection> {
    let conn = db.lock().await;
    let reader = DatabaseReader::new(&conn);
    
    match reader.get_articles(100) {
        Ok(articles) => {
            let response: Vec<ArticleResponse> = articles.into_iter()
                .map(|a| ArticleResponse {
                    title: a.title,
                    content: a.content,
                    categories: a.categories.into_iter().collect(),
                    last_modified: a.last_modified.to_rfc3339(),
                    size: a.size,
                })
                .collect();
            Ok(warp::reply::json(&response))
        },
        Err(_) => Err(warp::reject::not_found()),
    }
}

async fn handle_get_article(title: String, db: Arc<Mutex<Connection>>) -> Result<impl Reply, Rejection> {
    let conn = db.lock().await;
    let reader = DatabaseReader::new(&conn);
    
    match reader.get_article(&title) {
        Ok(Some(article)) => {
            let response = ArticleResponse {
                title: article.title,
                content: article.content,
                categories: article.categories.into_iter().collect(),
                last_modified: article.last_modified.to_rfc3339(),
                size: article.size,
            };
            Ok(warp::reply::json(&response))
        },
        Ok(None) => Err(warp::reject::not_found()),
        Err(_) => Err(warp::reject::not_found()),
    }
}

async fn handle_search(query: SearchQuery, db: Arc<Mutex<Connection>>) -> Result<impl Reply, Rejection> {
    let conn = db.lock().await;
    let reader = DatabaseReader::new(&conn);
    let limit = query.limit.unwrap_or(10);
    
    match reader.search_articles(&query.query, limit) {
        Ok(articles) => {
            let response: Vec<ArticleResponse> = articles.into_iter()
                .map(|a| ArticleResponse {
                    title: a.title,
                    content: a.content,
                    categories: a.categories.into_iter().collect(),
                    last_modified: a.last_modified.to_rfc3339(),
                    size: a.size,
                })
                .collect();
            Ok(warp::reply::json(&response))
        },
        Err(_) => Err(warp::reject::not_found()),
    }
}

async fn handle_semantic_search(
    query: SearchQuery, 
    db: Arc<Mutex<Connection>>, 
    vector_store: Arc<VectorStore>
) -> Result<impl Reply, Rejection> {
    // Generate embedding for the query
    let embedding = match vector_store.generate_embedding(&query.query).await {
        Ok(emb) => emb,
        Err(_) => return Err(warp::reject::not_found()),
    };
    
    // Find similar articles
    let limit = query.limit.unwrap_or(10);
    let similar = match vector_store.find_similar(&embedding, limit) {
        Ok(results) => results,
        Err(_) => return Err(warp::reject::not_found()),
    };
    
    // Get article details
    let conn = db.lock().await;
    let reader = DatabaseReader::new(&conn);
    
    let mut articles = Vec::new();
    for (title, _) in similar {
        if let Ok(Some(article)) = reader.get_article(&title) {
            articles.push(ArticleResponse {
                title: article.title,
                content: article.content,
                categories: article.categories.into_iter().collect(),
                last_modified: article.last_modified.to_rfc3339(),
                size: article.size,
            });
        }
    }
    
    Ok(warp::reply::json(&articles))
}

async fn handle_article_summary(
    title: String, 
    db: Arc<Mutex<Connection>>, 
    llm: Arc<LlmService>
) -> Result<impl Reply, Rejection> {
    // Get article
    let conn = db.lock().await;
    let reader = DatabaseReader::new(&conn);
    
    let article = match reader.get_article(&title) {
        Ok(Some(article)) => article,
        Ok(None) => return Err(warp::reject::not_found()),
        Err(_) => return Err(warp::reject::not_found()),
    };
    
    // Generate summary
    let prompt = format!(
        "Please provide a concise summary of the following Wikipedia article:\n\nTitle: {}\n\n{}",
        article.title, article.content
    );
    
    let summary = match llm.generate_text(&prompt).await {
        Ok(text) => text,
        Err(_) => return Err(warp::reject::not_found()),
    };
    
    Ok(warp::reply::json(&serde_json::json!({
        "title": article.title,
        "summary": summary,
    })))
}

async fn handle_status() -> Result<impl Reply, Rejection> {
    Ok(warp::reply::json(&serde_json::json!({
        "status": "ok",
        "version": env!("CARGO_PKG_VERSION"),
    })))
} 