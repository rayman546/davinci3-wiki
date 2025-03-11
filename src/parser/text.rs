use lazy_static::lazy_static;
use regex::Regex;
use std::collections::HashSet;
use url::Url;

lazy_static! {
    static ref REDIRECT_RE: Regex = Regex::new(r"#REDIRECT\s*\[\[([^\]]+)\]\]").unwrap();
    static ref CATEGORY_RE: Regex = Regex::new(r"\[\[Category:([^\]]+)\]\]").unwrap();
    static ref IMAGE_RE: Regex = Regex::new(r"\[\[File:([^\]|]+)(?:\|([^\]]+))?\]\]").unwrap();
    static ref INTERNAL_LINK_RE: Regex = Regex::new(r"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]").unwrap();
    static ref EXTERNAL_LINK_RE: Regex = Regex::new(r"\[([^\s\]]+)(?:\s+([^\]]+))?\]").unwrap();
    static ref HTML_TAG_RE: Regex = Regex::new(r"<[^>]+>").unwrap();
    static ref TEMPLATE_RE: Regex = Regex::new(r"\{\{[^\}]+\}\}").unwrap();
}

pub fn clean_wiki_text(text: &str) -> String {
    let mut cleaned = text.to_string();

    // Remove templates
    cleaned = TEMPLATE_RE.replace_all(&cleaned, "").to_string();

    // Convert internal links to text
    cleaned = INTERNAL_LINK_RE
        .replace_all(&cleaned, |caps: &regex::Captures| {
            caps.get(2).map_or_else(
                || caps[1].to_string(),
                |m| m.as_str().to_string(),
            )
        })
        .to_string();

    // Convert external links to text
    cleaned = EXTERNAL_LINK_RE
        .replace_all(&cleaned, |caps: &regex::Captures| {
            caps.get(2).map_or_else(
                || caps[1].to_string(),
                |m| m.as_str().to_string(),
            )
        })
        .to_string();

    // Remove HTML tags
    cleaned = HTML_TAG_RE.replace_all(&cleaned, "").to_string();

    // Remove multiple newlines
    cleaned = cleaned.replace("\n\n\n+", "\n\n");

    cleaned.trim().to_string()
}

pub fn extract_redirect(text: &str) -> Option<String> {
    REDIRECT_RE.captures(text).map(|caps| caps[1].to_string())
}

pub fn extract_categories(text: &str) -> HashSet<String> {
    CATEGORY_RE
        .captures_iter(text)
        .map(|caps| caps[1].trim().to_string())
        .collect()
}

pub fn extract_images(text: &str) -> Vec<(String, Option<String>)> {
    IMAGE_RE
        .captures_iter(text)
        .map(|caps| {
            (
                caps[1].trim().to_string(),
                caps.get(2).map(|m| m.as_str().trim().to_string()),
            )
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_clean_wiki_text() {
        let wiki_text = r#"
{{Template|param}}
[[Internal Link|Display Text]]
[http://example.com External Link]
<ref>Reference</ref>
[[Category:Test]]
[[File:image.jpg|thumb|Caption]]
"#;
        let cleaned = clean_wiki_text(wiki_text);
        assert!(!cleaned.contains("{{"));
        assert!(!cleaned.contains("[["));
        assert!(!cleaned.contains("<ref>"));
        assert!(cleaned.contains("Display Text"));
        assert!(cleaned.contains("External Link"));
    }

    #[test]
    fn test_extract_redirect() {
        let text = "#REDIRECT [[Target Page]]";
        assert_eq!(
            extract_redirect(text),
            Some("Target Page".to_string())
        );
    }

    #[test]
    fn test_extract_categories() {
        let text = "[[Category:Test1]]\n[[Category:Test2]]";
        let categories = extract_categories(text);
        assert!(categories.contains("Test1"));
        assert!(categories.contains("Test2"));
    }

    #[test]
    fn test_extract_images() {
        let text = "[[File:image1.jpg|thumb|Caption1]]\n[[File:image2.jpg]]";
        let images = extract_images(text);
        assert_eq!(images.len(), 2);
        assert_eq!(images[0].0, "image1.jpg");
        assert_eq!(images[0].1, Some("thumb|Caption1".to_string()));
        assert_eq!(images[1].0, "image2.jpg");
        assert_eq!(images[1].1, None);
    }
} 