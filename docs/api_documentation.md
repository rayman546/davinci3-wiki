# Davinci3 Wiki API Documentation

## Overview

The Davinci3 Wiki system provides a RESTful API that allows developers to interact with the system programmatically. This document details the available endpoints, request parameters, response formats, and usage examples.

## Base URL

All API endpoints are accessible through the base URL:

```
http://localhost:8080
```

You can configure a different host or port when starting the server:

```bash
davinci3-wiki start --host 0.0.0.0 --port 9090
```

## Authentication

The API does not currently require authentication as it is designed to run locally. If exposing the API to a network, consider using a reverse proxy with authentication.

## API Endpoints

### Articles

#### List Articles

```
GET /articles
```

Returns a paginated list of articles.

**Parameters:**

| Parameter | Type   | Required | Description                                 |
|-----------|--------|----------|---------------------------------------------|
| page      | number | No       | Page number (default: 1)                    |
| limit     | number | No       | Number of articles per page (default: 20)   |
| sort      | string | No       | Sort order ('title' or 'id', default: 'id') |

**Response:**

```json
{
  "total": 1000,
  "pages": 50,
  "current_page": 1,
  "articles": [
    {
      "id": "12345",
      "title": "Example Article",
      "snippet": "This is a summary of the example article...",
      "updated_at": "2023-05-15T00:00:00Z"
    },
    // More articles...
  ]
}
```

**Example:**

```bash
curl "http://localhost:8080/articles?page=2&limit=10"
```

#### Get Article by ID

```
GET /articles/:id
```

Returns a specific article by its ID.

**Parameters:**

| Parameter | Type   | Required | Description                |
|-----------|--------|----------|----------------------------|
| id        | string | Yes      | The unique ID of the article |

**Response:**

```json
{
  "id": "12345",
  "title": "Example Article",
  "content": "Full content of the article in HTML format...",
  "categories": ["Science", "Technology"],
  "updated_at": "2023-05-15T00:00:00Z"
}
```

**Example:**

```bash
curl "http://localhost:8080/articles/12345"
```

#### Get Related Articles

```
GET /articles/:id/related
```

Returns a list of articles related to the specified article.

**Parameters:**

| Parameter | Type   | Required | Description                  |
|-----------|--------|----------|------------------------------|
| id        | string | Yes      | The unique ID of the article |
| limit     | number | No       | Maximum number of related articles to return (default: 5) |

**Response:**

```json
[
  {
    "id": "67890",
    "title": "Related Article 1",
    "snippet": "This is a summary of the related article...",
    "similarity_score": 0.85
  },
  // More related articles...
]
```

**Example:**

```bash
curl "http://localhost:8080/articles/12345/related?limit=3"
```

### Search

#### Keyword Search

```
GET /search
```

Performs a keyword-based search using full-text search.

**Parameters:**

| Parameter | Type   | Required | Description                                |
|-----------|--------|----------|-------------------------------------------|
| q         | string | Yes      | Search query                              |
| page      | number | No       | Page number (default: 1)                   |
| limit     | number | No       | Results per page (default: 20)             |

**Response:**

```json
{
  "total": 120,
  "pages": 6,
  "current_page": 1,
  "results": [
    {
      "id": "12345",
      "title": "Example Article",
      "snippet": "...matched text with <b>highlighted</b> keywords...",
      "score": 0.95
    },
    // More results...
  ]
}
```

**Example:**

```bash
curl "http://localhost:8080/search?q=quantum%20physics&page=1&limit=10"
```

#### Semantic Search

```
GET /semantic-search
```

Performs a semantic search using vector embeddings.

**Parameters:**

| Parameter | Type   | Required | Description                                 |
|-----------|--------|----------|---------------------------------------------|
| q         | string | Yes      | Search query                               |
| page      | number | No       | Page number (default: 1)                    |
| limit     | number | No       | Results per page (default: 20)              |

**Response:**

```json
{
  "total": 50,
  "pages": 3,
  "current_page": 1,
  "results": [
    {
      "id": "12345",
      "title": "Example Article",
      "snippet": "Summary of the semantically similar article...",
      "similarity": 0.89
    },
    // More results...
  ]
}
```

**Example:**

```bash
curl "http://localhost:8080/semantic-search?q=how%20do%20black%20holes%20form&limit=5"
```

### LLM Integration

#### Generate Summary

```
GET /articles/:id/summary
```

Generates a summary of the specified article using the LLM.

**Parameters:**

| Parameter | Type   | Required | Description                  |
|-----------|--------|----------|------------------------------|
| id        | string | Yes      | The unique ID of the article |
| length    | string | No       | Summary length ('short', 'medium', 'long'; default: 'medium') |

**Response:**

```json
{
  "article_id": "12345",
  "article_title": "Example Article",
  "summary": "Concise summary of the article generated by the LLM...",
  "length": "medium"
}
```

**Example:**

```bash
curl "http://localhost:8080/articles/12345/summary?length=short"
```

#### Ask Question About Article

```
GET /articles/:id/ask
```

Answers a question about the specified article using the LLM.

**Parameters:**

| Parameter | Type   | Required | Description                  |
|-----------|--------|----------|------------------------------|
| id        | string | Yes      | The unique ID of the article |
| q         | string | Yes      | The question to ask          |

**Response:**

```json
{
  "article_id": "12345",
  "article_title": "Example Article",
  "question": "What is the main topic?",
  "answer": "The main topic of this article is..."
}
```

**Example:**

```bash
curl "http://localhost:8080/articles/12345/ask?q=What%20is%20the%20main%20topic%3F"
```

### System Information

#### Get System Status

```
GET /status
```

Returns information about the system status.

**Response:**

```json
{
  "version": "1.0.0",
  "status": "running",
  "database_status": "connected",
  "article_count": 10000,
  "ollama_status": "connected",
  "ollama_version": "0.1.14",
  "memory_usage": {
    "used_mb": 256,
    "total_mb": 8192
  },
  "disk_usage": {
    "database_mb": 500,
    "vector_store_mb": 200,
    "total_mb": 700
  }
}
```

**Example:**

```bash
curl "http://localhost:8080/status"
```

## Error Handling

The API returns standard HTTP status codes to indicate success or failure:

- `200 OK`: Request succeeded
- `400 Bad Request`: Invalid request parameters
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server error

Error responses include a JSON object with details:

```json
{
  "error": {
    "code": "ARTICLE_NOT_FOUND",
    "message": "Article with ID 12345 not found",
    "details": {
      "id": "12345"
    }
  }
}
```

## Rate Limiting

The API currently does not implement rate limiting as it is designed for local usage. If you expose the API to a network, consider implementing rate limiting using a reverse proxy.

## API Versioning

The current API is version 1 and is not explicitly versioned in the URL. Future versions will include a version prefix (e.g., `/v2/articles`).

## Pagination

Endpoints that return lists support pagination through the following parameters:

- `page`: Page number (starting from 1)
- `limit`: Number of items per page

Responses include pagination metadata:

- `total`: Total number of items
- `pages`: Total number of pages
- `current_page`: Current page number

## CORS Support

The API has CORS configured for security with the following settings:

- **Allowed Origins**: By default, only localhost origins are allowed (`http://localhost`, `http://localhost:8080`, `http://127.0.0.1`, `http://127.0.0.1:8080`)
- **Allowed Methods**: GET, POST, OPTIONS
- **Allowed Headers**: Content-Type, Authorization
- **Max Age**: 86400 seconds (24 hours)

If you need to expose the API to other origins, you must modify the allowed origins list in the server configuration. 

### Security Warning

⚠️ **Important**: If you expose this API publicly, be aware of the following security considerations:

1. The API is designed primarily for local use
2. No authentication is implemented by default
3. Consider using a reverse proxy with authentication if exposing to the internet
4. Restrict CORS to only the specific origins that need access
5. Implement rate limiting to prevent abuse

To customize CORS settings, modify the `ApiServer::with_origins` method in `src/api/mod.rs`.

## Websocket API

In addition to the REST API, Davinci3 Wiki provides a WebSocket endpoint for real-time notifications.

```
ws://localhost:8080/ws
```

### Events

The WebSocket API emits the following events:

#### Installation Progress

```json
{
  "type": "installation_progress",
  "data": {
    "stage": "downloading",
    "progress": 45,
    "message": "Downloading Wikipedia dump (45%)"
  }
}
```

#### Search Progress

```json
{
  "type": "search_progress",
  "data": {
    "query_id": "abc123",
    "progress": 100,
    "message": "Search completed",
    "results_count": 15
  }
}
```

## Example Usage: Python Client

```python
import requests

BASE_URL = "http://localhost:8080"

def search_articles(query, is_semantic=False):
    endpoint = "/semantic-search" if is_semantic else "/search"
    response = requests.get(f"{BASE_URL}{endpoint}", params={"q": query, "limit": 5})
    response.raise_for_status()
    return response.json()

def get_article(article_id):
    response = requests.get(f"{BASE_URL}/articles/{article_id}")
    response.raise_for_status()
    return response.json()

def ask_question(article_id, question):
    response = requests.get(
        f"{BASE_URL}/articles/{article_id}/ask", 
        params={"q": question}
    )
    response.raise_for_status()
    return response.json()

# Example usage
results = search_articles("quantum physics")
print(f"Found {results['total']} results")

for article in results["results"]:
    print(f"Article: {article['title']}")
    print(f"Snippet: {article['snippet']}")
    print("---")

if results["results"]:
    article_id = results["results"][0]["id"]
    article = get_article(article_id)
    print(f"Full article: {article['title']}")
    
    answer = ask_question(article_id, "What are the key principles?")
    print(f"Q: {answer['question']}")
    print(f"A: {answer['answer']}")
```

## Example Usage: JavaScript Client

```javascript
const BASE_URL = 'http://localhost:8080';

async function searchArticles(query, isSemantic = false) {
  const endpoint = isSemantic ? '/semantic-search' : '/search';
  try {
    const response = await fetch(`${BASE_URL}${endpoint}?q=${encodeURIComponent(query)}&limit=5`);
    
    // Enhanced error handling based on status code
    if (!response.ok) {
      const errorData = await response.json().catch(() => null);
      
      if (response.status >= 400 && response.status < 500) {
        // Client errors (4xx)
        const message = errorData?.error?.message || 'Invalid request';
        const code = errorData?.error?.code || 'CLIENT_ERROR';
        throw new Error(`Client error (${response.status}): ${message} [${code}]`);
      } else if (response.status >= 500) {
        // Server errors (5xx)
        throw new Error(`Server error (${response.status}): The server is experiencing issues. Please try again later.`);
      } else {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
    }
    
    return await response.json();
  } catch (error) {
    if (error.name === 'AbortError') {
      throw new Error('Request timed out. Please check your connection and try again.');
    } else if (error.name === 'TypeError' && error.message.includes('Failed to fetch')) {
      throw new Error('Network error: Unable to connect to the server. Please check if the server is running.');
    }
    throw error; // Re-throw the enhanced error
  }
}

async function getArticle(articleId) {
  try {
    const response = await fetch(`${BASE_URL}/articles/${articleId}`);
    
    // Enhanced error handling based on status code
    if (!response.ok) {
      const errorData = await response.json().catch(() => null);
      
      if (response.status === 404) {
        throw new Error(`Article not found: The article with ID "${articleId}" does not exist.`);
      } else if (response.status >= 400 && response.status < 500) {
        // Client errors (4xx)
        const message = errorData?.error?.message || 'Invalid request';
        const code = errorData?.error?.code || 'CLIENT_ERROR';
        throw new Error(`Client error (${response.status}): ${message} [${code}]`);
      } else if (response.status >= 500) {
        // Server errors (5xx)
        throw new Error(`Server error (${response.status}): The server is experiencing issues. Please try again later.`);
      } else {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
    }
    
    return await response.json();
  } catch (error) {
    if (error.name === 'AbortError') {
      throw new Error('Request timed out. Please check your connection and try again.');
    } else if (error.name === 'TypeError' && error.message.includes('Failed to fetch')) {
      throw new Error('Network error: Unable to connect to the server. Please check if the server is running.');
    }
    throw error; // Re-throw the enhanced error
  }
}

async function askQuestion(articleId, question) {
  try {
    const response = await fetch(
      `${BASE_URL}/articles/${articleId}/ask?q=${encodeURIComponent(question)}`
    );
    
    // Enhanced error handling based on status code
    if (!response.ok) {
      const errorData = await response.json().catch(() => null);
      
      if (response.status === 404) {
        throw new Error(`Article not found: The article with ID "${articleId}" does not exist.`);
      } else if (response.status === 400) {
        throw new Error(`Invalid question: ${errorData?.error?.message || 'Please provide a valid question.'}`);
      } else if (response.status >= 400 && response.status < 500) {
        // Other client errors (4xx)
        const message = errorData?.error?.message || 'Invalid request';
        const code = errorData?.error?.code || 'CLIENT_ERROR';
        throw new Error(`Client error (${response.status}): ${message} [${code}]`);
      } else if (response.status >= 500) {
        // Server errors (5xx)
        throw new Error(`Server error (${response.status}): The server is experiencing issues. Please try again later.`);
      } else {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
    }
    
    return await response.json();
  } catch (error) {
    if (error.name === 'AbortError') {
      throw new Error('Request timed out. Please check your connection and try again.');
    } else if (error.name === 'TypeError' && error.message.includes('Failed to fetch')) {
      throw new Error('Network error: Unable to connect to the server. Please check if the server is running.');
    }
    throw error; // Re-throw the enhanced error
  }
}

// Helper function to display user-friendly error messages
function displayErrorMessage(error) {
  let message = error.message;
  
  // Log full error details to console for debugging
  console.error('API Error:', error);
  
  // Display user-friendly message to the user
  alert(`Error: ${message}`);
}

// Example usage with improved error handling
async function main() {
  try {
    const results = await searchArticles('quantum physics');
    console.log(`Found ${results.total} results`);
    
    results.results.forEach(article => {
      console.log(`Article: ${article.title}`);
      console.log(`Snippet: ${article.snippet}`);
      console.log('---');
    });
    
    if (results.results.length > 0) {
      const articleId = results.results[0].id;
      const article = await getArticle(articleId);
      console.log(`Full article: ${article.title}`);
      
      const answer = await askQuestion(articleId, 'What are the key principles?');
      console.log(`Q: ${answer.question}`);
      console.log(`A: ${answer.answer}`);
    }
  } catch (error) {
    displayErrorMessage(error);
  }
}

// Add request timeout capability
function fetchWithTimeout(url, options = {}, timeout = 10000) {
  return new Promise((resolve, reject) => {
    const controller = new AbortController();
    const { signal } = controller;
    
    const timeoutId = setTimeout(() => {
      controller.abort();
    }, timeout);
    
    fetch(url, { ...options, signal })
      .then(resolve)
      .catch(reject)
      .finally(() => clearTimeout(timeoutId));
  });
}

main();
```

## Future API Enhancements

The following enhancements are planned for future releases:

1. Authentication support
2. Export API for downloading articles in various formats (PDF, EPUB)
3. Search history and bookmarks
4. User settings and preferences
5. Advanced filtering options for search 