#!/usr/bin/env python3

import argparse
import asyncio
import json
import os
import psutil
import sys
import time
import tracemalloc
from typing import Dict, List, Tuple
import urllib.request
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
import numpy as np
from web_scraper import process_urls, validate_url

# Set up Seaborn style for plots
sns.set_style('seaborn-v0_8')

TEST_URL_SETS = {
    'small': [
        'https://en.wikipedia.org/wiki/Python_(programming_language)',
        'https://en.wikipedia.org/wiki/Rust_(programming_language)',
        'https://en.wikipedia.org/wiki/JavaScript',
        'https://en.wikipedia.org/wiki/Go_(programming_language)',
        'https://en.wikipedia.org/wiki/TypeScript',
        'https://en.wikipedia.org/wiki/C%2B%2B',
        'https://en.wikipedia.org/wiki/Java_(programming_language)',
        'https://en.wikipedia.org/wiki/PHP',
        'https://en.wikipedia.org/wiki/Ruby_(programming_language)',
        'https://en.wikipedia.org/wiki/Swift_(programming_language)',
    ],
    'medium': [
        # Add 40 more Wikipedia article URLs for a total of 50
        'https://en.wikipedia.org/wiki/Python_(programming_language)',
        'https://en.wikipedia.org/wiki/Rust_(programming_language)',
        # ... and so on up to 50 URLs
    ],
    'large': [
        # Add 90 more Wikipedia article URLs for a total of 100
        'https://en.wikipedia.org/wiki/Python_(programming_language)',
        'https://en.wikipedia.org/wiki/Rust_(programming_language)',
        # ... and so on up to 100 URLs
    ],
    'xl': [
        # Add 190 more Wikipedia article URLs for a total of 200
        'https://en.wikipedia.org/wiki/Python_(programming_language)',
        'https://en.wikipedia.org/wiki/Rust_(programming_language)',
        # ... and so on up to 200 URLs
    ],
    'error': [
        # Valid URLs
        'https://en.wikipedia.org/wiki/Python_(programming_language)',
        # Invalid URLs
        'https://nonexistentwebsite123456789.com',
        # Timeout URLs (assume this will timeout)
        'https://example.com:81',
        # Malformed URLs
        'http://...',
        # URL with JavaScript error
        'javascript:alert("test")',
    ]
}

def get_process_memory() -> int:
    """Return the memory usage of the current process in MB."""
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / (1024 * 1024)

def get_cpu_usage() -> float:
    """Return the CPU usage percentage of the current process."""
    process = psutil.Process(os.getpid())
    return process.cpu_percent(interval=0.1)

async def run_benchmark(urls: List[str], max_concurrent: int) -> Dict:
    """Run a benchmark on the web scraper with the given URLs."""
    # Start memory tracking
    tracemalloc.start()
    start_memory = get_process_memory()
    
    # Start CPU tracking
    start_cpu = get_cpu_usage()
    
    # Start timing
    start_time = time.time()
    
    # Run the web scraper
    results = await process_urls(urls, max_concurrent)
    
    # Calculate metrics
    end_time = time.time()
    elapsed_time = end_time - start_time
    
    end_memory = get_process_memory()
    memory_used = end_memory - start_memory
    
    current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    
    end_cpu = get_cpu_usage()
    cpu_used = end_cpu - start_cpu
    
    # Count successful results
    success_count = 0
    for result in results:
        if result and len(result) > 0:
            success_count += 1
    
    # Return benchmark metrics
    return {
        'urls_count': len(urls),
        'max_concurrent': max_concurrent,
        'elapsed_time': elapsed_time,
        'memory_used_mb': memory_used,
        'peak_memory_mb': peak / (1024 * 1024),
        'cpu_usage': cpu_used,
        'success_rate': success_count / len(urls) if urls else 0,
        'avg_time_per_url': elapsed_time / len(urls) if urls else 0,
    }

async def run_concurrency_test(urls: List[str], concurrency_levels: List[int]) -> List[Dict]:
    """Run benchmarks with different concurrency levels."""
    results = []
    for concurrency in concurrency_levels:
        print(f"Running benchmark with concurrency level {concurrency}...")
        result = await run_benchmark(urls, concurrency)
        results.append(result)
        # Wait a bit to let resources clean up
        await asyncio.sleep(1)
    return results

def plot_results(results: List[Dict], output_dir: str):
    """Create visualizations of benchmark results."""
    os.makedirs(output_dir, exist_ok=True)
    
    # Convert results to DataFrame
    df = pd.DataFrame(results)
    
    # Plot time vs concurrency
    plt.figure(figsize=(12, 8))
    sns.lineplot(data=df, x='max_concurrent', y='elapsed_time', marker='o')
    plt.title('Scraping Time vs. Concurrency Level')
    plt.xlabel('Concurrency Level')
    plt.ylabel('Time (seconds)')
    plt.grid(True)
    plt.savefig(os.path.join(output_dir, 'time_vs_concurrency.png'))
    
    # Plot memory usage vs concurrency
    plt.figure(figsize=(12, 8))
    sns.lineplot(data=df, x='max_concurrent', y='memory_used_mb', marker='o', label='Memory Used')
    sns.lineplot(data=df, x='max_concurrent', y='peak_memory_mb', marker='s', label='Peak Memory')
    plt.title('Memory Usage vs. Concurrency Level')
    plt.xlabel('Concurrency Level')
    plt.ylabel('Memory (MB)')
    plt.legend()
    plt.grid(True)
    plt.savefig(os.path.join(output_dir, 'memory_vs_concurrency.png'))
    
    # Plot success rate vs concurrency
    plt.figure(figsize=(12, 8))
    sns.lineplot(data=df, x='max_concurrent', y='success_rate', marker='o')
    plt.title('Success Rate vs. Concurrency Level')
    plt.xlabel('Concurrency Level')
    plt.ylabel('Success Rate')
    plt.grid(True)
    plt.savefig(os.path.join(output_dir, 'success_vs_concurrency.png'))
    
    # Plot time per URL vs concurrency
    plt.figure(figsize=(12, 8))
    sns.lineplot(data=df, x='max_concurrent', y='avg_time_per_url', marker='o')
    plt.title('Average Time per URL vs. Concurrency Level')
    plt.xlabel('Concurrency Level')
    plt.ylabel('Time per URL (seconds)')
    plt.grid(True)
    plt.savefig(os.path.join(output_dir, 'time_per_url_vs_concurrency.png'))

async def main():
    parser = argparse.ArgumentParser(description='Benchmark web scraper performance')
    parser.add_argument('--dataset', choices=['small', 'medium', 'large', 'xl', 'error'], default='small',
                        help='Dataset size to use for testing (default: small)')
    parser.add_argument('--concurrency', type=str, default='1,3,5,10,20',
                        help='Comma-separated list of concurrency levels to test (default: 1,3,5,10,20)')
    parser.add_argument('--output-dir', type=str, default='benchmark_results',
                        help='Directory to save benchmark results (default: benchmark_results)')
    parser.add_argument('--plot', action='store_true',
                        help='Generate plots of benchmark results')
    
    args = parser.parse_args()
    
    # Parse concurrency levels
    concurrency_levels = [int(c) for c in args.concurrency.split(',')]
    
    # Get test URLs
    urls = TEST_URL_SETS.get(args.dataset, TEST_URL_SETS['small'])
    
    print(f"Running benchmarks with {len(urls)} URLs and concurrency levels: {concurrency_levels}")
    
    # Run benchmarks
    results = await run_concurrency_test(urls, concurrency_levels)
    
    # Save results to JSON
    os.makedirs(args.output_dir, exist_ok=True)
    results_file = os.path.join(args.output_dir, f'benchmark_{args.dataset}.json')
    with open(results_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"Benchmark results saved to {results_file}")
    
    # Print summary
    print("\nBenchmark Summary:")
    print("-" * 80)
    print(f"{'Concurrency':<15} {'Time (s)':<15} {'Memory (MB)':<15} {'Success Rate':<15} {'Time/URL (s)':<15}")
    print("-" * 80)
    for result in results:
        print(f"{result['max_concurrent']:<15} {result['elapsed_time']:<15.2f} {result['memory_used_mb']:<15.2f} {result['success_rate']:<15.2f} {result['avg_time_per_url']:<15.2f}")
    
    # Generate plots if requested
    if args.plot:
        plot_results(results, args.output_dir)
        print(f"Plots saved to {args.output_dir}")

if __name__ == '__main__':
    asyncio.run(main()) 