use zellij_tile::prelude::*;
use std::collections::BTreeMap;

#[derive(Default)]
struct State {
    // Pane tracking
    available_panes: Vec<PaneInfo>,
    selected_index: usize,

    // View state
    view_mode: ViewMode,

    // Analysis state
    current_analysis_pane: Option<u32>,
    analysis_progress: AnalysisProgress,
    analysis_result: Option<String>,
    error_message: Option<String>,
}

#[derive(Default, PartialEq)]
enum ViewMode {
    #[default]
    PaneList,
    Analyzing,
    Results,
}

#[derive(Default)]
enum AnalysisProgress {
    #[default]
    Idle,
    Dumping,
    Processing,
    CallingClaude,
    Complete,
}

register_plugin!(State);

impl ZellijPlugin for State {
    fn load(&mut self, _configuration: BTreeMap<String, String>) {
        // Request necessary permissions
        request_permission(&[
            PermissionType::ReadApplicationState,
            PermissionType::RunCommands,
            PermissionType::ChangeApplicationState,
        ]);

        // Subscribe to events
        subscribe(&[
            EventType::Key,
            EventType::PaneUpdate,
            EventType::RunCommandResult,
            EventType::CustomMessage,
        ]);

        // Make plugin selectable for keyboard input
        set_selectable(true);

        // Initialize state
        self.view_mode = ViewMode::PaneList;
        self.analysis_progress = AnalysisProgress::Idle;
    }

    fn update(&mut self, event: Event) -> bool {
        let mut should_render = false;

        match event {
            Event::PaneUpdate(pane_manifest) => {
                // Update list of available terminal panes (exclude plugins)
                // pane_manifest.panes is HashMap<usize, Vec<PaneInfo>> where key is tab_index
                self.available_panes = pane_manifest.panes
                    .into_iter()
                    .flat_map(|(_tab_index, panes)| panes)
                    .filter(|p| !p.is_plugin)
                    .collect();

                // Reset selection if out of bounds
                if self.selected_index >= self.available_panes.len() && !self.available_panes.is_empty() {
                    self.selected_index = self.available_panes.len() - 1;
                }

                should_render = true;
            }

            Event::Key(key) => {
                should_render = self.handle_key(key);
            }

            Event::CustomMessage(name, _payload) => {
                if name == "trigger_analyze" {
                    self.start_analysis();
                    should_render = true;
                }
            }

            Event::RunCommandResult(exit_code, stdout, stderr, context) => {
                // Convert Vec<u8> to String
                let stdout_str = String::from_utf8_lossy(&stdout).to_string();
                let stderr_str = String::from_utf8_lossy(&stderr).to_string();
                should_render = self.handle_command_result(exit_code, stdout_str, stderr_str, context);
            }

            _ => {}
        }

        should_render
    }

    fn render(&mut self, rows: usize, cols: usize) {
        match self.view_mode {
            ViewMode::PaneList => self.render_pane_list(rows, cols),
            ViewMode::Analyzing => self.render_analyzing(rows, cols),
            ViewMode::Results => self.render_results(rows, cols),
        }
    }
}

impl State {
    fn handle_key(&mut self, key: KeyWithModifier) -> bool {
        match self.view_mode {
            ViewMode::PaneList => {
                if key.is_key_without_modifier(BareKey::Down) {
                    if !self.available_panes.is_empty() && self.selected_index < self.available_panes.len() - 1 {
                        self.selected_index += 1;
                        return true;
                    }
                } else if key.is_key_without_modifier(BareKey::Up) {
                    if self.selected_index > 0 {
                        self.selected_index -= 1;
                        return true;
                    }
                } else if key.is_key_without_modifier(BareKey::Enter) {
                    // Enter key triggers analysis
                    self.start_analysis();
                    return true;
                }
            }

            ViewMode::Results => {
                if key.is_key_without_modifier(BareKey::Esc)
                    || key.is_key_without_modifier(BareKey::Char('b'))
                    || key.is_key_without_modifier(BareKey::Char('q')) {
                    // Back to pane list
                    self.view_mode = ViewMode::PaneList;
                    self.analysis_progress = AnalysisProgress::Idle;
                    self.analysis_result = None;
                    self.error_message = None;
                    return true;
                } else if key.is_key_without_modifier(BareKey::Char('r')) {
                    // Re-analyze
                    self.start_analysis();
                    return true;
                }
            }

            ViewMode::Analyzing => {
                // Can't interrupt during analysis (future: allow Esc to cancel)
            }
        }

        false
    }

    fn start_analysis(&mut self) {
        if self.available_panes.is_empty() {
            self.error_message = Some("No panes available to analyze".to_string());
            return;
        }

        if let Some(pane) = self.available_panes.get(self.selected_index) {
            self.current_analysis_pane = Some(pane.id);
            self.view_mode = ViewMode::Analyzing;
            self.analysis_progress = AnalysisProgress::Dumping;
            self.error_message = None;

            // Generate unique logfile
            let timestamp = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs();
            let logfile = format!("/tmp/k9s-dump-{}.txt", timestamp);

            // Prepare context for command result
            let mut context = BTreeMap::new();
            context.insert("stage".to_string(), "dump".to_string());
            context.insert("logfile".to_string(), logfile.clone());
            context.insert("pane_id".to_string(), pane.id.to_string());

            // CRITICAL: Focus the target pane first using Zellij API
            // dump-screen dumps the FOCUSED pane, not a specific pane ID
            focus_terminal_pane(pane.id, true); // true = switch to pane's tab if needed

            // Small delay to ensure focus completes, then dump
            // We use a shell command to wait and dump
            let dump_command = format!(
                "sleep 0.1 && zellij action dump-screen --full {}",
                logfile
            );

            // Run dump command (will dump the now-focused target pane)
            run_command(
                &["sh", "-c", &dump_command],
                context,
            );
        }
    }

    fn handle_command_result(
        &mut self,
        exit_code: Option<i32>,
        stdout: String,
        stderr: String,
        context: BTreeMap<String, String>,
    ) -> bool {
        if let Some(stage) = context.get("stage") {
            match stage.as_str() {
                "dump" => {
                    if exit_code == Some(0) {
                        // Dump successful, now analyze
                        self.analysis_progress = AnalysisProgress::Processing;
                        if let Some(logfile) = context.get("logfile") {
                            self.call_claude_analysis(logfile);
                        }
                    } else {
                        self.error_message = Some(format!("Dump failed: {}", stderr));
                        self.view_mode = ViewMode::Results;
                    }
                    return true;
                }

                "analyze" => {
                    if exit_code == Some(0) {
                        // Analysis complete
                        self.analysis_result = Some(stdout);
                        self.analysis_progress = AnalysisProgress::Complete;
                        self.view_mode = ViewMode::Results;
                    } else {
                        self.error_message = Some(format!("Analysis failed: {}", stderr));
                        self.view_mode = ViewMode::Results;
                    }
                    return true;
                }

                _ => {}
            }
        }

        false
    }

    fn call_claude_analysis(&mut self, logfile: &str) {
        self.analysis_progress = AnalysisProgress::CallingClaude;

        // Build analysis command
        let analyze_cmd = format!(
            r#"claude --model haiku "Analyze this Kubernetes/system output for issues, errors, warnings, anomalies, and patterns. Be concise and highlight critical findings." < {}"#,
            logfile
        );

        let mut context = BTreeMap::new();
        context.insert("stage".to_string(), "analyze".to_string());

        run_command(
            &["bash", "-c", &analyze_cmd],
            context,
        );
    }

    fn render_pane_list(&self, _rows: usize, cols: usize) {
        println!("╔{}╗", "═".repeat(cols.saturating_sub(2)));
        println!("║ 📊 AI Analyzer{}║", " ".repeat(cols.saturating_sub(17)));
        println!("╚{}╝", "═".repeat(cols.saturating_sub(2)));
        println!();

        if self.available_panes.is_empty() {
            println!("No panes available");
            println!();
            println!("Open k9s or other terminals");
            println!("to see them listed here.");
            return;
        }

        println!("Available Panes:");
        println!("{}", "─".repeat(cols.saturating_sub(1)));

        for (idx, pane) in self.available_panes.iter().enumerate() {
            let marker = if idx == self.selected_index { "▶" } else { " " };
            let icon = self.get_pane_icon(pane);

            // pane.title is now String, not Option<String>
            let title = if pane.title.is_empty() {
                "Untitled"
            } else {
                &pane.title
            };

            println!("{} {} {}", marker, icon, title);
        }

        println!();
        println!("{}", "─".repeat(cols.saturating_sub(1)));
        println!("↑↓     Navigate");
        println!("Alt+a  Analyze selected");
        println!("Enter  Analyze selected");
    }

    fn render_analyzing(&self, _rows: usize, cols: usize) {
        println!("╔{}╗", "═".repeat(cols.saturating_sub(2)));
        println!("║ 🤖 Analyzing...{}║", " ".repeat(cols.saturating_sub(18)));
        println!("╚{}╝", "═".repeat(cols.saturating_sub(2)));
        println!();

        if let Some(pane_id) = self.current_analysis_pane {
            println!("Pane ID: {}", pane_id);
            println!();
        }

        match &self.analysis_progress {
            AnalysisProgress::Dumping => {
                println!("⏳ Dumping pane content...");
            }
            AnalysisProgress::Processing => {
                println!("✅ Dump complete");
                println!("🔄 Processing logs...");
            }
            AnalysisProgress::CallingClaude => {
                println!("✅ Dump complete");
                println!("✅ Logs processed");
                println!("🤖 Analyzing with Claude...");
            }
            AnalysisProgress::Complete => {
                println!("✅ Analysis complete!");
            }
            _ => {}
        }
    }

    fn render_results(&self, rows: usize, cols: usize) {
        if let Some(error) = &self.error_message {
            println!("╔{}╗", "═".repeat(cols.saturating_sub(2)));
            println!("║ ❌ Error{}║", " ".repeat(cols.saturating_sub(11)));
            println!("╚{}╝", "═".repeat(cols.saturating_sub(2)));
            println!();
            println!("{}", error);
            println!();
            println!("{}", "─".repeat(cols.saturating_sub(1)));
            println!("[Esc/b] Back to list");
            return;
        }

        println!("╔{}╗", "═".repeat(cols.saturating_sub(2)));
        println!("║ ✅ Analysis Complete{}║", " ".repeat(cols.saturating_sub(23)));
        println!("╚{}╝", "═".repeat(cols.saturating_sub(2)));
        println!();

        if let Some(result) = &self.analysis_result {
            // Display result with basic wrapping
            for line in result.lines().take(rows.saturating_sub(8)) {
                let truncated = if line.len() > cols {
                    &line[..cols]
                } else {
                    line
                };
                println!("{}", truncated);
            }
        }

        println!();
        println!("{}", "─".repeat(cols.saturating_sub(1)));
        println!("[Esc/b/q] Back  [r] Re-analyze");
    }

    fn get_pane_icon(&self, pane: &PaneInfo) -> &str {
        // pane.title is now String, not Option<String>
        let lower = pane.title.to_lowercase();
        if lower.contains("prod") { return "🔴"; }
        if lower.contains("stag") { return "🟡"; }
        if lower.contains("dev") { return "🟢"; }
        if lower.contains("k9s") || lower.contains("k8s") { return "☸️"; }
        "📄"
    }
}
