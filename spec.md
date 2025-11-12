# Holocron - Terminal Control System Specification

## Overview

Holocron is a portable terminal workspace builder that creates sophisticated, multi-pane development environments using Zellij. It's designed to be installed and configured across multiple machines (laptops, VMs) with a consistent setup experience.

## Core Architecture

### Workspace Name
**Hyperpod** - A single Zellij workspace template with intelligent quadrant-based layout

### Layout Structure
```
┌─────────────────────────────────┬──────────────┐
│                                 │              │
│        Quadrant 1 (Q1)          │ Quadrant 3   │
│     Stacked Code Repos          │  (Q3) K8s    │
│      (80% height)               │  Clusters    │
│                                 │              │
├─────────────────────────────────┼──────────────┤
│                                 │              │
│    Quadrant 2 (Q2) - TBD        │ Quadrant 4   │
│      (20% height)               │  (Q4) TBD    │
│                                 │              │
└─────────────────────────────────┴──────────────┘
│         50% width              │  50% width   │
```

## Detailed Quadrant Specifications

### Quadrant 1: Development Repositories (Upper Left)
**Dimensions:** 50% width × 80% height
**Type:** Stacked panes (3 total, 1 visible at a time)
**Purpose:** Primary development workspaces

#### Repositories:
1. **Repository 1: Driving**
   - Primary development repo
   - User provides git URL during setup
   - Cloned to: `~/.holocron/workspace/repo1/`
   - Pane `cwd` set to this path

2. **Repository 2: K8s**
   - Kubernetes configurations
   - User provides git URL during setup
   - Cloned to: `~/.holocron/workspace/repo2/`
   - Pane `cwd` set to this path

3. **Repository 3: K8s Deploy**
   - Deployment configurations
   - User provides git URL during setup
   - Cloned to: `~/.holocron/workspace/repo3/`
   - Pane `cwd` set to this path

#### Repository Management:
- **Workspace Root**: `~/.holocron/workspace/`
- **Setup Flow**:
  1. Installer prompts for git repository URLs (e.g., `git@github.com:user/repo.git`)
  2. Clones each repository to fixed paths: `repo1/`, `repo2/`, `repo3/`
  3. Generates layout with proper `cwd` paths for each pane
  4. Saves configuration to `~/.config/holocron/config.yaml`
- **Benefits**:
  - Consistent workspace structure across machines
  - Easy backup and migration (just sync `~/.holocron/`)
  - Isolated from other projects
  - Clean separation of Holocron workspace from personal projects

#### Features:
- Each pane opens to its respective repository directory using Zellij's `cwd`
- Stacked layout: only one pane fully visible, others minimized
- Optimized for Python, Rust, K8s, and Terraform development
- Should detect and configure language servers when possible
- Repositories automatically cloned during setup
- Can re-clone or update repositories via setup script

### Quadrant 2: Future Expansion (Lower Left)
**Dimensions:** 50% width × 20% height
**Type:** Placeholder
**Purpose:** Reserved for future tooling (logs, monitoring, etc.)

#### Implementation:
- Single empty pane for now
- Will be connected to Q1 in future iterations

### Quadrant 3: Kubernetes Cluster Management (Upper Right)
**Dimensions:** 50% width × 80% height
**Type:** Stacked panes (2-3 total, 1 visible at a time)
**Purpose:** K8s cluster monitoring and management

#### Cluster Contexts:
1. **Production EKS**
   - Context: configurable during setup
   - Tool: k9s
   - Isolated kubectx configuration

2. **Development EKS**
   - Context: configurable during setup
   - Tool: k9s
   - Isolated kubectx configuration

3. **Production Ray EKS** (optional)
   - Context: configurable during setup
   - Tool: k9s
   - Isolated kubectx configuration

#### Features:
- Each pane maintains independent Kubernetes context
- k9s pre-loaded and configured
- Context isolation ensures no cross-pane interference
- If context not provided during setup, pane is skipped

### Quadrant 4: Cluster Utilities (Lower Right)
**Dimensions:** 50% width × 20% height
**Type:** Multiple panes (1 per Q3 pane)
**Purpose:** Supporting tools for Q3 clusters

#### Implementation:
- One pane per active Q3 cluster
- Connected to corresponding Q3 pane via Zellij pipes
- Future: Will display logs, metrics, or cluster-specific utilities
- For now: Placeholder panes that can receive pipe messages

#### Pipe Configuration:
- Bidirectional communication between Q3 and Q4 panes
- Named pipes based on cluster context
- Convention: `cluster-{context-name}-pipe`

## Installation & Setup System

### Requirements
- Zellij installed
- Git
- kubectl (for K8s panes)
- k9s (for K8s monitoring)
- Optional: Python, Rust, Terraform toolchains

### Setup Script Features
1. **Interactive Configuration:**
   - Prompt for repository paths/URLs
   - Prompt for K8s cluster contexts
   - Validate dependencies

2. **Template Generation:**
   - Creates customized Zellij layout (KDL format)
   - Generates startup scripts for each pane
   - Sets up pipe configurations

3. **Portability:**
   - Single command installation
   - Works across Linux, macOS, WSL
   - Stores configs in standard locations
   - Version controlled setup

### Directory Structure

#### Project Repository Structure
```
holocron/
├── src/
│   ├── layouts/
│   │   └── hyperpod.kdl          # Main Zellij layout template
│   ├── scripts/
│   │   ├── setup.sh              # Main setup script
│   │   ├── repo-init.sh          # Repository clone/update
│   │   ├── k8s-init.sh           # K8s context setup
│   │   └── pipe-config.sh        # Pipe configuration
│   └── templates/
│       └── pane-templates.kdl    # Reusable pane configs
├── configs/
│   └── default-config.yaml       # Default configuration values
├── install.sh                    # One-command installer
└── README.md                     # Documentation
```

#### User Installation Structure
After installation, the following directories are created:

```
~/.holocron/
├── workspace/
│   ├── repo1/                    # Cloned Repository 1
│   ├── repo2/                    # Cloned Repository 2
│   └── repo3/                    # Cloned Repository 3
└── logs/                         # Optional: Holocron logs

~/.config/holocron/
├── config.yaml                   # User configuration
└── layouts/
    └── hyperpod.kdl              # Generated layout (with real paths)

~/.local/share/zellij/
└── (Zellij data directory)
```

## User Experience

### Startup Flow
1. Run `holocron start` or `zellij --layout hyperpod`
2. Zellij loads with all quadrants configured
3. Repository panes cd to configured directories
4. K8s panes launch k9s with respective contexts
5. Pipes establish connections between Q3 and Q4
6. User sees familiar, consistent workspace across all machines

### Navigation
- Tab bar: Shows "Hyperpod" workspace name
- Status bar: Shows current pane, keybindings
- Pane switching: Standard Zellij navigation
- Stack navigation: Cycle through stacked panes in Q1 and Q3

## Technical Considerations

### Zellij Layout (KDL)
- Use `pane_template` for reusable pane configs
- Use `stacked: true` with `expanded: true` for Q1 and Q3
- Configure `cwd` per pane for repository navigation
- Use `command` property to launch k9s with context
- Use `name` property for pane identification

### Pipe Implementation
- Configure pipes in layout file
- Use named pipes for Q3 <-> Q4 communication
- Future: Plugin development for advanced pipe features

### Configuration Management
- YAML/TOML for user configuration
- Template variables replaced during setup
- Version controlled templates
- User overrides in `~/.config/holocron/config.yaml`

## Future Enhancements

1. **Multi-workspace support:** Different layouts for different projects
2. **Plugin system:** Custom Q4 utilities
3. **Remote session sharing:** Team collaboration features
4. **Auto-detection:** Detect project types and configure accordingly
5. **Session persistence:** Save and restore workspace state
6. **Cloud integration:** AWS, GCP console integration
7. **Custom quadrants:** User-defined layouts beyond 4 quadrants

## Development Phases

### Phase 1: MVP (Complete)
- [x] Research Zellij capabilities
- [x] Create basic layout with 4 quadrants
- [x] Implement stacked panes for Q1
- [x] Basic setup script for repos
- [x] Created Zellij skill for Claude Code
- [x] Repository management with git cloning

### Phase 2: K8s Integration (Complete)
- [x] Implement Q3 with k9s
- [x] Context isolation (each pane independent)
- [x] Setup script for cluster configs
- [x] Dependency installation (kubectl, k9s)

### Phase 3: Pipes & Communication (In Progress)
- [ ] Configure Q3 <-> Q4 pipes
- [ ] Basic message passing
- [ ] Pipe-based utilities in Q4
- [ ] Q4 plugin development

### Phase 4: Installation & Portability (Complete)
- [x] One-command installer
- [x] Automated testing script
- [x] Cross-platform support (macOS, Linux)
- [x] Documentation (README, spec)
- [x] Minikube test contexts
- [ ] Package for distribution (Future)

### Phase 5: Testing & Refinement (In Progress)
- [x] Automated test setup without user input
- [x] Clean test environment with teardown
- [ ] Create minikube test contexts
- [ ] End-to-end testing
- [ ] Performance optimization

## Success Criteria

- [x] One command installs and configures Holocron
- [x] Consistent experience across all machines
- [x] Repositories and contexts easily configurable
- [x] Stacked panes work smoothly in Q1 and Q3
- [x] K8s contexts isolated and functional
- [x] All dependencies properly detected/installed
- [x] Setup takes < 5 minutes from scratch
