#!/usr/bin/env bash
# Watch dump file and analyze with Claude when it changes

DUMP_FILE="/tmp/k9s-dump-latest.txt"
ANALYSIS_DIR="${1:-/tmp/holocron-analysis}"
LAST_MTIME=""

# Ensure analysis directory exists
mkdir -p "$ANALYSIS_DIR"
cd "$ANALYSIS_DIR"

echo "┌─────────────────────────────────────────────┐"
echo "│  Holocron Analyzer - Powered by Claude AI  │"
echo "├─────────────────────────────────────────────┤"
echo "│  Watching: $DUMP_FILE"
echo "│  Analysis Dir: $ANALYSIS_DIR"
echo "│  Model: Claude Haiku"
echo "└─────────────────────────────────────────────┘"
echo ""
echo "Waiting for dumps... Press Alt+a in any pane to start."
echo ""

while true; do
    if [[ -f "$DUMP_FILE" ]]; then
        # Get file modification time (cross-platform)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            CURRENT_MTIME=$(stat -f %m "$DUMP_FILE" 2>/dev/null)
        else
            CURRENT_MTIME=$(stat -c %Y "$DUMP_FILE" 2>/dev/null)
        fi

        # Check if file has been modified
        if [[ -n "$CURRENT_MTIME" && "$CURRENT_MTIME" != "$LAST_MTIME" ]]; then
            LAST_MTIME="$CURRENT_MTIME"

            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🔍 NEW DUMP DETECTED at $(date '+%H:%M:%S')"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""

            # Check if claude CLI is available
            if ! command -v claude &> /dev/null; then
                echo "❌ Claude CLI not found. Install Claude Code first."
                echo "   Visit: https://claude.ai/download"
                sleep 5
                continue
            fi

            # Analyze with Claude
            echo "🤖 Analyzing with Claude Haiku..."
            echo ""

            # Send to Claude for analysis
            if claude --model haiku "Analyze this Kubernetes/system output for issues, errors, warnings, anomalies, and patterns. Be concise and highlight critical findings." < "$DUMP_FILE"; then
                echo ""
                echo "✅ Analysis complete"
            else
                echo ""
                echo "❌ Analysis failed"
            fi

            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
        fi
    fi

    sleep 1
done
