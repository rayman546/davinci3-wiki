use std::collections::HashMap;
use std::net::IpAddr;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::Mutex;
use warp::Filter;
use warp::filters::BoxedFilter;
use warp::http::StatusCode;
use warp::reject::Rejection;
use warp::reply::Reply;
use serde::Serialize;

/// Rate limiter using a sliding window algorithm
#[derive(Debug, Clone)]
pub struct RateLimiter {
    /// Maximum number of requests allowed in the window
    max_requests: usize,
    /// Window duration in seconds
    window_secs: u64,
    /// Stores request timestamps for each IP
    request_history: Arc<Mutex<HashMap<IpAddr, Vec<Instant>>>>,
}

#[derive(Debug, Serialize)]
pub struct RateLimitExceededResponse {
    pub status: String,
    pub message: String,
    pub retry_after: u64,
}

impl RateLimiter {
    pub fn new(max_requests: usize, window_secs: u64) -> Self {
        Self {
            max_requests,
            window_secs,
            request_history: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Check if a request from IP is allowed, and update request history
    pub async fn is_allowed(&self, ip: IpAddr) -> bool {
        let mut history = self.request_history.lock().await;
        let now = Instant::now();
        let window_duration = Duration::from_secs(self.window_secs);
        
        // Get or create history for this IP
        let timestamps = history.entry(ip).or_insert_with(Vec::new);
        
        // Remove timestamps outside the window
        let cutoff = now.checked_sub(window_duration).unwrap_or(now);
        timestamps.retain(|&timestamp| timestamp >= cutoff);
        
        // Check if under limit
        if timestamps.len() < self.max_requests {
            // Add current timestamp and allow
            timestamps.push(now);
            true
        } else {
            // Over limit, deny
            false
        }
    }
    
    /// Get seconds until next available request slot
    pub async fn retry_after(&self, ip: IpAddr) -> u64 {
        let history = self.request_history.lock().await;
        let now = Instant::now();
        let window_duration = Duration::from_secs(self.window_secs);
        
        if let Some(timestamps) = history.get(&ip) {
            if timestamps.len() >= self.max_requests && !timestamps.is_empty() {
                // Get oldest timestamp
                let oldest = timestamps[0];
                let time_passed = now.duration_since(oldest);
                
                if time_passed < window_duration {
                    let wait_time = window_duration.checked_sub(time_passed);
                    return wait_time.map_or(0, |t| t.as_secs() + 1);
                }
            }
        }
        
        0 // No waiting needed
    }
    
    /// Periodically clean up expired entries
    pub async fn start_cleanup(self, interval_secs: u64) {
        let cleanup_interval = Duration::from_secs(interval_secs);
        
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(cleanup_interval);
            
            loop {
                interval.tick().await;
                self.cleanup().await;
            }
        });
    }
    
    /// Clean up expired entries
    async fn cleanup(&self) {
        let mut history = self.request_history.lock().await;
        let now = Instant::now();
        let window_duration = Duration::from_secs(self.window_secs);
        let cutoff = now.checked_sub(window_duration).unwrap_or(now);
        
        // Remove expired entries for each IP
        let mut empty_ips = Vec::new();
        
        for (ip, timestamps) in history.iter_mut() {
            timestamps.retain(|&timestamp| timestamp >= cutoff);
            
            if timestamps.is_empty() {
                empty_ips.push(*ip);
            }
        }
        
        // Remove IPs with no timestamps
        for ip in empty_ips {
            history.remove(&ip);
        }
    }
    
    /// Create a warp filter that applies rate limiting
    pub fn with_rate_limiting<T: Reply + Send>(
        &self,
        route: BoxedFilter<(T,)>,
    ) -> BoxedFilter<(impl Reply,)> {
        let rate_limiter = self.clone();
        
        warp::any()
            .and(route)
            .and(warp::addr::remote())
            .and_then(move |reply: T, addr: Option<std::net::SocketAddr>| {
                let rate_limiter = rate_limiter.clone();
                async move {
                    // Get IP from request or use a default
                    let ip = addr
                        .map(|socket_addr| socket_addr.ip())
                        .unwrap_or_else(|| IpAddr::from([127, 0, 0, 1]));
                    
                    // Check if request is allowed
                    if rate_limiter.is_allowed(ip).await {
                        // Request allowed, return original reply
                        Ok(warp::reply::with_header(
                            reply,
                            "X-RateLimit-Remaining",
                            (rate_limiter.max_requests - 1).to_string(),
                        ))
                    } else {
                        // Request denied, return 429 Too Many Requests
                        let retry_after = rate_limiter.retry_after(ip).await;
                        let response = RateLimitExceededResponse {
                            status: "error".to_string(),
                            message: "Rate limit exceeded. Please try again later.".to_string(),
                            retry_after,
                        };
                        
                        let json = warp::reply::json(&response);
                        let reply = warp::reply::with_status(json, StatusCode::TOO_MANY_REQUESTS);
                        let reply = warp::reply::with_header(
                            reply,
                            "Retry-After",
                            retry_after.to_string(),
                        );
                        
                        Ok(reply)
                    }
                }
            })
            .boxed()
    }
}

/// Warp filter that applies rate limiting to a route
pub fn with_rate_limiting<T: Reply + Send>(
    rate_limiter: &RateLimiter,
    route: BoxedFilter<(T,)>,
) -> BoxedFilter<(impl Reply,)> {
    rate_limiter.with_rate_limiting(route)
}

#[cfg(test)]
mod tests; 