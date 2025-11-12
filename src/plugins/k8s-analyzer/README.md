# K8s Analyzer Plugin

Zellij plugin for AI-powered Kubernetes log analysis using Claude Haiku.

## Features

- **Pane List**: Shows all terminal panes with contextual icons
- **Smart Selection**: Navigate with ↑↓ without changing focus
- **One-Key Analysis**: Alt+a triggers AI analysis from anywhere
- **Claude Haiku**: Fast, cost-effective log analysis
- **Persistent View**: Results stay visible in static panel
- **Progress Tracking**: Clear status updates during analysis

## Building

```bash
cargo build --release --target wasm32-wasip1
```

Output: `target/wasm32-wasip1/release/k8s_analyzer.wasm`

## Installation

Copy the WASM file to Zellij plugins directory:

```bash
mkdir -p ~/.config/zellij/plugins
cp target/wasm32-wasip1/release/k8s_analyzer.wasm ~/.config/zellij/plugins/
```

## Usage

1. Add to your layout:
```kdl
pane {
    plugin location="file:~/.config/zellij/plugins/k8s_analyzer.wasm"
}
```

2. Add global keybinding:
```kdl
bind "Alt a" {
    MessagePlugin "file:~/.config/zellij/plugins/k8s_analyzer.wasm" {
        name "trigger_analyze"
    }
}
```

3. Navigate pane list with ↑↓
4. Press Alt+a or Enter to analyze selected pane
5. View results, press Esc to return to list

## Requirements

- Zellij 0.40+
- claude CLI installed and authenticated
- Rust toolchain with wasm32-wasip1 target
