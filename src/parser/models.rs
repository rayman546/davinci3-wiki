use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WikiArticle {
    pub title: String,
    pub content: String,
    pub categories: HashSet<String>,
    pub last_modified: DateTime<Utc>,
    pub size: usize,
    pub redirect_to: Option<String>,
    pub images: Vec<WikiImage>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WikiImage {
    pub filename: String,
    pub path: String,
    pub size: usize,
    pub mime_type: String,
    pub hash: String,
    pub caption: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WikiCategory {
    pub name: String,
    pub parent_categories: HashSet<String>,
    pub subcategories: HashSet<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WikiDumpMetadata {
    pub dump_date: DateTime<Utc>,
    pub version: String,
    pub lang: String,
    pub article_count: usize,
}

impl WikiArticle {
    pub fn new(title: String, content: String) -> Self {
        Self {
            title,
            content,
            categories: HashSet::new(),
            last_modified: Utc::now(),
            size: 0,
            redirect_to: None,
            images: Vec::new(),
        }
    }

    pub fn is_redirect(&self) -> bool {
        self.redirect_to.is_some()
    }

    pub fn add_category(&mut self, category: String) {
        self.categories.insert(category);
    }

    pub fn add_image(&mut self, image: WikiImage) {
        self.images.push(image);
    }

    pub fn update_size(&mut self) {
        self.size = self.content.len();
    }
}

impl WikiImage {
    pub fn new(filename: String, path: String, mime_type: String, hash: String) -> Self {
        Self {
            filename,
            path,
            size: 0,
            mime_type,
            hash,
            caption: None,
        }
    }

    pub fn with_caption(mut self, caption: String) -> Self {
        self.caption = Some(caption);
        self
    }

    pub fn with_size(mut self, size: usize) -> Self {
        self.size = size;
        self
    }
} 