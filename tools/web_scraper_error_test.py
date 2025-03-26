#!/usr/bin/env python3

import asyncio
import json
import os
import sys
import time
import traceback
from typing import Dict, List, Optional
from web_scraper import process_urls, validate_url, fetch_page, parse_html
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    stream=sys.stderr
)
logger = logging.getLogger(__name__)

# Test URLs with different error conditions
ERROR_TEST_URLS = [
    # Valid URL
    "https://en.wikipedia.org/wiki/Python_(programming_language)",
    
    # Non-existent domain
    "https://nonexistent-domain-12345.com",
    
    # Invalid URL format
    "not_a_url",
    
    # URL that should time out
    "https://example.com:81",
    
    # Malformed URL
    "http://...",
    
    # Invalid protocol
    "file:///etc/passwd",
    
    # JavaScript URL
    "javascript:alert('test')",
    
    # URL with special characters
    "https://example.com/<script>alert('xss')</script>",
    
    # Very long URL (potentially problematic)
    "https://example.com/" + "a" * 2000,
    
    # URL with HTTP auth credentials (potentially problematic)
    "https://user:password@example.com",
]

async def test_error_handling():
    """Test error handling in the web scraper."""
    results = {
        'valid_url_count': 0,
        'validation_failures': 0,
        'fetch_failures': 0,
        'parse_failures': 0,
        'success_count': 0,
        'details': []
    }
    
    for url in ERROR_TEST_URLS:
        # Reset for this test
        error_stage = None
        error_message = None
        content = None
        parsed_content = None
        
        try:
            # Test URL validation
            is_valid = validate_url(url)
            if not is_valid:
                results['validation_failures'] += 1
                error_stage = 'validation'
                error_message = 'URL failed validation'
                continue
            
            results['valid_url_count'] += 1
            
            # Test fetch_page using process_urls
            try:
                start_time = time.time()
                scraped_content = await process_urls([url], max_concurrent=1)
                elapsed_time = time.time() - start_time
                
                if not scraped_content or not scraped_content[0]:
                    results['fetch_failures'] += 1
                    error_stage = 'fetch'
                    error_message = 'Failed to fetch content'
                    continue
                
                content = scraped_content[0]
                results['success_count'] += 1
            except Exception as e:
                results['fetch_failures'] += 1
                error_stage = 'fetch'
                error_message = str(e)
                continue
            
        except Exception as e:
            error_stage = 'unknown'
            error_message = str(e)
        
        # Log results for this URL
        results['details'].append({
            'url': url,
            'valid': is_valid,
            'error_stage': error_stage,
            'error_message': error_message,
            'content_length': len(content) if content else 0,
            'elapsed_time': elapsed_time if 'elapsed_time' in locals() else None,
        })
        
        logger.info(f"Tested URL: {url} - Error stage: {error_stage or 'none'}")
    
    return results

async def test_error_isolation():
    """Test that errors in one URL don't affect others."""
    # Mix of good and bad URLs
    urls = [
        "https://en.wikipedia.org/wiki/Python_(programming_language)",
        "https://nonexistent-domain-12345.com",
        "https://en.wikipedia.org/wiki/JavaScript",
        "not_a_url",
        "https://en.wikipedia.org/wiki/Rust_(programming_language)",
    ]
    
    start_time = time.time()
    try:
        results = await process_urls(urls, max_concurrent=3)
        success = True
    except Exception as e:
        logger.error(f"Process failed with exception: {e}")
        traceback.print_exc()
        results = []
        success = False
    
    elapsed_time = time.time() - start_time
    
    # Count successful scrapes
    success_count = 0
    for result in results:
        if result and len(result) > 0:
            success_count += 1
    
    isolation_results = {
        'all_urls_processed': len(results) == len(urls),
        'any_successful': success_count > 0,
        'success_count': success_count,
        'total_count': len(urls),
        'overall_success': success,
        'elapsed_time': elapsed_time,
    }
    
    return isolation_results

async def test_resource_cleanup():
    """Test that resources are properly cleaned up after errors."""
    import psutil
    import gc
    
    process = psutil.Process(os.getpid())
    
    # Force garbage collection
    gc.collect()
    
    # Measure baseline memory
    start_memory = process.memory_info().rss / (1024 * 1024)
    
    # Run error-prone URLs
    for _ in range(3):  # Run multiple times to detect leaks
        await process_urls(ERROR_TEST_URLS, max_concurrent=2)
        
        # Force garbage collection again
        gc.collect()
    
    # Measure memory after tests
    end_memory = process.memory_info().rss / (1024 * 1024)
    
    # Check if memory usage has significantly increased
    memory_diff = end_memory - start_memory
    
    cleanup_results = {
        'start_memory_mb': start_memory,
        'end_memory_mb': end_memory,
        'memory_diff_mb': memory_diff,
        'significant_leak': memory_diff > 10,  # Consider >10MB a significant leak
    }
    
    return cleanup_results

async def main():
    """Run all error tests and output results."""
    os.makedirs('test_results', exist_ok=True)
    
    logger.info("Testing error handling...")
    error_results = await test_error_handling()
    
    logger.info("Testing error isolation...")
    isolation_results = await test_error_isolation()
    
    logger.info("Testing resource cleanup...")
    cleanup_results = await test_resource_cleanup()
    
    # Combine all results
    all_results = {
        'error_handling': error_results,
        'error_isolation': isolation_results,
        'resource_cleanup': cleanup_results,
    }
    
    # Save results to JSON
    with open('test_results/error_test_results.json', 'w') as f:
        json.dump(all_results, f, indent=2)
    
    # Print summary
    print("\nError Test Summary:")
    print("-" * 80)
    print(f"URLs tested: {len(ERROR_TEST_URLS)}")
    print(f"Valid URLs: {error_results['valid_url_count']}")
    print(f"Validation failures: {error_results['validation_failures']}")
    print(f"Fetch failures: {error_results['fetch_failures']}")
    print(f"Successful scrapes: {error_results['success_count']}")
    print("\nError Isolation:")
    print(f"All URLs processed: {isolation_results['all_urls_processed']}")
    print(f"Success count: {isolation_results['success_count']} / {isolation_results['total_count']}")
    print("\nResource Cleanup:")
    print(f"Memory difference: {cleanup_results['memory_diff_mb']:.2f} MB")
    print(f"Significant leak detected: {cleanup_results['significant_leak']}")
    
    # Calculate overall test result
    passed = (
        error_results['success_count'] > 0 and
        isolation_results['any_successful'] and
        not cleanup_results['significant_leak']
    )
    
    print("-" * 80)
    if passed:
        print("OVERALL RESULT: PASSED")
        return 0
    else:
        print("OVERALL RESULT: FAILED")
        return 1

if __name__ == '__main__':
    sys.exit(asyncio.run(main())) 