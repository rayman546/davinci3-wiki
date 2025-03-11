use quick_xml::events::Event;
use quick_xml::reader::Reader;
use std::fs::File;
use std::io::BufReader;
use std::path::Path;
use tracing::{debug, info, warn};
use chrono::{DateTime, Utc};

use crate::error_handling::{WikiError, WikiResult};
use super::models::{WikiArticle, WikiDumpMetadata, WikiImage};
use super::text::clean_wiki_text;

pub struct WikiXmlParser {
    reader: Reader<BufReader<File>>,
    buf: Vec<u8>,
    metadata: Option<WikiDumpMetadata>,
}

impl WikiXmlParser {
    pub fn new() -> Self {
        Self {
            reader: Reader::from_reader(BufReader::new(File::open("/dev/null").unwrap_or_else(|_| {
                // Fallback for Windows
                File::open("NUL").unwrap_or_else(|_| {
                    panic!("Could not open null device")
                })
            }))),
            buf: Vec::new(),
            metadata: None,
        }
    }

    pub fn from_file<P: AsRef<Path>>(path: P) -> WikiResult<Self> {
        let file = File::open(path).map_err(WikiError::from)?;
        let reader = Reader::from_reader(BufReader::new(file));
        Ok(Self {
            reader,
            buf: Vec::new(),
            metadata: None,
        })
    }
    
    pub fn from_string(content: &str) -> Self {
        let reader = Reader::from_str(content);
        Self {
            reader: Reader::from_reader(BufReader::new(File::open("/dev/null").unwrap_or_else(|_| {
                // Fallback for Windows
                File::open("NUL").unwrap_or_else(|_| {
                    panic!("Could not open null device")
                })
            }))),
            buf: Vec::new(),
            metadata: None,
        }
    }

    pub fn parse_metadata(&mut self) -> WikiResult<WikiDumpMetadata> {
        if let Some(ref metadata) = self.metadata {
            return Ok(metadata.clone());
        }

        let mut in_siteinfo = false;
        let mut in_sitename = false;
        let mut in_generator = false;
        let mut in_lang = false;
        let mut generator = String::new();
        let mut lang = String::new();
        let mut dump_date = Utc::now();

        loop {
            self.buf.clear();
            match self.reader.read_event_into(&mut self.buf) {
                Ok(Event::Start(ref e)) => match e.name().as_ref() {
                    b"siteinfo" => in_siteinfo = true,
                    b"sitename" => in_sitename = true,
                    b"generator" => in_generator = true,
                    b"lang" => in_lang = true,
                    b"mediawiki" => {
                        // Try to get timestamp from mediawiki tag attributes
                        for attr in e.attributes().flatten() {
                            if attr.key.as_ref() == b"timestamp" {
                                if let Ok(ts) = String::from_utf8_lossy(&attr.value).parse::<DateTime<Utc>>() {
                                    dump_date = ts;
                                }
                            }
                        }
                    }
                    _ => (),
                },
                Ok(Event::End(ref e)) => match e.name().as_ref() {
                    b"siteinfo" => {
                        in_siteinfo = false;
                        break;
                    }
                    b"sitename" => in_sitename = false,
                    b"generator" => in_generator = false,
                    b"lang" => in_lang = false,
                    _ => (),
                },
                Ok(Event::Text(e)) => {
                    if in_siteinfo {
                        if in_generator {
                            generator = String::from_utf8_lossy(&e).into_owned();
                        } else if in_lang {
                            lang = String::from_utf8_lossy(&e).into_owned();
                        }
                    }
                }
                Ok(Event::Eof) => break,
                Err(e) => return Err(WikiError::Parse(e.to_string())),
                _ => (),
            }
        }

        let metadata = WikiDumpMetadata {
            dump_date,
            version: generator,
            lang,
            article_count: 0, // Will be updated during parsing
        };

        self.metadata = Some(metadata.clone());
        Ok(metadata)
    }

    pub fn parse_articles<F>(&mut self, mut callback: F) -> WikiResult<usize>
    where
        F: FnMut(WikiArticle) -> WikiResult<()>,
    {
        let mut count = 0;
        let mut current_article: Option<WikiArticle> = None;
        let mut in_page = false;
        let mut in_title = false;
        let mut in_text = false;
        let mut in_redirect = false;
        let mut current_text = String::new();

        // Ensure we have metadata
        if self.metadata.is_none() {
            self.parse_metadata()?;
        }

        loop {
            self.buf.clear();
            match self.reader.read_event_into(&mut self.buf) {
                Ok(Event::Start(ref e)) => match e.name().as_ref() {
                    b"page" => {
                        in_page = true;
                        current_article = None;
                    }
                    b"title" => in_title = true,
                    b"text" => in_text = true,
                    b"redirect" => {
                        in_redirect = true;
                        if let Some(ref mut article) = current_article {
                            // Get redirect target from attributes
                            for attr in e.attributes().flatten() {
                                if attr.key.as_ref() == b"title" {
                                    article.redirect_to = Some(String::from_utf8_lossy(&attr.value).into_owned());
                                }
                            }
                        }
                    }
                    _ => (),
                },
                Ok(Event::End(ref e)) => match e.name().as_ref() {
                    b"page" => {
                        if let Some(mut article) = current_article.take() {
                            article.content = clean_wiki_text(&current_text);
                            article.update_size();
                            
                            // Extract categories from content
                            let content = article.content.clone();
                            for line in content.lines() {
                                if line.starts_with("[[Category:") {
                                    let cat = line.trim_start_matches("[[Category:")
                                        .trim_end_matches("]]")
                                        .trim()
                                        .to_string();
                                    article.add_category(cat);
                                }
                            }

                            // Extract images from content
                            let content = article.content.clone();
                            for line in content.lines() {
                                if line.starts_with("[[File:") || line.starts_with("[[Image:") {
                                    let img = line.trim_start_matches("[[File:")
                                        .trim_start_matches("[[Image:")
                                        .trim_end_matches("]]")
                                        .trim();
                                    let parts: Vec<&str> = img.split('|').collect();
                                    if !parts.is_empty() {
                                        let filename = parts[0].to_string();
                                        let caption = parts.get(1).map(|s| s.to_string());
                                        let image = WikiImage::new(
                                            filename.clone(),
                                            format!("/images/{}", filename),
                                            "image/unknown".to_string(),
                                            "".to_string(),
                                        ).with_caption(caption.unwrap_or_default());
                                        article.add_image(image);
                                    }
                                }
                            }

                            callback(article)?;
                            count += 1;
                            if count % 1000 == 0 {
                                info!("Processed {} articles", count);
                            }
                        }
                        in_page = false;
                        current_text.clear();
                    }
                    b"title" => in_title = false,
                    b"text" => in_text = false,
                    b"redirect" => in_redirect = false,
                    _ => (),
                },
                Ok(Event::Text(e)) => {
                    if in_page {
                        if in_title {
                            let title = String::from_utf8_lossy(&e).into_owned();
                            current_article = Some(WikiArticle::new(title, String::new()));
                        } else if in_text {
                            current_text.push_str(&String::from_utf8_lossy(&e).into_owned());
                        }
                    }
                }
                Ok(Event::Eof) => break,
                Err(e) => {
                    warn!("Error parsing XML: {}", e);
                    return Err(WikiError::Parse(e.to_string()));
                }
                _ => (),
            }
        }

        // Update metadata with final article count
        if let Some(ref mut metadata) = self.metadata {
            metadata.article_count = count;
        }

        info!("Finished processing {} articles", count);
        Ok(count)
    }

    pub fn parse(&mut self, content: &str) -> WikiResult<Vec<WikiArticle>> {
        let mut articles = Vec::new();
        let mut parser = WikiXmlParser::from_string(content);
        
        parser.parse_articles(|article| {
            articles.push(article);
            Ok(())
        })?;
        
        Ok(articles)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::NamedTempFile;

    #[test]
    fn test_parse_simple_article() -> WikiResult<()> {
        let xml_content = r#"
        <mediawiki timestamp="2024-03-11T00:00:00Z">
            <siteinfo>
                <sitename>Wikipedia</sitename>
                <generator>MediaWiki 1.41.0</generator>
                <lang>en</lang>
            </siteinfo>
            <page>
                <title>Test Article</title>
                <text>This is a test article content.
                [[Category:Test Category]]
                [[File:Test.jpg|thumb|Test image]]</text>
            </page>
        </mediawiki>"#;

        let mut parser = WikiXmlParser::from_string(xml_content);
        let metadata = parser.parse_metadata()?;
        
        assert_eq!(metadata.lang, "en");
        assert!(metadata.version.contains("MediaWiki"));

        let mut articles = Vec::new();
        parser.parse_articles(|article| {
            articles.push(article);
            Ok(())
        })?;

        assert_eq!(articles.len(), 1);
        assert_eq!(articles[0].title, "Test Article");
        assert!(!articles[0].categories.is_empty());
        assert!(!articles[0].images.is_empty());
        Ok(())
    }

    #[test]
    fn test_parse_redirect() -> WikiResult<()> {
        let xml_content = r#"
        <mediawiki>
            <page>
                <title>Redirect Test</title>
                <redirect title="Target Article"/>
                <text>#REDIRECT [[Target Article]]</text>
            </page>
        </mediawiki>"#;

        let mut temp_file = NamedTempFile::new().unwrap();
        write!(temp_file, "{}", xml_content).unwrap();

        let mut parser = WikiXmlParser::new(temp_file.path())?;
        let mut articles = Vec::new();

        parser.parse_articles(|article| {
            articles.push(article);
            Ok(())
        })?;

        assert_eq!(articles.len(), 1);
        assert!(articles[0].is_redirect());
        assert_eq!(articles[0].redirect_to.as_deref(), Some("Target Article"));
        Ok(())
    }
} 