#!/usr/bin/env bash
# Zellij Pane Analyzer
# Captures current pane content and analyzes it with Claude
# Results are sent to the analysis output file that the Cluster-Metrics pane monitors

set -euo pipefail

# Configuration
CAPTURE_DIR="/tmp/zellij-captures"
ANALYSIS_OUTPUT="/tmp/zellij-analysis-output.txt"
SESSION_NAME="${ZELLIJ_SESSION_NAME:-unknown}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CAPTURE_FILE="$CAPTURE_DIR/capture-${SESSION_NAME}-${TIMESTAMP}.txt"

# Ensure capture directory exists
mkdir -p "$CAPTURE_DIR"

# Dump current pane screen to file
echo "🔍 Capturing pane content..."
zellij action dump-screen "$CAPTURE_FILE"

# Check if capture succeeded
if [[ ! -s "$CAPTURE_FILE" ]]; then
    echo "❌ Failed to capture pane content" | tee -a "$ANALYSIS_OUTPUT"
    exit 1
fi

LINE_COUNT=$(wc -l < "$CAPTURE_FILE")
echo "✅ Captured ${LINE_COUNT} lines" | tee -a "$ANALYSIS_OUTPUT"

# Add separator to analysis output
{
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔬 Analysis started at $(date '+%Y-%m-%d %H:%M:%S')"
    echo "📁 Source: $CAPTURE_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
} >> "$ANALYSIS_OUTPUT"

# Analyze with Claude (if available)
if command -v claude &> /dev/null; then
    echo "🤖 Analyzing with Claude..." | tee -a "$ANALYSIS_OUTPUT"
    echo "" >> "$ANALYSIS_OUTPUT"

    # Send to Claude and append results
    claude "Analyze this K8s cluster output. Look for errors, warnings, resource issues, pod states, or any anomalies that need attention:" < "$CAPTURE_FILE" >> "$ANALYSIS_OUTPUT" 2>&1

    # Add closing separator
    {
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ Analysis completed"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    } >> "$ANALYSIS_OUTPUT"
else
    {
        echo "❌ Claude CLI not found. Install from: https://claude.ai/download"
        echo ""
        echo "Raw capture available at: $CAPTURE_FILE"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    } >> "$ANALYSIS_OUTPUT"
fi

# Keep last 1000 lines of analysis output to prevent file from growing too large
if [[ -f "$ANALYSIS_OUTPUT" ]]; then
    TEMP_FILE="${ANALYSIS_OUTPUT}.tmp"
    tail -1000 "$ANALYSIS_OUTPUT" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$ANALYSIS_OUTPUT"
fi

echo "✨ Analysis complete! Check bottom-right pane for results."
