use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct PluginConfig {
    /// List of regex patterns to filter panes
    #[serde(default)]
    pub pane_filters: Vec<String>,

    /// GitHub repository URL for method configurations
    /// Format: "owner/repo" or full URL
    #[serde(default = "default_methods_repo")]
    pub methods_repo: String,

    /// Branch to fetch methods from
    #[serde(default = "default_branch")]
    pub methods_branch: String,

    /// Path within the repo to methods.json
    #[serde(default = "default_methods_path")]
    pub methods_path: String,
}

fn default_methods_repo() -> String {
    "".to_string()
}

fn default_branch() -> String {
    "main".to_string()
}

fn default_methods_path() -> String {
    "methods.json".to_string()
}

impl Default for PluginConfig {
    fn default() -> Self {
        Self {
            pane_filters: vec![],
            methods_repo: default_methods_repo(),
            methods_branch: default_branch(),
            methods_path: default_methods_path(),
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Method {
    /// Unique identifier for the method
    pub id: String,

    /// Display name
    pub name: String,

    /// Description of what this method does
    pub description: String,

    /// Docker image to use (optional)
    pub docker_image: Option<String>,

    /// Command to execute
    pub command: String,

    /// Arguments for the command
    #[serde(default)]
    pub args: Vec<String>,

    /// Environment variables
    #[serde(default)]
    pub env: HashMap<String, String>,

    /// Whether this requires confirmation
    #[serde(default)]
    pub requires_confirmation: bool,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct MethodsConfig {
    pub version: String,
    pub methods: Vec<Method>,
}
