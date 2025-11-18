# 🌌 Holocron

> *An elegant terminal workspace... for a more civilized age*

**Holocron** is a sophisticated terminal control system built on Zellij that creates portable, multi-pane development environments. Inspired by the ancient Star Wars knowledge keepers, Holocron brings order and power to your terminal universe.

## ✨ Features

- **🎯 Quadrant-Based Layout**: Intelligent 4-quadrant workspace with stacked panes
- **📦 Portable Setup**: One command installs and configures across all your machines
- **🔄 Git Integration**: Automatically clones and manages your repositories
- **☸️ Kubernetes Ready**: Built-in k9s integration with multi-cluster support
- **🔌 Pane Filter Plugin**: Filter panes by regex and execute configurable methods/actions
- **🛠️ Dependency Management**: Automatically installs Zellij, kubectl, k9s, and more
- **⚙️ Highly Configurable**: YAML-based configuration with sensible defaults
- **🚀 Fast Workspace Switching**: Get coding in seconds, not minutes

## 🖼️ Workspace Layout

```
┌─────────────────────────────────┬──────────────┐
│  [Driving] [K8s] [Deploy]       │ [Prod] [Dev] │
├─────────────────────────────────┤  [Ray]       │
│                                 │              │
│  Q1: Repository Workspace       │ Q3: K8s      │
│      Stacked code repos         │    Clusters  │
│      (80% height)               │    (k9s)     │
│                                 │              │
├─────────────────────────────────┼──────────────┤
│  Q2: Logs/Monitoring            │ Q4: Cluster  │
│      (Future expansion)         │    Utilities │
└─────────────────────────────────┴──────────────┘
```

**Quadrant 1** (Upper Left): Stacked panes for 3 development repositories
**Quadrant 2** (Lower Left): Reserved for logs/monitoring
**Quadrant 3** (Upper Right): Stacked k9s panes for Kubernetes clusters
**Quadrant 4** (Lower Right): Cluster utilities and tools

## 📦 Installation

### Quick Install

```bash
git clone https://github.com/sloflash/holocron.git
cd holocron
./install.sh
```

The installer will:
1. ✅ Check and install dependencies (Zellij, kubectl, k9s, etc.)
2. 🦀 Optionally install Rust and build the Pane Filter plugin
3. 📝 Prompt for your git repository URLs
4. 📝 Prompt for your Kubernetes contexts
5. 📂 Clone repositories to `~/.holocron/workspace/`
6. ⚙️ Generate customized Zellij layout
7. 🚀 Create `holocron` launcher command

### Manual Installation

1. Ensure Zellij is installed: https://zellij.dev/documentation/installation
2. Clone this repository
3. Run `./src/scripts/setup.sh`

## 🚀 Usage

### Launch Hyperpod Workspace

```bash
holocron
```

### Other Commands

```bash
holocron config   # Edit configuration
holocron layout   # Edit Zellij layout
holocron update   # Update all repositories
```

### Keyboard Navigation

Holocron uses standard Zellij keybindings:

- `Alt + n`: Create new pane
- `Alt + [←↑↓→]`: Navigate between panes
- `Alt + [`: Cycle through stacked panes (Q1/Q3)
- `Ctrl + p` + `d`: Detach from session
- `Ctrl + p` + `q`: Quit Zellij

See [Zellij keybindings](https://zellij.dev/documentation/keybindings) for more.

## ⚙️ Configuration

### Configuration File

Located at: `~/.config/holocron/config.yaml`

```yaml
repositories:
  repo1:
    name: "Driving"
    url: "git@github.com:user/repo1.git"
    path: "~/.holocron/workspace/repo1"

kubernetes:
  enabled: true
  context1:
    name: "Prod EKS"
    context: "prod-eks-cluster"
```

### Layout File

Located at: `~/.config/holocron/layouts/hyperpod.kdl`

The layout is generated from your configuration during setup. You can edit it directly or run `holocron layout`.

### Workspace Structure

```
~/.holocron/
├── workspace/
│   ├── repo1/      # Your first repository
│   ├── repo2/      # Your second repository
│   └── repo3/      # Your third repository
└── logs/           # Optional logs directory

~/.config/holocron/
├── config.yaml     # Your configuration
├── layouts/
│   └── hyperpod.kdl  # Generated layout
└── plugins/
    └── pane-filter.wasm  # Pane Filter plugin
```

## 🧪 Testing with Minikube

Want to try Holocron without real clusters? We've got you covered!

```bash
# See the testing guide (coming soon)
./src/scripts/create-test-contexts.sh
```

This will create 3 minikube contexts for testing:
- `holocron-prod`
- `holocron-dev`
- `holocron-ray`

## 🛠️ Requirements

### Required
- [Zellij](https://zellij.dev/) - Terminal workspace
- Git - Repository management

### Optional (for full functionality)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI
- [k9s](https://k9scli.io/) - Kubernetes TUI
- Python, Rust, Terraform - For development tooling

The installer will help you install missing dependencies.

## 🔌 Pane Filter Plugin

The Pane Filter plugin is a powerful Zellij plugin that allows you to:

- **Filter panes** using regex patterns (e.g., "k9s", "bash", "^repo-.*")
- **Execute methods** on selected panes (kubectl commands, git operations, Docker commands)
- **Configure methods** via a GitHub repository with JSON configuration
- **Run Docker containers** for debugging and utilities

### Quick Start

1. **Launch the plugin** with `Ctrl+p` (requires keybinding setup)
2. **Browse filtered panes** using ↑/↓ arrows
3. **Select a pane** and press Enter to see available methods
4. **Execute a method** on the pane

### Configuration

Create a methods repository on GitHub with a `methods.json` file:

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
      "requires_confirmation": true
    }
  ]
}
```

### Setup Keybinding

Add to `~/.config/zellij/config.kdl`:

```kdl
keybinds {
    normal {
        bind "Ctrl p" {
            LaunchPlugin "file:~/.config/holocron/plugins/pane-filter.wasm" {
                floating true
                pane_filters "k9s,bash,repo"
                methods_repo "your-org/your-methods-repo"
            }
        }
    }
}
```

See [plugins/pane-filter/README.md](plugins/pane-filter/README.md) for complete documentation.

## 📚 Documentation

- [spec.md](spec.md) - Full technical specification
- [plugins/pane-filter/README.md](plugins/pane-filter/README.md) - Pane Filter plugin documentation
- [Zellij Documentation](https://zellij.dev/documentation/) - Learn about Zellij
- [Claude Code Skill](.claude/skills/zellij/) - Zellij expertise for development

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 🗺️ Roadmap

- [x] Basic 4-quadrant layout
- [x] Repository management
- [x] Kubernetes integration
- [x] Dependency installation
- [x] Pane Filter plugin
- [ ] Minikube test setup
- [ ] Pipe-based Q3 → Q4 communication
- [ ] Custom Q4 utilities
- [ ] Multi-workspace support
- [ ] Session persistence
- [ ] Cloud integration (AWS/GCP)

## 📝 License

MIT License - See [LICENSE](LICENSE) for details

## 🌟 Inspiration

Named after the ancient Jedi and Sith knowledge keepers, Holocron brings the wisdom and power of the Force to your terminal. May the terminals be with you!

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/sloflash/holocron/issues)
- **Discussions**: [GitHub Discussions](https://github.com/sloflash/holocron/discussions)

---

**Built with Claude Code** 🤖
*Generated with [Claude Code](https://claude.com/claude-code)*
