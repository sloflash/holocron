# Building Holocron Plugins

## Prerequisites

### 1. Install Rust
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
```

### 2. Add WASM target
```bash
rustup target add wasm32-wasi
```

### 3. Verify installation
```bash
cargo --version
rustc --version
rustup target list | grep wasm32-wasi
```

## Building Plugins

### Quick Build (All Plugins)
```bash
cd src/plugins
./build.sh
```

This will:
1. Build all plugins in release mode
2. Install WASM files to `~/.config/zellij/plugins/`
3. Show installation summary

### Manual Build (Single Plugin)
```bash
cd src/plugins/k8s-analyzer
cargo build --release --target wasm32-wasi

# Install manually
mkdir -p ~/.config/zellij/plugins
cp target/wasm32-wasi/release/k8s_analyzer.wasm ~/.config/zellij/plugins/
```

## Troubleshooting

### "cargo: command not found"
- Install Rust (see Prerequisites)
- Restart your shell after installation
- Run: `source ~/.cargo/env`

### "target 'wasm32-wasi' not found"
```bash
rustup target add wasm32-wasi
```

### Build errors
```bash
# Clean and rebuild
cargo clean
cargo build --release --target wasm32-wasi
```

### Plugin not loading
- Check file exists: `ls -l ~/.config/zellij/plugins/k8s_analyzer.wasm`
- Check Zellij version: `zellij --version` (need 0.40+)
- Check logs: `~/.cache/zellij/zellij.log`

## Development

### Watch mode (auto-rebuild on changes)
```bash
cargo watch -x 'build --release --target wasm32-wasi'
```

### Testing
```bash
# Syntax check only (fast)
cargo check --target wasm32-wasi

# Full build with warnings
cargo build --target wasm32-wasi --all-features

# Release build
cargo build --release --target wasm32-wasi
```

## Plugin Locations

- **Source**: `src/plugins/k8s-analyzer/`
- **Binary**: `src/plugins/k8s-analyzer/target/wasm32-wasi/release/k8s_analyzer.wasm`
- **Installed**: `~/.config/zellij/plugins/k8s_analyzer.wasm`
- **Layout reference**: `file:~/.config/zellij/plugins/k8s_analyzer.wasm`
