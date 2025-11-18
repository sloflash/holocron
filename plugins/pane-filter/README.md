# Pane Filter Plugin for Zellij

A powerful Zellij plugin that allows you to filter panes using regex patterns and execute configurable methods/actions on them.

## Features

- **Pane Filtering**: Filter panes using multiple regex patterns
- **Interactive UI**: Browse filtered panes with keyboard navigation
- **Configurable Methods**: Execute predefined methods on selected panes
- **GitHub Integration**: Load method configurations from a GitHub repository
- **Docker Support**: Run methods in Docker containers
- **Confirmation Prompts**: Require confirmation for destructive operations

## Installation

### Prerequisites

- Rust toolchain (`rustup`)
- Zellij (installed)
- `wasm32-wasi` target for Rust

### Build the Plugin

```bash
cd plugins/pane-filter
./build.sh
```

This will:
1. Install the `wasm32-wasi` target if needed
2. Compile the plugin to WASM
3. Create `pane-filter.wasm` in the plugin directory

## Configuration

### 1. Plugin Configuration (plugin.kdl)

Edit `plugin.kdl` to configure the plugin:

```kdl
plugin {
    location "file:/path/to/pane-filter.wasm"

    configuration {
        // Comma-separated regex patterns to filter panes
        pane_filters "k9s,^repo-.*,.*bash.*"

        // GitHub repository containing methods configuration
        methods_repo "your-org/your-methods-repo"

        // Branch to fetch from (default: main)
        methods_branch "main"

        // Path to methods.json (default: methods.json)
        methods_path "methods.json"
    }
}
```

#### Filter Patterns

The `pane_filters` configuration accepts comma-separated regex patterns:

- `k9s` - Match panes with "k9s" in the title
- `^repo-.*` - Match panes starting with "repo-"
- `.*bash.*` - Match panes containing "bash"
- Leave empty to show all panes

### 2. Methods Configuration (GitHub Repository)

Create a GitHub repository with a `methods.json` file defining your methods:

```json
{
  "version": "1.0.0",
  "methods": [
    {
      "id": "restart-pod",
      "name": "Restart Pod",
      "description": "Restart the currently selected Kubernetes pod",
      "command": "kubectl",
      "args": ["delete", "pod", "--grace-period=0"],
      "env": {},
      "requires_confirmation": true
    },
    {
      "id": "docker-debug",
      "name": "Debug with Docker",
      "description": "Run debugging tools in a container",
      "docker_image": "nicolaka/netshoot",
      "command": "bash",
      "args": [],
      "env": {
        "DEBUG_MODE": "true"
      },
      "requires_confirmation": false
    }
  ]
}
```

#### Method Properties

- `id` (required): Unique identifier
- `name` (required): Display name
- `description` (required): Description shown in UI
- `command` (required): Command to execute
- `args` (optional): Array of command arguments
- `docker_image` (optional): If specified, runs command in this Docker container
- `env` (optional): Environment variables
- `requires_confirmation` (optional): Whether to prompt before execution

## Usage

### Loading the Plugin

Add the plugin to your Zellij layout:

```kdl
layout {
    tab {
        pane {
            plugin location="file:/path/to/pane-filter.wasm" {
                pane_filters "k9s,bash"
                methods_repo "your-org/your-methods-repo"
            }
        }
    }
}
```

Or use a keybinding in your Zellij config:

```kdl
keybinds {
    normal {
        bind "Ctrl p" {
            LaunchPlugin "file:/path/to/pane-filter.wasm" {
                pane_filters "k9s,bash"
                methods_repo "your-org/your-methods-repo"
            }
        }
    }
}
```

### Keyboard Shortcuts

#### Pane Browser Mode
- `↑/k`: Move selection up
- `↓/j`: Move selection down
- `Enter/Space`: Select pane and show methods
- `f`: Focus on selected pane (and close plugin)
- `r`: Refresh methods from GitHub
- `q/Esc`: Close plugin

#### Method Selection Mode
- `↑/k`: Move selection up
- `↓/j`: Move selection down
- `Enter/Space`: Execute selected method
- `Esc/q`: Back to pane browsing

#### Confirmation Mode
- `y`: Confirm and execute
- `n/Esc`: Cancel

## Integration with Holocron

To integrate with the Holocron terminal control system:

1. The plugin is automatically built during Holocron installation
2. Add a keybinding in your Zellij config to launch the plugin
3. Configure your methods repository with Kubernetes and development tools

### Example Holocron Methods Repository Structure

```
your-methods-repo/
├── methods.json          # Main methods configuration
├── k8s/                  # Kubernetes-specific methods
│   └── methods.json
├── docker/               # Docker-specific methods
│   └── methods.json
└── dev/                  # Development methods
    └── methods.json
```

## Use Cases

### Kubernetes Management
- Filter for k9s panes
- Execute kubectl commands (restart pods, view logs, describe resources)
- Port forward to selected pods
- Open shell in containers

### Repository Management
- Filter for repository panes
- Run git commands (status, pull, push)
- Execute build scripts
- Run tests

### Docker Operations
- Filter for Docker-related panes
- Manage containers
- Run debugging tools in containers
- Execute docker-compose commands

## Troubleshooting

### Plugin doesn't show any panes
- Ensure your regex patterns are correct
- Try removing filters to see all panes
- Check that Zellij has panes open in the session

### Methods not loading
- Verify the GitHub repository URL is correct
- Check that the repository is public or accessible
- Ensure `methods.json` exists at the specified path
- Use `r` key to manually refresh methods

### Build errors
- Ensure Rust is installed: `rustup --version`
- Install wasm32-wasi target: `rustup target add wasm32-wasi`
- Update dependencies: `cargo update`

## Example Methods Repository

See `methods.json.example` for a complete example with:
- Kubernetes operations
- Git commands
- NPM/Node.js operations
- Docker commands
- Custom debugging tools

## Contributing

To add new features or fix bugs:

1. Modify the source code in `src/`
2. Run `./build.sh` to compile
3. Test in Zellij
4. Submit improvements

## License

Part of the Holocron terminal control system.
