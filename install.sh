#!/usr/bin/env bash
# Holocron One-Command Installer
# Run this script to install and configure Holocron

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
    ╔════════════════════════════════════════════════════════════════╗
    ║                                                                ║
    ║                 🌌  HOLOCRON  🌌                               ║
    ║         Terminal Control System - Installer                    ║
    ║                                                                ║
    ║   "An elegant terminal workspace... for a more civilized age"  ║
    ║                                                                ║
    ╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if setup script exists
if [[ ! -f "$SCRIPT_DIR/src/scripts/setup.sh" ]]; then
    echo -e "${GREEN}[ERROR]${NC} Setup script not found!"
    echo "Make sure you're running this from the Holocron repository root."
    exit 1
fi

# Run setup
exec "$SCRIPT_DIR/src/scripts/setup.sh" "$@"
