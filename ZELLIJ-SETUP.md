# Zellij Setup Guide - Solarized Dark

This guide explains your Zellij layout configuration optimized for Solarized Dark theme.

## What's Changed

### 1. Shell Configuration
- All panes now use `zsh` instead of `bash`
- All repository panes and utility panes start with zsh

### 2. Kubernetes Contexts
Each k9s pane connects to a different minikube profile:
- **Prod EKS** (Upper Right, expanded): `prod-eks` context
- **Dev EKS** (Upper Right, stacked): `dev-eks` context
- **Ray EKS** (Upper Right, stacked): `ray-eks` context

### 3. Pane Layout with Border Colors
The layout uses 4 quadrants with distinct purposes:

**Q1 - Development Repositories (Upper Left, 50%x80%)**
- Border: GREEN (Solarized)
- 3 stacked zsh panes for your repos
- Panes: Driving, K8s, Deploy

**Q2 - OS Logs (Lower Left, 50%x20%)**
- Border: PINK/MAGENTA (Solarized)
- General purpose zsh pane for system logs

**Q3 - Kubernetes Monitoring (Upper Right, 50%x80%)**
- Border: ORANGE (Solarized)
- 3 stacked k9s panes, each with different context
- Panes: Prod EKS, Dev EKS, Ray EKS

**Q4 - Cluster Metrics (Lower Right, 50%x20%)**
- Border: YELLOW (Solarized)
- General purpose zsh pane for cluster utilities

### 4. Zellij Configuration
A new config file at `configs/zellij-config.kdl` includes:

**Theme:**
- Solarized Dark color scheme optimized for readability
- Uses proper Solarized palette (base03, base0, accent colors)

**Key Bindings:**
- `Ctrl+h`: Show keybindings help (compact-bar plugin)
- `Ctrl+s`: Toggle pane synchronization (type in all panes at once)
- `Alt+f`: Toggle fullscreen for current pane
- `Ctrl+q`: Quick quit/detach
- `Ctrl+Arrow`: Navigate between panes
- In Pane mode: `v` split down, `h` split right, `x` close pane
- In Tab mode: `1-5` to jump to specific tabs
- In Scroll mode: `PageUp/Down`, `Home/End`

**Features:**
- Default shell: `zsh`
- Mouse support enabled
- Copy-on-select enabled (macOS: `pbcopy`)
- Large scrollback buffer (100,000 lines)
- Rounded pane corners
- Session serialization enabled

## Font Scaling

**Important:** Zellij layouts cannot directly control terminal font size. Font sizing is controlled by your terminal emulator.

To increase font size for better readability:

### iTerm2:
1. Go to `Preferences` → `Profiles` → `Text`
2. Increase font size by 2-4 points (e.g., 12pt → 16pt)
3. Or use `⌘+` to increase font size temporarily

### Terminal.app:
1. Go to `Preferences` → `Profiles` → `Font`
2. Click `Change` and increase size
3. Or use `⌘+` to zoom in

### Alacritty:
Edit `~/.config/alacritty/alacritty.yml`:
```yaml
font:
  size: 14.0  # Increase by 2-4
```

### Kitty:
Edit `~/.config/kitty/kitty.conf`:
```conf
font_size 14.0  # Increase by 2-4
```

### WezTerm:
Edit `~/.wezterm.lua`:
```lua
config.font_size = 14.0  -- Increase by 2-4
```

## Border Colors

**Note:** Zellij does not support per-pane custom border colors. The color scheme uses:
- **Focused pane**: Bright/highlighted border (uses theme's focus color)
- **Unfocused panes**: Dimmer border

The comments in the layout file (GREEN, ORANGE, PINK, YELLOW) indicate the intended conceptual organization, but Zellij only supports focused vs unfocused styling.

To customize border colors, edit `configs/zellij-config.kdl`:
```kdl
themes {
    solarized-dark {
        fg "#839496"       // Text color
        bg "#002b36"       // Background
        green "#859900"    // Used for focused borders
        // ... other colors
    }
}
```

## Setting Up Minikube Clusters

The test-setup.sh script expects three minikube profiles to exist:

```bash
# Create three minikube clusters
minikube start -p prod-eks --driver=docker --cpus=2 --memory=2048
minikube start -p dev-eks --driver=docker --cpus=2 --memory=2048
minikube start -p ray-eks --driver=docker --cpus=2 --memory=2048

# Deploy sample pods to each cluster (optional)
kubectl config use-context prod-eks
kubectl create deployment prod-app --image=busybox --replicas=3 -- sleep 3600
kubectl create deployment prod-worker --image=busybox --replicas=2 -- sleep 3600

kubectl config use-context dev-eks
kubectl create deployment dev-app --image=busybox --replicas=2 -- sleep 3600
kubectl create deployment dev-test --image=busybox --replicas=1 -- sleep 3600

kubectl config use-context ray-eks
kubectl create deployment ray-cluster --image=busybox --replicas=4 -- sleep 3600
kubectl create deployment ray-worker --image=busybox --replicas=2 -- sleep 3600
```

## Using the Configuration

### Option 1: Test Environment
Run the test setup script which uses the existing minikube clusters:
```bash
NO_CLEANUP=true ./src/scripts/test-setup.sh setup
```

Then launch Zellij with the generated layout:
```bash
# Get the layout path from test-setup.sh output
zellij --layout /tmp/holocron-test-XXXXX/.config/holocron/layouts/hyperpod.kdl
```

### Option 2: Install Globally
To use this as your default Zellij configuration:

```bash
# Copy config
mkdir -p ~/.config/zellij
cp configs/zellij-config.kdl ~/.config/zellij/config.kdl

# Copy layout
mkdir -p ~/.config/holocron/layouts
cp src/layouts/hyperpod.kdl ~/.config/holocron/layouts/

# Launch
zellij --layout ~/.config/holocron/layouts/hyperpod.kdl
```

## Troubleshooting

### k9s shows errors
1. Check if Docker is running: `docker info`
2. Check minikube status: `minikube profile list`
3. Start stopped clusters: `minikube start -p <profile-name>`
4. Verify k9s works: `k9s --context prod-eks`

### Panes show bash errors
- The layout now uses `zsh` - make sure zsh is installed
- Check: `command -v zsh`
- Install on macOS: `brew install zsh`

### Colors don't match Solarized
1. Make sure your terminal is using Solarized Dark theme
2. Use the Zellij config: `--config configs/zellij-config.kdl`
3. Terminal color scheme takes precedence over Zellij theme

### Font is too small
- Increase font size in your terminal emulator (see Font Scaling section above)
- Zellij cannot control terminal font size directly

## Helpful Zellij Commands

Inside Zellij:
- `Ctrl+h` - Show all keybindings (compact-bar)
- `Ctrl+p` → `d` - Detach from session
- `Ctrl+t` - Enter tab mode (create, switch tabs)
- `Ctrl+p` - Enter pane mode (split, close panes)
- `Ctrl+n` - Enter resize mode
- `Ctrl+s` - Sync all panes (type in all at once)

Outside Zellij:
```bash
# List sessions
zellij list-sessions

# Attach to session
zellij attach <session-name>

# Delete session
zellij delete-session <session-name>

# Kill all sessions
zellij kill-all-sessions
```

## Next Steps

1. Increase your terminal font size by 2-4 points for better readability
2. Run `./src/scripts/test-setup.sh setup` to test the configuration
3. Launch Zellij with `--config configs/zellij-config.kdl`
4. Use `Ctrl+h` inside Zellij to see all available keybindings
5. Try `Ctrl+s` to sync panes and type commands across all panes at once
