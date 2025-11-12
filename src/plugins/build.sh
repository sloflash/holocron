#!/usr/bin/env bash
# Build all Zellij plugins

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR"
OUTPUT_DIR="$HOME/.config/zellij/plugins"

echo "🔨 Building Zellij plugins..."
echo ""

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Check for wasm32-wasi target
if ! rustup target list | grep -q "wasm32-wasi (installed)"; then
    echo "📦 Installing wasm32-wasi target..."
    rustup target add wasm32-wasi
fi

# Build k8s-analyzer
echo "Building k8s-analyzer..."
cd "$PLUGIN_DIR/k8s-analyzer"
cargo build --release --target wasm32-wasi

if [ $? -eq 0 ]; then
    echo "✅ k8s-analyzer built successfully"
    cp target/wasm32-wasi/release/k8s_analyzer.wasm "$OUTPUT_DIR/"
    echo "📦 Installed to: $OUTPUT_DIR/k8s_analyzer.wasm"
else
    echo "❌ k8s-analyzer build failed"
    exit 1
fi

echo ""
echo "✅ All plugins built and installed!"
echo ""
echo "Plugins installed to: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.wasm 2>/dev/null || echo "No WASM files found"
