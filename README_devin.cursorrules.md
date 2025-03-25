# davinci3


A Cursor-powered AI development environment with advanced agentic capabilities.


## Quick Start

1. Set up the virtual environment:
   ```bash
   # Create virtual environment
   python3 -m venv venv
   
   # On Windows
   venv\Scripts\activate
   
   # On macOS/Linux
   source venv/bin/activate
   
   # Install dependencies
   pip install -r requirements.txt
   ```

2. Configure your environment:
   - Copy `.env.example` to `.env` if you haven't already
   - Add your API keys in `.env` (optional)

## Dependency Management

This project uses `pip-tools` to manage dependencies:

```bash
# Install pip-tools
pip install pip-tools

# Update requirements.txt from requirements.in
pip-compile requirements.in --output-file requirements.txt

# Install all dependencies
pip install -r requirements.txt
```

To add a new dependency:
1. Add it to `requirements.in`
2. Run `pip-compile requirements.in --output-file requirements.txt`
3. Install with `pip install -r requirements.txt`

## Available Tools

Your project includes several powerful tools in the `tools/` directory:

### LLM Integration
```python
from tools.llm_api import query_llm

# Use LLM for assistance
response = query_llm(
    "Your question here",
    provider="anthropic"  # Options: openai, anthropic, azure_openai, deepseek, gemini
)
print(response)
```

### Web Scraping
```python
from tools.web_scraper import scrape_urls

# Scrape web content
results = scrape_urls(["https://example.com"], max_concurrent=3)
```

### Search Engine
```python
from tools.search_engine import search

# Search the web
results = search("your search keywords")
```


### Screenshot Verification
```python
from tools.screenshot_utils import take_screenshot_sync
from tools.llm_api import query_llm

# Take and analyze screenshots
screenshot_path = take_screenshot_sync('https://example.com', 'screenshot.png')
analysis = query_llm(
    "Describe this webpage",
    provider="openai",
    image_path=screenshot_path
)
```

Note: When you first use the screenshot verification feature, Playwright browsers will be installed automatically.


## AI Assistant Configuration


This project uses `.cursorrules` to configure the AI assistant. The assistant can:
- Help with coding tasks
- Verify screenshots
- Perform web searches
- Analyze images and code


## Environment Variables

Configure these in your `.env` file:

- `LLM_API_KEY`: Your LLM API key (optional)
- `AZURE_OPENAI_API_KEY`: Azure OpenAI API key (optional)
- `AZURE_OPENAI_ENDPOINT`: Azure OpenAI endpoint (optional)
- `AZURE_OPENAI_MODEL_DEPLOYMENT`: Azure OpenAI model deployment name (optional)
- `SILICONFLOW_API_KEY`: Siliconflow API key (optional)
Note: Basic functionality works without API keys. Advanced features (like multimodal analysis) require appropriate API keys.

## Development Tools

- `.devcontainer/`: VS Code development container configuration
- `.vscode.example/`: Recommended VS Code settings
- `.github/`: CI/CD workflows

## License

MIT License