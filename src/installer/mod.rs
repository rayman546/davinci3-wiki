use std::path::{Path, PathBuf};
use tokio::fs;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn};
use std::process::Command;

use crate::error_handling::{WikiError, WikiResult};

const OLLAMA_VERSION: &str = "0.1.27";
const OLLAMA_MODEL: &str = "llama2";

#[derive(Debug, Serialize, Deserialize)]
pub struct InstallConfig {
    pub data_dir: PathBuf,
    pub cache_dir: PathBuf,
    pub vector_store_dir: PathBuf,
    pub ollama_url: String,
    pub max_image_size: usize,
    pub max_batch_size: usize,
}

impl Default for InstallConfig {
    fn default() -> Self {
        Self {
            data_dir: PathBuf::from("data"),
            cache_dir: PathBuf::from("cache"),
            vector_store_dir: PathBuf::from("vectors"),
            ollama_url: "http://localhost:11434".to_string(),
            max_image_size: 10 * 1024 * 1024, // 10MB
            max_batch_size: 32,
        }
    }
}

pub struct InstallManager {
    config: InstallConfig,
    client: Client,
}

impl InstallManager {
    pub fn new(config: InstallConfig) -> Self {
        Self {
            config,
            client: Client::new(),
        }
    }

    pub async fn install(&self) -> WikiResult<()> {
        info!("Starting installation...");

        // Create directories
        self.create_directories().await?;

        // Check and install Ollama
        self.install_ollama().await?;

        // Pull required models
        self.pull_models().await?;

        info!("Installation completed successfully!");
        Ok(())
    }

    async fn create_directories(&self) -> WikiResult<()> {
        info!("Creating directories...");
        fs::create_dir_all(&self.config.data_dir).await?;
        fs::create_dir_all(&self.config.cache_dir).await?;
        fs::create_dir_all(&self.config.vector_store_dir).await?;
        Ok(())
    }

    async fn install_ollama(&self) -> WikiResult<()> {
        info!("Checking Ollama installation...");

        if self.check_ollama_installed().await? {
            info!("Ollama is already installed");
            return Ok(());
        }

        info!("Installing Ollama...");
        
        #[cfg(target_os = "windows")]
        {
            let installer_url = format!(
                "https://github.com/jmorganca/ollama/releases/download/v{}/ollama-windows.exe",
                OLLAMA_VERSION
            );
            let response = self.client.get(&installer_url).send().await?;
            let bytes = response.bytes().await?;
            
            let installer_path = self.config.cache_dir.join("ollama-installer.exe");
            fs::write(&installer_path, &bytes).await?;

            let status = Command::new(installer_path)
                .arg("/VERYSILENT")
                .status()
                .map_err(|e| WikiError::Installation(format!("Failed to run Ollama installer: {}", e)))?;

            if !status.success() {
                return Err(WikiError::Installation("Ollama installation failed".to_string()));
            }
        }

        #[cfg(target_os = "linux")]
        {
            let status = Command::new("curl")
                .args(["-fsSL", "https://ollama.ai/install.sh"])
                .stdout(std::process::Stdio::piped())
                .spawn()
                .map_err(|e| WikiError::Installation(format!("Failed to download Ollama installer: {}", e)))?
                .wait()
                .map_err(|e| WikiError::Installation(format!("Failed to run Ollama installer: {}", e)))?;

            if !status.success() {
                return Err(WikiError::Installation("Ollama installation failed".to_string()));
            }
        }

        #[cfg(target_os = "macos")]
        {
            let status = Command::new("brew")
                .args(["install", "ollama"])
                .status()
                .map_err(|e| WikiError::Installation(format!("Failed to install Ollama: {}", e)))?;

            if !status.success() {
                return Err(WikiError::Installation("Ollama installation failed".to_string()));
            }
        }

        info!("Ollama installed successfully");
        Ok(())
    }

    async fn check_ollama_installed(&self) -> WikiResult<bool> {
        let status = Command::new("ollama")
            .arg("--version")
            .status()
            .map_err(|_| WikiError::Installation("Failed to check Ollama version".to_string()))?;

        Ok(status.success())
    }

    async fn pull_models(&self) -> WikiResult<()> {
        info!("Pulling required models...");

        let status = Command::new("ollama")
            .args(["pull", OLLAMA_MODEL])
            .status()
            .map_err(|e| WikiError::Installation(format!("Failed to pull model {}: {}", OLLAMA_MODEL, e)))?;

        if !status.success() {
            return Err(WikiError::Installation(format!("Failed to pull model {}", OLLAMA_MODEL)));
        }

        info!("Models pulled successfully");
        Ok(())
    }

    pub async fn uninstall(&self) -> WikiResult<()> {
        info!("Starting uninstallation...");

        // Remove directories
        if self.config.data_dir.exists() {
            fs::remove_dir_all(&self.config.data_dir).await?;
        }
        if self.config.cache_dir.exists() {
            fs::remove_dir_all(&self.config.cache_dir).await?;
        }
        if self.config.vector_store_dir.exists() {
            fs::remove_dir_all(&self.config.vector_store_dir).await?;
        }

        // Uninstall Ollama
        #[cfg(target_os = "windows")]
        {
            let status = Command::new("ollama")
                .args(["uninstall"])
                .status()
                .map_err(|e| WikiError::Installation(format!("Failed to uninstall Ollama: {}", e)))?;

            if !status.success() {
                return Err(WikiError::Installation("Ollama uninstallation failed".to_string()));
            }
        }

        #[cfg(any(target_os = "linux", target_os = "macos"))]
        {
            let status = Command::new("which")
                .arg("ollama")
                .output()
                .map_err(|e| WikiError::Installation(format!("Failed to locate Ollama: {}", e)))?;

            if status.status.success() {
                let ollama_path = String::from_utf8_lossy(&status.stdout);
                fs::remove_file(ollama_path.trim()).await?;
            }
        }

        info!("Uninstallation completed successfully!");
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[tokio::test]
    async fn test_install_manager() -> WikiResult<()> {
        let temp_dir = TempDir::new()?;
        let config = InstallConfig {
            data_dir: temp_dir.path().join("data"),
            cache_dir: temp_dir.path().join("cache"),
            vector_store_dir: temp_dir.path().join("vectors"),
            ..Default::default()
        };

        let installer = InstallManager::new(config);

        // Test installation
        installer.install().await?;

        // Verify directories were created
        assert!(installer.config.data_dir.exists());
        assert!(installer.config.cache_dir.exists());
        assert!(installer.config.vector_store_dir.exists());

        // Verify Ollama is installed
        assert!(installer.check_ollama_installed().await?);

        // Test uninstallation
        installer.uninstall().await?;

        // Verify directories were removed
        assert!(!installer.config.data_dir.exists());
        assert!(!installer.config.cache_dir.exists());
        assert!(!installer.config.vector_store_dir.exists());

        Ok(())
    }
} 