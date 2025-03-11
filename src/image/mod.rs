use std::path::{Path, PathBuf};
use std::io;
use tokio::fs;
use reqwest::Client;
use image::{DynamicImage, ImageFormat};
use sha2::{Sha256, Digest};
use tracing::{debug, info, warn};

use crate::error_handling::{WikiError, WikiResult};

#[derive(Debug, Clone)]
pub struct ImageMetadata {
    pub filename: String,
    pub hash: String,
    pub content_type: String,
    pub size: usize,
    pub width: u32,
    pub height: u32,
}

pub struct ImageProcessor {
    cache_dir: PathBuf,
    max_size: usize,
    client: Client,
}

impl ImageProcessor {
    pub async fn new<P: AsRef<Path>>(cache_dir: P, max_size: usize) -> WikiResult<Self> {
        let cache_dir = cache_dir.as_ref().to_path_buf();
        fs::create_dir_all(&cache_dir).await?;

        Ok(Self {
            cache_dir,
            max_size,
            client: Client::new(),
        })
    }

    pub async fn download_image(&self, url: &str) -> WikiResult<ImageMetadata> {
        let response = self.client.get(url).send().await?;
        let content_type = response
            .headers()
            .get("content-type")
            .and_then(|ct| ct.to_str().ok())
            .unwrap_or("application/octet-stream")
            .to_string();

        let bytes = response.bytes().await?;
        let size = bytes.len();

        if size > self.max_size {
            return Err(WikiError::ImageTooLarge(size, self.max_size));
        }

        let mut hasher = Sha256::new();
        hasher.update(&bytes);
        let hash = format!("{:x}", hasher.finalize());

        let img = image::load_from_memory(&bytes)
            .map_err(|e| WikiError::ImageProcessingFailed(e.to_string()))?;

        let filename = format!("{}.{}", hash, self.get_extension(&content_type));
        let path = self.cache_dir.join(&filename);

        fs::write(&path, &bytes).await?;

        Ok(ImageMetadata {
            filename,
            hash,
            content_type,
            size,
            width: img.width(),
            height: img.height(),
        })
    }

    fn get_extension(&self, content_type: &str) -> &str {
        match content_type {
            "image/jpeg" | "image/jpg" => "jpg",
            "image/png" => "png",
            "image/gif" => "gif",
            "image/webp" => "webp",
            _ => "bin",
        }
    }

    pub async fn get_cached_image(&self, hash: &str) -> WikiResult<Option<Vec<u8>>> {
        let pattern = format!("{}.*", hash);
        let mut entries = fs::read_dir(&self.cache_dir).await?;

        while let Some(entry) = entries.next_entry().await? {
            let filename = entry.file_name();
            let filename_str = filename.to_string_lossy();
            if filename_str.starts_with(hash) {
                return Ok(Some(fs::read(entry.path()).await?));
            }
        }

        Ok(None)
    }

    pub async fn resize_image(&self, data: &[u8], max_width: u32, max_height: u32) -> WikiResult<Vec<u8>> {
        let img = image::load_from_memory(data)
            .map_err(|e| WikiError::ImageProcessingFailed(e.to_string()))?;

        let (width, height) = img.dimensions();
        if width <= max_width && height <= max_height {
            return Ok(data.to_vec());
        }

        let ratio = f64::min(
            max_width as f64 / width as f64,
            max_height as f64 / height as f64,
        );

        let new_width = (width as f64 * ratio) as u32;
        let new_height = (height as f64 * ratio) as u32;

        let resized = img.resize(new_width, new_height, image::imageops::FilterType::Lanczos3);
        let mut buffer = Vec::new();
        resized
            .write_to(&mut buffer, ImageFormat::Png)
            .map_err(|e| WikiError::ImageProcessingFailed(e.to_string()))?;

        Ok(buffer)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[tokio::test]
    async fn test_image_processor() -> WikiResult<()> {
        let temp_dir = TempDir::new()?;
        let processor = ImageProcessor::new(temp_dir.path(), 10 * 1024 * 1024).await?;

        let test_url = "https://raw.githubusercontent.com/rust-lang/rust-artwork/master/logo/rust-logo-128x128.png";
        let metadata = processor.download_image(test_url).await?;

        assert_eq!(metadata.content_type, "image/png");
        assert!(metadata.size > 0);
        assert!(metadata.width > 0);
        assert!(metadata.height > 0);

        let cached = processor.get_cached_image(&metadata.hash).await?.unwrap();
        assert!(!cached.is_empty());

        let resized = processor.resize_image(&cached, 64, 64).await?;
        assert!(!resized.is_empty());
        assert!(resized.len() < cached.len());

        Ok(())
    }
} 