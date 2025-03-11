use davinci3_wiki::{
    error_handling::WikiResult,
    installer::{InstallConfig, InstallManager},
};
use std::path::PathBuf;
use tempfile::TempDir;

#[tokio::test]
async fn test_installer_basic_functionality() -> WikiResult<()> {
    // Create temporary directories for test
    let temp_dir = TempDir::new()?;
    let base_path = temp_dir.path();
    
    // Create config with temporary directories
    let config = InstallConfig {
        data_dir: base_path.join("data"),
        cache_dir: base_path.join("cache"),
        vector_store_dir: base_path.join("vectors"),
        ollama_url: "http://localhost:11434".to_string(),
        max_image_size: 1024 * 1024, // 1MB
        max_batch_size: 10,
    };
    
    // Create installer
    let installer = InstallManager::new(config);
    
    // Test directory creation
    assert!(installer.create_directories().await.is_ok());
    
    // Verify directories were created
    assert!(base_path.join("data").exists());
    assert!(base_path.join("cache").exists());
    assert!(base_path.join("vectors").exists());
    
    // Test uninstallation
    assert!(installer.uninstall().await.is_ok());
    
    // Verify directories were removed
    assert!(!base_path.join("data").exists());
    assert!(!base_path.join("cache").exists());
    assert!(!base_path.join("vectors").exists());
    
    Ok(())
}

#[tokio::test]
async fn test_installer_config_customization() -> WikiResult<()> {
    // Test different configurations
    let temp_dir = TempDir::new()?;
    let base_path = temp_dir.path();
    
    // Test default config
    let default_config = InstallConfig::default();
    assert_eq!(default_config.ollama_url, "http://localhost:11434");
    
    // Test custom config
    let custom_config = InstallConfig {
        data_dir: base_path.join("custom_data"),
        cache_dir: base_path.join("custom_cache"),
        vector_store_dir: base_path.join("custom_vectors"),
        ollama_url: "http://custom:8080".to_string(),
        max_image_size: 5 * 1024 * 1024, // 5MB
        max_batch_size: 20,
    };
    
    let installer = InstallManager::new(custom_config);
    
    // Test directory creation
    assert!(installer.create_directories().await.is_ok());
    
    // Verify custom directories were created
    assert!(base_path.join("custom_data").exists());
    assert!(base_path.join("custom_cache").exists());
    assert!(base_path.join("custom_vectors").exists());
    
    // Cleanup
    installer.uninstall().await?;
    
    Ok(())
}

// Skip this test in normal runs as it takes a long time
#[tokio::test]
#[ignore]
async fn test_download_wikidump() -> WikiResult<()> {
    let temp_dir = TempDir::new()?;
    let base_path = temp_dir.path();
    
    let config = InstallConfig {
        data_dir: base_path.join("data"),
        cache_dir: base_path.join("cache"),
        vector_store_dir: base_path.join("vectors"),
        ollama_url: "http://localhost:11434".to_string(),
        max_image_size: 1024 * 1024,
        max_batch_size: 10,
    };
    
    let installer = InstallManager::new(config);
    
    // Create directories
    installer.create_directories().await?;
    
    // Download wiki dump (will be slow)
    let dump_path = installer.download_wikidump().await?;
    
    // Verify dump was downloaded
    assert!(dump_path.exists());
    assert!(dump_path.metadata()?.len() > 0);
    
    // Cleanup
    installer.uninstall().await?;
    
    Ok(())
} 