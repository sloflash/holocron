use crate::config::{Method, MethodsConfig, PluginConfig};
use regex::Regex;
use std::collections::HashMap;
use zellij_tile::prelude::*;

#[derive(Debug, Clone)]
pub struct PaneInfo {
    pub id: u32,
    pub title: String,
    pub is_focused: bool,
    pub is_plugin: bool,
    pub terminal_command: Option<String>,
}

#[derive(Debug, PartialEq)]
pub enum Mode {
    /// Browsing panes
    BrowsePanes,
    /// Selecting a method to apply
    SelectMethod,
    /// Confirming method execution
    Confirm,
}

pub struct State {
    /// Plugin configuration
    pub config: PluginConfig,

    /// Compiled regex patterns
    pub compiled_filters: Vec<Regex>,

    /// All available panes
    pub all_panes: Vec<PaneInfo>,

    /// Filtered panes (matching regex patterns)
    pub filtered_panes: Vec<PaneInfo>,

    /// Currently selected pane index
    pub selected_pane_index: usize,

    /// Current mode
    pub mode: Mode,

    /// Available methods
    pub methods: Vec<Method>,

    /// Selected method index
    pub selected_method_index: usize,

    /// Status/error messages
    pub status_message: Option<String>,

    /// Loading state
    pub is_loading: bool,

    /// Current tab info
    pub current_tab_index: usize,

    /// All tabs
    pub tabs: Vec<TabInfo>,
}

impl State {
    pub fn new() -> Self {
        Self {
            config: PluginConfig::default(),
            compiled_filters: vec![],
            all_panes: vec![],
            filtered_panes: vec![],
            selected_pane_index: 0,
            mode: Mode::BrowsePanes,
            methods: vec![],
            selected_method_index: 0,
            status_message: None,
            is_loading: false,
            current_tab_index: 0,
            tabs: vec![],
        }
    }

    pub fn update_config(&mut self, config: PluginConfig) {
        // Compile regex patterns
        let mut compiled = vec![];
        for pattern in &config.pane_filters {
            match Regex::new(pattern) {
                Ok(re) => compiled.push(re),
                Err(e) => {
                    self.status_message = Some(format!("Invalid regex '{}': {}", pattern, e));
                }
            }
        }
        self.compiled_filters = compiled;
        self.config = config;
    }

    pub fn update_panes(&mut self, pane_manifest: &PaneManifest) {
        let mut panes = vec![];

        // Collect all panes from all tabs
        for (tab_index, tab) in pane_manifest.panes.iter().enumerate() {
            for (pane_id, pane) in tab.iter() {
                panes.push(PaneInfo {
                    id: *pane_id,
                    title: pane.title.clone(),
                    is_focused: pane.is_focused,
                    is_plugin: pane.is_plugin,
                    terminal_command: None, // This would need to be tracked separately
                });
            }
        }

        self.all_panes = panes;
        self.filter_panes();
    }

    pub fn filter_panes(&mut self) {
        if self.compiled_filters.is_empty() {
            // No filters, show all panes
            self.filtered_panes = self.all_panes.clone();
        } else {
            // Apply filters
            self.filtered_panes = self
                .all_panes
                .iter()
                .filter(|pane| {
                    // Match against any of the regex patterns
                    self.compiled_filters
                        .iter()
                        .any(|re| re.is_match(&pane.title))
                })
                .cloned()
                .collect();
        }

        // Reset selection if out of bounds
        if self.selected_pane_index >= self.filtered_panes.len() && !self.filtered_panes.is_empty()
        {
            self.selected_pane_index = 0;
        }
    }

    pub fn move_selection_up(&mut self) {
        match self.mode {
            Mode::BrowsePanes => {
                if !self.filtered_panes.is_empty() && self.selected_pane_index > 0 {
                    self.selected_pane_index -= 1;
                }
            }
            Mode::SelectMethod => {
                if !self.methods.is_empty() && self.selected_method_index > 0 {
                    self.selected_method_index -= 1;
                }
            }
            _ => {}
        }
    }

    pub fn move_selection_down(&mut self) {
        match self.mode {
            Mode::BrowsePanes => {
                if self.selected_pane_index + 1 < self.filtered_panes.len() {
                    self.selected_pane_index += 1;
                }
            }
            Mode::SelectMethod => {
                if self.selected_method_index + 1 < self.methods.len() {
                    self.selected_method_index += 1;
                }
            }
            _ => {}
        }
    }

    pub fn get_selected_pane(&self) -> Option<&PaneInfo> {
        self.filtered_panes.get(self.selected_pane_index)
    }

    pub fn get_selected_method(&self) -> Option<&Method> {
        self.methods.get(self.selected_method_index)
    }

    pub fn enter_method_selection(&mut self) {
        if !self.filtered_panes.is_empty() && !self.methods.is_empty() {
            self.mode = Mode::SelectMethod;
            self.selected_method_index = 0;
        } else if self.methods.is_empty() {
            self.status_message = Some("No methods configured".to_string());
        }
    }

    pub fn back_to_pane_browsing(&mut self) {
        self.mode = Mode::BrowsePanes;
        self.status_message = None;
    }

    pub fn load_methods(&mut self, methods_config: MethodsConfig) {
        self.methods = methods_config.methods;
        self.is_loading = false;
        self.status_message = Some(format!("Loaded {} methods", self.methods.len()));
    }

    pub fn set_error(&mut self, message: String) {
        self.status_message = Some(message);
        self.is_loading = false;
    }
}
