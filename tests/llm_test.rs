use davinci3_wiki::{
    error_handling::WikiResult,
    llm::LLMClient,
};

#[tokio::test]
async fn test_llm_client_init() -> WikiResult<()> {
    // Initialize LLM client
    let llm_client = LLMClient::new("http://localhost:11434", "llama2")?;
    
    // Verify the client was initialized successfully
    assert_eq!(llm_client.model(), "llama2");
    assert_eq!(llm_client.endpoint(), "http://localhost:11434");
    
    Ok(())
}

#[tokio::test]
async fn test_llm_text_completion() -> WikiResult<()> {
    // Skip this test if Ollama is not available
    match tokio::process::Command::new("ollama")
        .arg("--version")
        .output()
        .await {
        Ok(_) => {}, // Ollama is installed, continue with the test
        Err(_) => {
            println!("Skipping test_llm_text_completion because Ollama is not installed");
            return Ok(());
        }
    }
    
    // Initialize LLM client
    let llm_client = LLMClient::new("http://localhost:11434", "llama2")?;
    
    // Test simple text completion
    let prompt = "What is the capital of France?";
    let completion = llm_client.complete_text(prompt, 50).await?;
    
    // Verify we got a non-empty response
    assert!(!completion.is_empty());
    
    // The answer should contain Paris
    assert!(completion.to_lowercase().contains("paris"));
    
    Ok(())
}

#[tokio::test]
async fn test_llm_summarization() -> WikiResult<()> {
    // Skip this test if Ollama is not available
    match tokio::process::Command::new("ollama")
        .arg("--version")
        .output()
        .await {
        Ok(_) => {}, // Ollama is installed, continue with the test
        Err(_) => {
            println!("Skipping test_llm_summarization because Ollama is not installed");
            return Ok(());
        }
    }
    
    // Initialize LLM client
    let llm_client = LLMClient::new("http://localhost:11434", "llama2")?;
    
    // Test summarization
    let text = "Rust is a multi-paradigm, general-purpose programming language. \
                Rust emphasizes performance, type safety, and concurrency. \
                Rust enforces memory safety—that is, that all references point \
                to valid memory—without requiring the use of a garbage collector \
                or reference counting present in other memory-safe languages. \
                To simultaneously enforce memory safety and prevent concurrent \
                data races, Rust's borrow checker tracks the object lifetime and \
                ownership of all references at compile time.";
                
    let summary = llm_client.summarize_text(text).await?;
    
    // Verify we got a non-empty summary
    assert!(!summary.is_empty());
    
    // Summary should be shorter than the original text
    assert!(summary.len() < text.len());
    
    // Summary should mention Rust
    assert!(summary.contains("Rust"));
    
    Ok(())
}

#[tokio::test]
async fn test_llm_question_answering() -> WikiResult<()> {
    // Skip this test if Ollama is not available
    match tokio::process::Command::new("ollama")
        .arg("--version")
        .output()
        .await {
        Ok(_) => {}, // Ollama is installed, continue with the test
        Err(_) => {
            println!("Skipping test_llm_question_answering because Ollama is not installed");
            return Ok(());
        }
    }
    
    // Initialize LLM client
    let llm_client = LLMClient::new("http://localhost:11434", "llama2")?;
    
    // Test context-aware question answering
    let context = "The Eiffel Tower is a wrought-iron lattice tower on the Champ de Mars in Paris, France. \
                   It is named after the engineer Gustave Eiffel, whose company designed and built the tower. \
                   Constructed from 1887 to 1889 as the entrance to the 1889 World's Fair, it was initially \
                   criticized by some of France's leading artists and intellectuals for its design, but it \
                   has become a global cultural icon of France and one of the most recognizable structures \
                   in the world. The Eiffel Tower is the most-visited paid monument in the world; \
                   6.91 million people ascended it in 2015.";
                   
    let question = "When was the Eiffel Tower built?";
    
    let answer = llm_client.answer_question(question, context).await?;
    
    // Verify we got a non-empty answer
    assert!(!answer.is_empty());
    
    // The answer should mention the years 1887-1889
    assert!(answer.contains("1887") && answer.contains("1889"));
    
    Ok(())
} 