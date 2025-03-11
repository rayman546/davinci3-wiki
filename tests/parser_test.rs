use davinci3_wiki::{
    error_handling::WikiResult,
    parser::{WikiDumpParser, models::WikiArticle},
};
use std::fs::File;
use std::io::Write;
use tempfile::TempDir;

#[test]
fn test_parser_simple_xml() -> WikiResult<()> {
    // Create a temporary directory for test files
    let temp_dir = TempDir::new()?;
    let xml_path = temp_dir.path().join("test.xml");
    
    // Create a simple XML file with a few articles
    let test_xml = r#"<mediawiki>
  <page>
    <title>Test Article 1</title>
    <ns>0</ns>
    <id>1</id>
    <revision>
      <text>This is the content of test article 1.</text>
    </revision>
  </page>
  <page>
    <title>Test Article 2</title>
    <ns>0</ns>
    <id>2</id>
    <revision>
      <text>This is the content of test article 2.</text>
    </revision>
  </page>
</mediawiki>"#;
    
    // Write the XML to a file
    let mut file = File::create(&xml_path)?;
    file.write_all(test_xml.as_bytes())?;
    
    // Parse the XML
    let parser = WikiDumpParser::new();
    let xml_content = std::fs::read_to_string(&xml_path)?;
    let articles = parser.parse(&xml_content)?;
    
    // Verify the parsing results
    assert_eq!(articles.len(), 2);
    
    // Check the first article
    assert_eq!(articles[0].id, "1");
    assert_eq!(articles[0].title, "Test Article 1");
    assert_eq!(articles[0].text, "This is the content of test article 1.");
    
    // Check the second article
    assert_eq!(articles[1].id, "2");
    assert_eq!(articles[1].title, "Test Article 2");
    assert_eq!(articles[1].text, "This is the content of test article 2.");
    
    Ok(())
}

#[test]
fn test_parser_handles_special_characters() -> WikiResult<()> {
    // Create a temporary directory for test files
    let temp_dir = TempDir::new()?;
    let xml_path = temp_dir.path().join("special_chars.xml");
    
    // Create XML with special characters
    let test_xml = r#"<mediawiki>
  <page>
    <title>Special &amp; Characters</title>
    <ns>0</ns>
    <id>1</id>
    <revision>
      <text>This article contains &lt;special&gt; characters &amp; symbols.</text>
    </revision>
  </page>
</mediawiki>"#;
    
    // Write the XML to a file
    let mut file = File::create(&xml_path)?;
    file.write_all(test_xml.as_bytes())?;
    
    // Parse the XML
    let parser = WikiDumpParser::new();
    let xml_content = std::fs::read_to_string(&xml_path)?;
    let articles = parser.parse(&xml_content)?;
    
    // Verify the parsing results
    assert_eq!(articles.len(), 1);
    
    // Check that special characters are handled correctly
    assert_eq!(articles[0].title, "Special & Characters");
    assert_eq!(articles[0].text, "This article contains <special> characters & symbols.");
    
    Ok(())
}

#[test]
fn test_parser_skips_non_article_namespaces() -> WikiResult<()> {
    // Create a temporary directory for test files
    let temp_dir = TempDir::new()?;
    let xml_path = temp_dir.path().join("namespaces.xml");
    
    // Create XML with different namespaces
    let test_xml = r#"<mediawiki>
  <page>
    <title>Regular Article</title>
    <ns>0</ns>
    <id>1</id>
    <revision>
      <text>This is a regular article.</text>
    </revision>
  </page>
  <page>
    <title>Talk:Some Topic</title>
    <ns>1</ns>
    <id>2</id>
    <revision>
      <text>This is a talk page that should be skipped.</text>
    </revision>
  </page>
  <page>
    <title>User:Example</title>
    <ns>2</ns>
    <id>3</id>
    <revision>
      <text>This is a user page that should be skipped.</text>
    </revision>
  </page>
</mediawiki>"#;
    
    // Write the XML to a file
    let mut file = File::create(&xml_path)?;
    file.write_all(test_xml.as_bytes())?;
    
    // Parse the XML
    let parser = WikiDumpParser::new();
    let xml_content = std::fs::read_to_string(&xml_path)?;
    let articles = parser.parse(&xml_content)?;
    
    // Verify only the article namespace (0) was parsed
    assert_eq!(articles.len(), 1);
    assert_eq!(articles[0].title, "Regular Article");
    
    Ok(())
} 