use reqwest::Client;
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn};

use crate::error_handling::{WikiError, WikiResult};

const DEFAULT_MODEL: &str = "llama2";
const DEFAULT_TEMPERATURE: f32 = 0.7;
const DEFAULT_MAX_TOKENS: usize = 1024;

#[derive(Debug, Serialize, Deserialize)]
struct GenerationRequest {
    model: String,
    prompt: String,
    stream: bool,
    max_tokens: Option<usize>,
    temperature: Option<f32>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GenerationResponse {
    model: String,
    response: String,
}

pub struct LlmService {
    client: Client,
    ollama_url: String,
    model: String,
}

impl LlmService {
    pub fn new(ollama_url: &str, model: Option<&str>) -> Self {
        Self {
            client: Client::new(),
            ollama_url: ollama_url.to_string(),
            model: model.unwrap_or(DEFAULT_MODEL).to_string(),
        }
    }

    pub async fn generate_text(&self, prompt: &str) -> WikiResult<String> {
        info!("Generating text with model: {}", self.model);
        debug!("Prompt: {}", prompt);

        let request = GenerationRequest {
            model: self.model.clone(),
            prompt: prompt.to_string(),
            stream: false,
            max_tokens: Some(1024),
            temperature: Some(0.7),
        };

        let response = self.client
            .post(format!("{}/api/generate", self.ollama_url))
            .json(&request)
            .send()
            .await
            .map_err(|e| WikiError::OperationFailed(format!("Failed to send request to LLM: {}", e)))?
            .json::<GenerationResponse>()
            .await
            .map_err(|e| WikiError::OperationFailed(format!("Failed to parse LLM response: {}", e)))?;

        debug!("Generated text: {}", response.response);
        Ok(response.response)
    }

    pub async fn summarize_article(&self, title: &str, content: &str) -> WikiResult<String> {
        let prompt = format!(
            "Please provide a concise summary of the following Wikipedia article:\n\nTitle: {}\n\n{}",
            title, content
        );
        self.generate_text(&prompt).await
    }

    pub async fn answer_question(&self, article_title: &str, article_content: &str, question: &str) -> WikiResult<String> {
        let prompt = format!(
            "Based on the following Wikipedia article, please answer the question.\n\nArticle Title: {}\n\nArticle Content: {}\n\nQuestion: {}\n\nAnswer:",
            article_title, article_content, question
        );
        self.generate_text(&prompt).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use mockito::{mock, server_url};

    #[tokio::test]
    async fn test_generate_text() -> WikiResult<()> {
        let mock_server = mock("POST", "/api/generate")
            .with_status(200)
            .with_header("content-type", "application/json")
            .with_body(r#"{"model":"llama2","response":"This is a test response."}"#)
            .create();

        let llm = LlmService::new(&server_url(), Some("llama2"));
        let response = llm.generate_text("Test prompt").await?;

        assert_eq!(response, "This is a test response.");
        mock_server.assert();

        Ok(())
    }
} 