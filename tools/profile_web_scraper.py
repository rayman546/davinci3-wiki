#!/usr/bin/env python3

import cProfile
import pstats
import io
import asyncio
import gc
import psutil
import os
import time
import tracemalloc
from web_scraper import process_urls, validate_url

# Sample URLs from the small dataset
TEST_URLS = [
    'https://en.wikipedia.org/wiki/Python_(programming_language)',
    'https://en.wikipedia.org/wiki/Rust_(programming_language)',
    'https://en.wikipedia.org/wiki/JavaScript',
    'https://en.wikipedia.org/wiki/Go_(programming_language)',
    'https://en.wikipedia.org/wiki/TypeScript',
]

def get_process_memory_mb():
    """Return the memory usage of the current process in MB."""
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / (1024 * 1024)

async def measure_performance(urls, max_concurrent):
    """Measure the performance of the web scraper."""
    # Start tracking memory
    tracemalloc.start()
    gc.collect()  # Force garbage collection before starting
    
    start_memory = get_process_memory_mb()
    print(f"Starting memory usage: {start_memory:.2f} MB")
    
    # Start timing
    start_time = time.time()
    
    # Run the web scraper
    print(f"Processing {len(urls)} URLs with concurrency {max_concurrent}...")
    results = await process_urls(urls, max_concurrent)
    
    # Calculate metrics
    end_time = time.time()
    elapsed_time = end_time - start_time
    
    end_memory = get_process_memory_mb()
    memory_used = end_memory - start_memory
    
    current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    
    # Calculate processing stats
    success_count = sum(1 for r in results if r and len(r) > 0)
    avg_content_length = sum(len(r) if r else 0 for r in results) / max(1, success_count)
    
    # Print results
    print("\nPerformance Results:")
    print(f"Total time: {elapsed_time:.2f} seconds")
    print(f"Time per URL: {elapsed_time / len(urls):.2f} seconds")
    print(f"Additional memory used: {memory_used:.2f} MB")
    print(f"Peak memory: {peak / (1024 * 1024):.2f} MB")
    print(f"Success rate: {success_count}/{len(urls)} ({success_count / len(urls) * 100:.1f}%)")
    print(f"Average content length: {avg_content_length:.0f} characters")
    
    return elapsed_time, memory_used, success_count

async def profile_html_parsing():
    """Profile the HTML parsing function specifically."""
    from web_scraper import _parse_html_impl
    
    print("\nProfiling HTML parsing...")
    
    # Get a sample HTML to parse
    try:
        results = await process_urls([TEST_URLS[0]], 1)
        html = results[0]
        if not html:
            print("Failed to fetch HTML sample for profiling")
            return
        
        # Set up profiler
        pr = cProfile.Profile()
        pr.enable()
        
        # Parse HTML multiple times to get better statistics
        for _ in range(5):
            result = _parse_html_impl(html)
        
        pr.disable()
        
        # Print stats
        s = io.StringIO()
        ps = pstats.Stats(pr, stream=s).sort_stats('cumulative')
        ps.print_stats(20)  # Print top 20 functions by cumulative time
        print(s.getvalue())
    except Exception as e:
        print(f"Error during HTML parsing profiling: {e}")

async def main():
    """Run performance tests with different concurrency levels."""
    print("Web Scraper Performance Analysis")
    print("================================")
    
    # Test with different concurrency levels
    for concurrency in [1, 3, 5]:
        print(f"\nTesting with concurrency level: {concurrency}")
        await measure_performance(TEST_URLS, concurrency)
    
    # Profile HTML parsing specifically
    await profile_html_parsing()

if __name__ == "__main__":
    asyncio.run(main()) 