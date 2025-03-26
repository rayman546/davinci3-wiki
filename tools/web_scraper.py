#!/usr/bin/env /workspace/tmp_windsurf/venv/bin/python3

import asyncio
import argparse
import sys
import os
from typing import List, Optional
from playwright.async_api import async_playwright
import html5lib
import time
from urllib.parse import urlparse
import logging
import re

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    stream=sys.stderr
)
logger = logging.getLogger(__name__)

async def fetch_page(url: str, context) -> Optional[str]:
    """Asynchronously fetch a webpage's content."""
    page = await context.new_page()
    try:
        logger.info(f"Fetching {url}")
        await page.goto(url)
        await page.wait_for_load_state('networkidle')
        content = await page.content()
        logger.info(f"Successfully fetched {url}")
        return content
    except Exception as e:
        logger.error(f"Error fetching {url}: {str(e)}")
        return None
    finally:
        await page.close()

async def parse_html(html_content: Optional[str], url: str = "Unknown URL") -> str:
    """Parse HTML content and extract text with hyperlinks in markdown format."""
    if not html_content:
        return ""
    
    try:
        # Run the CPU-intensive parsing in a thread pool to avoid blocking the event loop
        return await asyncio.to_thread(_parse_html_impl, html_content, url)
    except Exception as e:
        logger.error(f"Error parsing HTML: {str(e)}")
        return ""

# Precompiled regex patterns for filtering
noise_patterns = [
    re.compile(r'function\(\)'),
    re.compile(r'\.ready\('),
    re.compile(r'<!\[CDATA\['),
    re.compile(r'\]\]>'),
    re.compile(r'on(load|click|mouseover|mouseout|submit|focus|blur)'),
    re.compile(r'javascript:'),
    re.compile(r'style='),
    re.compile(r'class='),
    re.compile(r'id='),
    re.compile(r'\.getElementById'),
    re.compile(r'\.getElementsBy'),
    re.compile(r'document\.'),
    re.compile(r'window\.'),
    re.compile(r'\$\('),
]

def _parse_html_impl(html_content: str, url: str = "Unknown URL") -> str:
    """Parse HTML content using html5lib and extract relevant text."""
    try:
        # Use html5lib parser for better HTML parsing
        parsed_html = html5lib.parse(html_content, namespaceHTMLElements=False)
        
        # Define constants for commonly used tags
        script_tag = "script"
        style_tag = "style"
        body_tag = "body"
        anchor_tag = "a"
        meta_tag = "meta"
        title_tag = "title"
        
        # Cache for indentation strings
        indent_cache = {}
        
        # Set to track seen text to avoid duplicates
        seen_texts = set()
        
        # Check if an element should be skipped
        def should_skip_element(element):
            if element.tag in (script_tag, style_tag):
                return True
            
            # Skip empty elements
            if not element.text and not list(element):
                return True
                
            # Skip elements with only whitespace
            if element.text and element.text.strip() == "" and not list(element):
                return True
                
            return False
        
        # Process an element and its children recursively
        def process_element(element, indentation=0):
            result = []
            
            # Get indentation string from cache or create it
            if indentation not in indent_cache:
                indent_cache[indentation] = "  " * indentation
            indent = indent_cache[indentation]
            
            # Handle text content
            if element.text and element.text.strip():
                text = element.text.strip()
                # Use hash for faster duplicate check
                text_hash = hash(text)
                if text_hash not in seen_texts:
                    seen_texts.add(text_hash)
                    result.append(f"{indent}{text}")
            
            # Process children
            for child in element:
                if not should_skip_element(child):
                    child_result = process_element(child, indentation + 1)
                    if child_result:
                        result.extend(child_result)
                
                # Handle tail text (text after the element)
                if child.tail and child.tail.strip():
                    tail = child.tail.strip()
                    # Use hash for faster duplicate check
                    tail_hash = hash(tail)
                    if tail_hash not in seen_texts:
                        seen_texts.add(tail_hash)
                        result.append(f"{indent}{tail}")
            
            return result
        
        # Extract metadata (title, description)
        metadata = []
        title_element = parsed_html.find(f".//{title_tag}")
        if title_element is not None and title_element.text:
            metadata.append(f"Title: {title_element.text.strip()}")
        
        # Look for meta description
        for meta in parsed_html.findall(f".//{meta_tag}"):
            if meta.get("name", "").lower() == "description" and meta.get("content"):
                metadata.append(f"Description: {meta.get('content').strip()}")
                break
        
        # Add URL
        metadata.append(f"URL: {url}")
        
        # Extract body content or full document if body not found
        body = parsed_html.find(f".//{body_tag}")
        if body is None:
            body = parsed_html
            
        # Process the document
        content = process_element(body)
        
        # Combine metadata and content
        result = metadata + [""] + content
        
        # Efficient filtering for common noise patterns
        filtered_result = []
        for line in result:
            skip = False
            # Check each pattern against the line
            for pattern in noise_patterns:
                if pattern.search(line):
                    skip = True
                    break
            if not skip:
                filtered_result.append(line)
        
        return "\n".join(filtered_result)
    except Exception as e:
        logger.error(f"Error parsing HTML: {str(e)}")
        # Return minimal data on parsing error
        return f"URL: {url}\n\nError parsing content: {str(e)}"

async def process_urls(urls: List[str], max_concurrent: int = 5) -> List[str]:
    """Process multiple URLs concurrently."""
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        try:
            # Create browser contexts
            n_contexts = min(len(urls), max_concurrent)
            contexts = [await browser.new_context() for _ in range(n_contexts)]
            
            # Create tasks for each URL
            fetch_tasks = []
            for i, url in enumerate(urls):
                context = contexts[i % len(contexts)]
                task = fetch_page(url, context)
                fetch_tasks.append(task)
            
            # Gather HTML contents
            html_contents = await asyncio.gather(*fetch_tasks)
            
            # Parse HTML contents using asyncio tasks instead of multiprocessing
            parse_tasks = [parse_html(content, url) for content, url in zip(html_contents, urls)]
            results = await asyncio.gather(*parse_tasks)
            
            return results
            
        finally:
            # Cleanup
            for context in contexts:
                await context.close()
            await browser.close()

def validate_url(url: str) -> bool:
    """Validate if the given string is a valid URL."""
    try:
        result = urlparse(url)
        return all([result.scheme, result.netloc])
    except:
        return False

def main():
    parser = argparse.ArgumentParser(description='Fetch and extract text content from webpages.')
    parser.add_argument('urls', nargs='+', help='URLs to process')
    parser.add_argument('--max-concurrent', type=int, default=5,
                       help='Maximum number of concurrent browser instances (default: 5)')
    parser.add_argument('--debug', action='store_true',
                       help='Enable debug logging')
    
    args = parser.parse_args()
    
    if args.debug:
        logger.setLevel(logging.DEBUG)
    
    # Validate URLs
    valid_urls = []
    for url in args.urls:
        if validate_url(url):
            valid_urls.append(url)
        else:
            logger.error(f"Invalid URL: {url}")
    
    if not valid_urls:
        logger.error("No valid URLs provided")
        sys.exit(1)
    
    start_time = time.time()
    try:
        results = asyncio.run(process_urls(valid_urls, args.max_concurrent))
        
        # Print results to stdout
        for url, text in zip(valid_urls, results):
            print(f"\n=== Content from {url} ===")
            print(text)
            print("=" * 80)
        
        logger.info(f"Total processing time: {time.time() - start_time:.2f}s")
        
    except Exception as e:
        logger.error(f"Error during execution: {str(e)}")
        sys.exit(1)

if __name__ == '__main__':
    main() 