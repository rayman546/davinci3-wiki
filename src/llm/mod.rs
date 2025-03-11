use reqwest::Client;
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn};

use crate::error_handling::{WikiError, WikiResult};

const DEFAULT_MODEL: &str = "llama2";
const DEFAULT_TEMPERATURE: f32 = 0.7;
const DEFAULT_MAX_TOKENS: usize = 1024;

#[derive(Debug, Serialize)]
pub struct CompletionRequest {
    model: String,
    prompt: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    temperature: Option<f32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    max_tokens: Option<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    stop: Option<Vec<String>>,
}

#[derive(Debug, Deserialize)]
pub struct CompletionResponse {
    pub response: String,
}

pub struct LLMClient {
    client: Client,
    ollama_url: String,
    model: String,
    temperature: f32,
    max_tokens: usize,
}

impl LLMClient {
    pub fn new(ollama_url: &str) -> Self {
        Self {
            client: Client::new(),
            ollama_url: ollama_url.to_string(),
            model: DEFAULT_MODEL.to_string(),
            temperature: DEFAULT_TEMPERATURE,
            max_tokens: DEFAULT_MAX_TOKENS,
        }
    }

    pub fn with_model(mut self, model: &str) -> Self {
        self.model = model.to_string();
        self
    }

    pub fn with_temperature(mut self, temperature: f32) -> Self {
        self.temperature = temperature.clamp(0.0, 1.0);
        self
    }

    pub fn with_max_tokens(mut self, max_tokens: usize) -> Self {
        self.max_tokens = max_tokens;
        self
    }

    pub async fn complete(&self, prompt: &str) -> WikiResult<String> {
        let request = CompletionRequest {
            model: self.model.clone(),
            prompt: prompt.to_string(),
            temperature: Some(self.temperature),
            max_tokens: Some(self.max_tokens),
            stop: None,
        };

        let response = self.client
            .post(format!("{}/api/generate", self.ollama_url))
            .json(&request)
            .send()
            .await?
            .json::<CompletionResponse>()
            .await?;

        Ok(response.response)
    }

    pub async fn complete_with_context(&self, prompt: &str, context: &str) -> WikiResult<String> {
        let full_prompt = format!("Context:\n{}\n\nQuestion:\n{}", context, prompt);
        self.complete(&full_prompt).await
    }

    pub async fn summarize(&self, text: &str) -> WikiResult<String> {
        let prompt = format!(
            "Please provide a concise summary of the following text:\n\n{}\n\nSummary:",
            text
        );
        self.complete(&prompt).await
    }

    pub async fn answer_question(&self, question: &str, context: &str) -> WikiResult<String> {
        let prompt = format!(
            "Based on the following context, please answer the question. If the answer cannot be found in the context, say so.\n\nContext:\n{}\n\nQuestion:\n{}\n\nAnswer:",
            context,
            question
        );
        self.complete(&prompt).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_llm_client() -> WikiResult<()> {
        let client = LLMClient::new("http://localhost:11434")
            .with_model("llama2")
            .with_temperature(0.7)
            .with_max_tokens(100);

        // Test basic completion
        let response = client.complete("What is Rust?").await?;
        assert!(!response.is_empty());

        // Test completion with context
        let context = "Rust is a systems programming language focused on safety, concurrency, and performance.";
        let response = client
            .complete_with_context("What are the main features of Rust?", context)
            .await?;
        assert!(!response.is_empty());

        // Test summarization
        let text = "Rust is a systems programming language that runs blazingly fast, prevents segfaults, and guarantees thread safety. It accomplishes these goals by being memory-safe without using garbage collection.";
        let summary = client.summarize(text).await?;
        assert!(!summary.is_empty());

        Ok(())
    }
} 