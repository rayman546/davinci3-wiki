use std::path::{Path, PathBuf};
use heed::{Database, Env, EnvOpenOptions};
use ndarray::{Array1, ArrayView1};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn};
use rayon::prelude::*;

use crate::error_handling::{WikiError, WikiResult};

const VECTOR_SIZE: usize = 1536; // OpenAI embedding size
const MAX_BATCH_SIZE: usize = 32;

#[derive(Debug, Serialize, Deserialize)]
pub struct EmbeddingRequest {
    model: String,
    input: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct EmbeddingResponse {
    data: Vec<Embedding>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Embedding {
    embedding: Vec<f32>,
}

pub struct VectorStore {
    env: Env,
    db: Database<heed::types::Str, heed::types::SerdeBincode<Vec<f32>>>,
    client: Client,
    ollama_url: String,
}

impl VectorStore {
    pub fn new<P: AsRef<Path>>(path: P, ollama_url: &str) -> WikiResult<Self> {
        let path = path.as_ref().to_path_buf();
        std::fs::create_dir_all(&path)?;

        let env = EnvOpenOptions::new()
            .map_size(10 * 1024 * 1024 * 1024) // 10GB
            .max_dbs(1)
            .open(path)?;

        let mut wtxn = env.write_txn()?;
        let db = env.create_database(&mut wtxn, Some("vectors"))?;
        wtxn.commit()?;

        Ok(Self {
            env,
            db,
            client: Client::new(),
            ollama_url: ollama_url.to_string(),
        })
    }

    pub async fn generate_embedding(&self, text: &str) -> WikiResult<Vec<f32>> {
        let request = EmbeddingRequest {
            model: "llama2".to_string(),
            input: text.to_string(),
        };

        let response = self.client
            .post(format!("{}/api/embeddings", self.ollama_url))
            .json(&request)
            .send()
            .await?
            .json::<EmbeddingResponse>()
            .await?;

        Ok(response.data[0].embedding.clone())
    }

    pub async fn generate_embeddings_batch(&self, texts: &[String]) -> WikiResult<Vec<Vec<f32>>> {
        let mut results = Vec::with_capacity(texts.len());
        
        for chunk in texts.chunks(MAX_BATCH_SIZE) {
            let mut chunk_results = Vec::with_capacity(chunk.len());
            for text in chunk {
                let embedding = self.generate_embedding(text).await?;
                chunk_results.push(embedding);
            }
            results.extend(chunk_results);
        }
        
        Ok(results)
    }

    pub fn store_embedding(&self, key: &str, embedding: &[f32]) -> WikiResult<()> {
        let mut wtxn = self.env.write_txn()?;
        self.db.put(&mut wtxn, key, &embedding.to_vec())?;
        wtxn.commit()?;
        Ok(())
    }

    pub fn get_embedding(&self, key: &str) -> WikiResult<Option<Vec<f32>>> {
        let rtxn = self.env.read_txn()?;
        Ok(self.db.get(&rtxn, key)?)
    }

    pub fn find_similar(&self, query_embedding: &[f32], limit: usize) -> WikiResult<Vec<(String, f32)>> {
        let rtxn = self.env.read_txn()?;
        let query_array = ArrayView1::from(query_embedding);
        
        let mut results: Vec<_> = self.db
            .iter(&rtxn)?
            .filter_map(|item| item.ok())
            .map(|(key, embedding)| {
                let similarity = cosine_similarity(&query_array, &ArrayView1::from(&embedding));
                (key.to_string(), similarity)
            })
            .collect();
        
        results.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
        results.truncate(limit);
        
        Ok(results)
    }
}

fn cosine_similarity(a: &ArrayView1<f32>, b: &ArrayView1<f32>) -> f32 {
    let dot_product = a.dot(b);
    let norm_a = (a.dot(a)).sqrt();
    let norm_b = (b.dot(b)).sqrt();
    dot_product / (norm_a * norm_b)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[tokio::test]
    async fn test_vector_store() -> WikiResult<()> {
        let temp_dir = TempDir::new()?;
        let store = VectorStore::new(temp_dir.path(), "http://localhost:11434")?;

        // Test embedding generation
        let text = "This is a test sentence.";
        let embedding = store.generate_embedding(text).await?;
        assert_eq!(embedding.len(), VECTOR_SIZE);

        // Test storage and retrieval
        store.store_embedding("test_key", &embedding)?;
        let retrieved = store.get_embedding("test_key")?.unwrap();
        assert_eq!(embedding, retrieved);

        // Test similarity search
        let similar = store.find_similar(&embedding, 5)?;
        assert!(!similar.is_empty());
        assert!(similar[0].1 <= 1.0);
        assert!(similar[0].1 >= -1.0);

        Ok(())
    }
} 