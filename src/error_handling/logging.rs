use tracing::{Level, subscriber::set_global_default};
use tracing_subscriber::{EnvFilter, FmtSubscriber, fmt::format::FmtSpan};
use crate::error_handling::{WikiError, WikiResult};

/// Initialize logging with a custom level
pub fn init_logging(level: Level) -> WikiResult<()> {
    let subscriber = FmtSubscriber::builder()
        .with_env_filter(
            EnvFilter::from_default_env()
                .add_directive(level.into())
        )
        .with_target(true)
        .with_thread_ids(true)
        .with_file(true)
        .with_line_number(true)
        .pretty()
        .try_init();

    match subscriber {
        Ok(_) => Ok(()),
        Err(e) => Err(WikiError::OperationFailed(format!(
            "Failed to initialize logging: {}", e
        ))),
    }
}

/// Initialize logging for development with detailed output
pub fn init_debug_logging() -> WikiResult<()> {
    let subscriber = FmtSubscriber::builder()
        .with_env_filter(
            EnvFilter::from_default_env()
                .add_directive(Level::DEBUG.into())
                .add_directive("tokio=debug".parse().unwrap())
                .add_directive("runtime=debug".parse().unwrap())
        )
        .with_target(true)
        .with_thread_ids(true)
        .with_file(true)
        .with_line_number(true)
        .with_span_events(FmtSpan::FULL)
        .pretty()
        .try_init();

    match subscriber {
        Ok(_) => Ok(()),
        Err(e) => Err(WikiError::OperationFailed(format!(
            "Failed to initialize debug logging: {}", e
        ))),
    }
}

/// Initialize logging for production with minimal output
pub fn init_production_logging() -> WikiResult<()> {
    let subscriber = FmtSubscriber::builder()
        .with_env_filter(
            EnvFilter::from_default_env()
                .add_directive(Level::INFO.into())
                .add_directive("tokio=warn".parse().unwrap())
                .add_directive("runtime=warn".parse().unwrap())
        )
        .with_target(false)
        .with_thread_ids(false)
        .with_file(false)
        .with_line_number(false)
        .with_span_events(FmtSpan::NONE)
        .try_init();

    match subscriber {
        Ok(_) => Ok(()),
        Err(e) => Err(WikiError::OperationFailed(format!(
            "Failed to initialize production logging: {}", e
        ))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_init_logging() {
        assert!(init_logging(Level::DEBUG).is_ok());
    }

    #[test]
    fn test_debug_logging() {
        assert!(init_debug_logging().is_ok());
    }

    #[test]
    fn test_production_logging() {
        assert!(init_production_logging().is_ok());
    }
} 