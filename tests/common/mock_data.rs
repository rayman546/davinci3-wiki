use davinci3_wiki::parser::models::WikiArticle;

/// Get a single test article
pub fn get_test_article() -> WikiArticle {
    WikiArticle {
        id: Some(1),
        title: "Test Article".to_string(),
        content: "This is a test article with some content for testing purposes.".to_string(),
        categories: vec!["Test".to_string(), "Example".to_string()],
        is_redirect: false,
        redirect_to: None,
        images: Vec::new(),
    }
}

/// Get a list of test articles
pub fn get_test_articles() -> Vec<WikiArticle> {
    vec![
        WikiArticle {
            id: None,
            title: "Test Article 1".to_string(),
            content: "This is the first test article content.".to_string(),
            categories: vec!["Test".to_string(), "First".to_string()],
            is_redirect: false,
            redirect_to: None,
            images: Vec::new(),
        },
        WikiArticle {
            id: None,
            title: "Test Article 2".to_string(),
            content: "This is the second test article content.".to_string(),
            categories: vec!["Test".to_string(), "Second".to_string()],
            is_redirect: false,
            redirect_to: None,
            images: Vec::new(),
        },
        WikiArticle {
            id: None,
            title: "Test Article 3".to_string(),
            content: "This is the third test article with special content about science.".to_string(),
            categories: vec!["Test".to_string(), "Science".to_string()],
            is_redirect: false,
            redirect_to: None,
            images: Vec::new(),
        },
        WikiArticle {
            id: None,
            title: "Test Article 4".to_string(),
            content: "This is the fourth test article with special content about technology.".to_string(),
            categories: vec!["Test".to_string(), "Technology".to_string()],
            is_redirect: false,
            redirect_to: None,
            images: Vec::new(),
        },
        WikiArticle {
            id: None,
            title: "Science Example".to_string(),
            content: "Scientific article about physics, chemistry, and biology.".to_string(),
            categories: vec!["Science".to_string()],
            is_redirect: false,
            redirect_to: None,
            images: Vec::new(),
        },
    ]
}

/// Get a small test XML dump
pub fn get_test_xml_dump() -> &'static str {
    r#"<mediawiki>
      <page>
        <title>Test Article 1</title>
        <ns>0</ns>
        <revision>
          <text>This is the first test article content.</text>
        </revision>
      </page>
      <page>
        <title>Test Article 2</title>
        <ns>0</ns>
        <revision>
          <text>This is the second test article content.</text>
        </revision>
      </page>
      <page>
        <title>Test Article 3</title>
        <ns>0</ns>
        <revision>
          <text>This is the third test article with special content about science.</text>
        </revision>
      </page>
      <page>
        <title>Talk:Something</title>
        <ns>1</ns>
        <revision>
          <text>This should be skipped</text>
        </revision>
      </page>
    </mediawiki>"#
}

/// Get an updated test XML dump for incremental update testing
pub fn get_updated_test_xml_dump() -> &'static str {
    r#"<mediawiki>
      <page>
        <title>Test Article 1</title>
        <ns>0</ns>
        <revision>
          <text>This is the first test article content.</text>
        </revision>
      </page>
      <page>
        <title>Test Article 2</title>
        <ns>0</ns>
        <revision>
          <text>This is the second test article content that has been modified.</text>
        </revision>
      </page>
      <page>
        <title>New Article 1</title>
        <ns>0</ns>
        <revision>
          <text>This is a completely new article with new content.</text>
        </revision>
      </page>
      <page>
        <title>New Article 2</title>
        <ns>0</ns>
        <revision>
          <text>This is another new article with different content.</text>
        </revision>
      </page>
      <page>
        <title>Talk:Something</title>
        <ns>1</ns>
        <revision>
          <text>This should be skipped</text>
        </revision>
      </page>
    </mediawiki>"#
}

/// Get a large test XML dump for performance testing
pub fn get_large_test_xml_dump() -> String {
    let mut result = String::from("<mediawiki>\n");
    
    for i in 1..1001 {
        result.push_str(&format!(
            r#"  <page>
    <title>Performance Test Page {}</title>
    <ns>0</ns>
    <revision>
      <text>This is test content for performance testing article number {}. It contains various words like science, technology, history, and culture to ensure we have searchable content.</text>
    </revision>
  </page>
"#,
            i, i
        ));
    }
    
    result.push_str("</mediawiki>");
    result
}

/// Get test vector data (article ID to vector mapping)
pub fn get_test_vectors() -> Vec<(u64, Vec<f32>)> {
    vec![
        (1, vec![0.1, 0.2, 0.3, 0.4, 0.5]),
        (2, vec![0.2, 0.3, 0.4, 0.5, 0.6]),
        (3, vec![0.3, 0.4, 0.5, 0.6, 0.7]),
        (4, vec![0.4, 0.5, 0.6, 0.7, 0.8]),
        (5, vec![0.5, 0.6, 0.7, 0.8, 0.9]),
    ]
}

/// Get a test query vector for semantic search
pub fn get_test_query_vector() -> Vec<f32> {
    vec![0.3, 0.4, 0.5, 0.6, 0.7]
}

/// Get a test prompt for LLM
pub fn get_test_summary_prompt(article_content: &str) -> String {
    format!(
        "Please provide a brief summary of the following article:\n\n{}\n\nSummary:",
        article_content
    )
}

/// Get a test question prompt for LLM
pub fn get_test_question_prompt(article_content: &str, question: &str) -> String {
    format!(
        "Article: {}\n\nQuestion: {}\n\nAnswer:",
        article_content, question
    )
}

/// Get a test installer configuration
pub fn get_test_installer_config(temp_dir: &std::path::Path) -> davinci3_wiki::installer::InstallerConfig {
    davinci3_wiki::installer::InstallerConfig {
        data_dir: temp_dir.join("data"),
        cache_dir: temp_dir.join("cache"),
        vector_dir: temp_dir.join("vectors"),
        ollama_url: "http://localhost:11434".to_string(),
        skip_download: true,
        skip_embeddings: false,
        min_article_length: 50,
    }
}

/// Get a partial invalid XML dump with some valid and some invalid articles
pub fn get_partial_invalid_xml_dump() -> &'static str {
    r#"<mediawiki>
      <page>
        <title>Valid Article 1</title>
        <ns>0</ns>
        <revision>
          <text>This is a valid article that should be imported successfully.</text>
        </revision>
      </page>
      <page>
        <title>Valid Article 2</title>
        <ns>0</ns>
        <revision>
          <text>This is another valid article that should be imported successfully.</text>
        </revision>
      </page>
      <page>
        <!-- Missing title element, should cause an error or be skipped -->
        <ns>0</ns>
        <revision>
          <text>Article with missing title</text>
        </revision>
      </page>
      <page>
        <title>Invalid Article</title>
        <ns>0</ns>
        <!-- Missing revision element, should cause an error or be skipped -->
      </page>
      <page>
        <title>Valid Article 3</title>
        <ns>0</ns>
        <revision>
          <text>This is another valid article after some invalid ones.</text>
        </revision>
      </page>
      <corrupted_element>
        This is completely invalid and might break the parser
      </corrupted_element>
    </mediawiki>"#
} 