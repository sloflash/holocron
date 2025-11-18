mod config;
mod state;
mod ui;

use config::{MethodsConfig, PluginConfig};
use state::{Mode, State};
use zellij_tile::prelude::*;

#[derive(Default)]
struct PaneFilterPlugin {
    state: State,
}

register_plugin!(PaneFilterPlugin);

impl ZellijPlugin for PaneFilterPlugin {
    fn load(&mut self, configuration: BTreeMap<String, String>) {
        // Request permissions
        request_permission(&[
            PermissionType::ReadApplicationState,
            PermissionType::ChangeApplicationState,
            PermissionType::RunCommands,
            PermissionType::OpenFiles,
            PermissionType::WebAccess,
        ]);

        subscribe(&[
            EventType::Key,
            EventType::PaneUpdate,
            EventType::TabUpdate,
            EventType::Mouse,
            EventType::Timer,
        ]);

        // Parse configuration
        let config = self.parse_configuration(configuration);
        self.state.update_config(config);

        // Load methods from GitHub if configured
        if !self.state.config.methods_repo.is_empty() {
            self.fetch_methods();
        }
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            Event::Key(key) => self.handle_key(key),
            Event::PaneUpdate(pane_manifest) => {
                self.state.update_panes(&pane_manifest);
                true
            }
            Event::CustomMessage(message, payload) => {
                self.handle_custom_message(&message, &payload);
                true
            }
            Event::Timer(_) => {
                // Periodic refresh
                true
            }
            _ => false,
        }
    }

    fn render(&mut self, rows: usize, cols: usize) {
        ui::render(&self.state, rows, cols);
    }
}

impl PaneFilterPlugin {
    fn parse_configuration(&self, configuration: BTreeMap<String, String>) -> PluginConfig {
        // Try to parse as JSON first
        if let Some(json_config) = configuration.get("_json") {
            if let Ok(config) = serde_json::from_str::<PluginConfig>(json_config) {
                return config;
            }
        }

        // Fall back to manual parsing
        let mut config = PluginConfig::default();

        if let Some(filters) = configuration.get("pane_filters") {
            config.pane_filters = filters
                .split(',')
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect();
        }

        if let Some(repo) = configuration.get("methods_repo") {
            config.methods_repo = repo.clone();
        }

        if let Some(branch) = configuration.get("methods_branch") {
            config.methods_branch = branch.clone();
        }

        if let Some(path) = configuration.get("methods_path") {
            config.methods_path = path.clone();
        }

        config
    }

    fn handle_key(&mut self, key: Key) -> bool {
        match self.state.mode {
            Mode::BrowsePanes => self.handle_browse_keys(key),
            Mode::SelectMethod => self.handle_method_select_keys(key),
            Mode::Confirm => self.handle_confirm_keys(key),
        }
    }

    fn handle_browse_keys(&mut self, key: Key) -> bool {
        match key {
            Key::Up | Key::Char('k') => {
                self.state.move_selection_up();
                true
            }
            Key::Down | Key::Char('j') => {
                self.state.move_selection_down();
                true
            }
            Key::Char('\n') | Key::Char(' ') => {
                // Enter method selection
                self.state.enter_method_selection();
                true
            }
            Key::Char('q') | Key::Esc => {
                // Close plugin
                close_self();
                false
            }
            Key::Char('r') => {
                // Refresh methods
                if !self.state.config.methods_repo.is_empty() {
                    self.fetch_methods();
                }
                true
            }
            Key::Char('f') => {
                // Focus on selected pane
                if let Some(pane) = self.state.get_selected_pane() {
                    focus_terminal_pane(pane.id, false);
                    close_self();
                }
                false
            }
            _ => false,
        }
    }

    fn handle_method_select_keys(&mut self, key: Key) -> bool {
        match key {
            Key::Up | Key::Char('k') => {
                self.state.move_selection_up();
                true
            }
            Key::Down | Key::Char('j') => {
                self.state.move_selection_down();
                true
            }
            Key::Char('\n') | Key::Char(' ') => {
                // Execute method
                self.execute_selected_method();
                true
            }
            Key::Esc | Key::Char('q') => {
                // Back to pane browsing
                self.state.back_to_pane_browsing();
                true
            }
            _ => false,
        }
    }

    fn handle_confirm_keys(&mut self, key: Key) -> bool {
        match key {
            Key::Char('y') | Key::Char('Y') => {
                // Confirmed, execute
                self.execute_selected_method();
                self.state.back_to_pane_browsing();
                true
            }
            Key::Char('n') | Key::Char('N') | Key::Esc => {
                // Cancelled
                self.state.mode = Mode::SelectMethod;
                true
            }
            _ => false,
        }
    }

    fn execute_selected_method(&mut self) {
        if let (Some(pane), Some(method)) = (
            self.state.get_selected_pane(),
            self.state.get_selected_method(),
        ) {
            // Check if confirmation is needed
            if method.requires_confirmation && self.state.mode != Mode::Confirm {
                self.state.mode = Mode::Confirm;
                return;
            }

            // Build the command
            let mut command_parts = vec![method.command.clone()];
            command_parts.extend(method.args.clone());

            // If docker image is specified, wrap in docker run
            let final_command = if let Some(ref image) = method.docker_image {
                let mut docker_cmd = vec![
                    "docker".to_string(),
                    "run".to_string(),
                    "--rm".to_string(),
                    "-i".to_string(),
                ];

                // Add environment variables
                for (key, value) in &method.env {
                    docker_cmd.push("-e".to_string());
                    docker_cmd.push(format!("{}={}", key, value));
                }

                docker_cmd.push(image.clone());
                docker_cmd.extend(command_parts);
                docker_cmd.join(" ")
            } else {
                command_parts.join(" ")
            };

            // Run the command in the selected pane
            run_command(
                &[final_command.as_str()],
                BTreeMap::new(),
            );

            self.state.status_message =
                Some(format!("Executed '{}' on pane {}", method.name, pane.id));

            // Switch focus to the pane
            focus_terminal_pane(pane.id, false);
        }
    }

    fn fetch_methods(&mut self) {
        self.state.is_loading = true;
        self.state.status_message = Some("Loading methods...".to_string());

        let repo = &self.state.config.methods_repo;
        let branch = &self.state.config.methods_branch;
        let path = &self.state.config.methods_path;

        // Build GitHub raw content URL
        let url = if repo.starts_with("http") {
            // Full URL provided, try to convert to raw URL
            repo.replace("github.com", "raw.githubusercontent.com")
                .replace("/blob/", "/")
        } else {
            // Assume "owner/repo" format
            format!(
                "https://raw.githubusercontent.com/{}/{}/{}",
                repo, branch, path
            )
        };

        // Use web_request to fetch the methods configuration
        // Note: This will trigger a CustomMessage event with the response
        post_message_to_plugin(PluginMessage {
            worker_name: None,
            name: "fetch_methods".to_string(),
            payload: url,
        });
    }

    fn handle_custom_message(&mut self, message: &str, payload: &str) {
        match message {
            "fetch_methods_response" => {
                // Parse the methods configuration
                match serde_json::from_str::<MethodsConfig>(payload) {
                    Ok(methods_config) => {
                        self.state.load_methods(methods_config);
                    }
                    Err(e) => {
                        self.state
                            .set_error(format!("Failed to parse methods: {}", e));
                    }
                }
            }
            "fetch_methods_error" => {
                self.state
                    .set_error(format!("Failed to fetch methods: {}", payload));
            }
            _ => {}
        }
    }
}
