pub mod models;
mod text;
mod xml;

use std::fs::File;
use std::io::{self, BufReader, BufWriter};
use std::path::Path;
use flate2::read::GzDecoder;
use crate::error_handling::{WikiError, WikiResult};
use tracing::{info, debug, error};

pub use models::{WikiArticle, WikiCategory, WikiDumpMetadata, WikiImage};
pub use xml::WikiXmlParser;

/// Extract a gzipped file to a destination path
pub fn extract_gzip<P: AsRef<Path>>(source: P, dest: P) -> WikiResult<()> {
    info!("Extracting {} to {}", source.as_ref().display(), dest.as_ref().display());
    
    let input = File::open(&source)
        .map_err(|e| {
            error!("Failed to open source file: {}", e);
            WikiError::Io(e)
        })?;

    let output = File::create(&dest)
        .map_err(|e| {
            error!("Failed to create destination file: {}", e);
            WikiError::Io(e)
        })?;

    let mut decoder = GzDecoder::new(BufReader::new(input));
    let mut writer = BufWriter::new(output);

    debug!("Starting decompression");
    io::copy(&mut decoder, &mut writer)
        .map_err(|e| {
            error!("Failed to decompress file: {}", e);
            WikiError::Io(e)
        })?;
    debug!("Decompression completed");

    info!("Successfully extracted file");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn test_extract_gzip() {
        let dir = tempdir().unwrap();
        let source = dir.path().join("test.gz");
        let dest = dir.path().join("test.xml");

        // Create a test gzipped file
        let mut encoder = flate2::write::GzEncoder::new(
            File::create(&source).unwrap(),
            flate2::Compression::default(),
        );
        encoder.write_all(b"<test>content</test>").unwrap();
        encoder.finish().unwrap();

        // Test extraction
        assert!(extract_gzip(&source, &dest).is_ok());
        assert!(dest.exists());
        
        let content = fs::read_to_string(&dest).unwrap();
        assert_eq!(content, "<test>content</test>");
    }
} 