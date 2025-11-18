#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Pane Filter Plugin...${NC}"

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: Rust/Cargo not found${NC}"
    echo "Please install Rust from https://rustup.rs/"
    exit 1
fi

# Check if wasm32-wasi target is installed
if ! rustup target list | grep -q "wasm32-wasi (installed)"; then
    echo -e "${YELLOW}Installing wasm32-wasi target...${NC}"
    rustup target add wasm32-wasi
fi

# Build the plugin
echo -e "${YELLOW}Compiling plugin to WASM...${NC}"
cargo build --release --target wasm32-wasi

# Copy the built WASM file to the plugin directory
WASM_FILE="../../target/wasm32-wasi/release/pane_filter.wasm"
if [ -f "$WASM_FILE" ]; then
    cp "$WASM_FILE" ./pane-filter.wasm
    echo -e "${GREEN}✓ Plugin built successfully: pane-filter.wasm${NC}"

    # Show file size
    SIZE=$(du -h pane-filter.wasm | cut -f1)
    echo -e "${GREEN}  Size: ${SIZE}${NC}"
else
    echo -e "${RED}Error: WASM file not found at $WASM_FILE${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Build complete!${NC}"
echo -e "${YELLOW}To use the plugin:${NC}"
echo "1. Update the methods_repo in plugin.kdl with your GitHub repository"
echo "2. Create a methods.json file in your repo (see methods.json.example)"
echo "3. Load the plugin in your Zellij layout"
