#[cfg(test)]
mod tests {
    use super::*;
    use std::net::IpAddr;
    use std::str::FromStr;
    use tokio::time::{sleep, Duration};
    use warp::test::request;
    use warp::http::StatusCode;

    #[tokio::test]
    async fn test_rate_limiter_allows_within_limit() {
        let rate_limiter = RateLimiter::new(5, 60);
        let ip = IpAddr::from_str("127.0.0.1").unwrap();
        
        // Should allow 5 requests in a row
        for _ in 0..5 {
            assert!(rate_limiter.is_allowed(ip).await);
        }
        
        // Should deny the 6th request
        assert!(!rate_limiter.is_allowed(ip).await);
    }
    
    #[tokio::test]
    async fn test_rate_limiter_reset_after_window() {
        let rate_limiter = RateLimiter::new(2, 1); // 2 requests per second
        let ip = IpAddr::from_str("127.0.0.1").unwrap();
        
        // Use up the quota
        assert!(rate_limiter.is_allowed(ip).await);
        assert!(rate_limiter.is_allowed(ip).await);
        assert!(!rate_limiter.is_allowed(ip).await);
        
        // Wait for the window to pass
        sleep(Duration::from_secs(1)).await;
        
        // Should be allowed again
        assert!(rate_limiter.is_allowed(ip).await);
    }
    
    #[tokio::test]
    async fn test_rate_limiter_retry_after() {
        let rate_limiter = RateLimiter::new(3, 10); // 3 requests per 10 seconds
        let ip = IpAddr::from_str("127.0.0.1").unwrap();
        
        // Use up the quota
        assert!(rate_limiter.is_allowed(ip).await);
        assert!(rate_limiter.is_allowed(ip).await);
        assert!(rate_limiter.is_allowed(ip).await);
        assert!(!rate_limiter.is_allowed(ip).await);
        
        // Should recommend waiting close to 10 seconds
        let retry_after = rate_limiter.retry_after(ip).await;
        assert!(retry_after > 0);
        assert!(retry_after <= 11); // Allow some flexibility in timing
    }
    
    #[tokio::test]
    async fn test_rate_limiter_different_ips() {
        let rate_limiter = RateLimiter::new(2, 60);
        let ip1 = IpAddr::from_str("127.0.0.1").unwrap();
        let ip2 = IpAddr::from_str("192.168.1.1").unwrap();
        
        // Both IPs should be allowed their quota independently
        assert!(rate_limiter.is_allowed(ip1).await);
        assert!(rate_limiter.is_allowed(ip1).await);
        assert!(!rate_limiter.is_allowed(ip1).await);
        
        assert!(rate_limiter.is_allowed(ip2).await);
        assert!(rate_limiter.is_allowed(ip2).await);
        assert!(!rate_limiter.is_allowed(ip2).await);
    }
    
    #[tokio::test]
    async fn test_rate_limiter_cleanup() {
        let rate_limiter = RateLimiter::new(2, 1); // 2 requests per second
        let ip1 = IpAddr::from_str("127.0.0.1").unwrap();
        let ip2 = IpAddr::from_str("192.168.1.1").unwrap();
        
        // Add some requests
        rate_limiter.is_allowed(ip1).await;
        rate_limiter.is_allowed(ip2).await;
        
        // Both IPs should have entries
        {
            let history = rate_limiter.request_history.lock().await;
            assert_eq!(history.len(), 2);
        }
        
        // Wait for window to pass
        sleep(Duration::from_secs(1)).await;
        
        // Run cleanup
        rate_limiter.cleanup().await;
        
        // Both IPs should be removed since their timestamps expired
        {
            let history = rate_limiter.request_history.lock().await;
            assert_eq!(history.len(), 0);
        }
    }
    
    #[tokio::test]
    async fn test_with_rate_limiting_filter() {
        // Create a rate limiter
        let rate_limiter = RateLimiter::new(2, 60);
        
        // Create a simple test route
        let route = warp::any()
            .map(|| "Hello, World!")
            .boxed();
        
        // Apply rate limiting
        let limited_route = rate_limiter.with_rate_limiting(route);
        
        // First request should pass with 200 OK
        let resp1 = request()
            .method("GET")
            .path("/")
            .remote_addr(([127, 0, 0, 1], 8080))
            .reply(&limited_route)
            .await;
        assert_eq!(resp1.status(), StatusCode::OK);
        assert_eq!(resp1.body(), "Hello, World!");
        
        // Second request should pass with 200 OK
        let resp2 = request()
            .method("GET")
            .path("/")
            .remote_addr(([127, 0, 0, 1], 8080))
            .reply(&limited_route)
            .await;
        assert_eq!(resp2.status(), StatusCode::OK);
        assert_eq!(resp2.body(), "Hello, World!");
        
        // Third request should be rate limited with 429 Too Many Requests
        let resp3 = request()
            .method("GET")
            .path("/")
            .remote_addr(([127, 0, 0, 1], 8080))
            .reply(&limited_route)
            .await;
        assert_eq!(resp3.status(), StatusCode::TOO_MANY_REQUESTS);
        assert!(resp3.headers().contains_key("retry-after"));
    }
} 