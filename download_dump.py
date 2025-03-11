import requests
import os
import sys

print(f"Script location: {os.path.abspath(__file__)}")
print(f"Current working directory: {os.getcwd()}")
print(f"Python executable: {sys.executable}")

url = 'https://dumps.wikimedia.org/simplewiki/latest/simplewiki-latest-pages-articles1.xml.bz2'
print(f"Downloading {url}")

try:
    response = requests.get(url, stream=True)
    response.raise_for_status()
    print(f"Response status: {response.status_code}")
    print(f"Content length: {response.headers.get('content-length', 'unknown')}")
    
    with open('wiki-dump.xml.bz2', 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            if chunk:
                f.write(chunk)
                print(".", end="", flush=True)
    print("\nDownload complete")
except Exception as e:
    print(f"Error: {e}", file=sys.stderr) 