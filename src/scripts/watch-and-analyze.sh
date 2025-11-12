#!/usr/bin/env bash
# Watch dump file and analyze with Claude when it changes

DUMP_FILE="/tmp/k9s-dump-latest.txt"
ANALYSIS_DIR="${1:-/tmp/holocron-analysis}"
LAST_CONTENT_HASH=""

# Ensure analysis directory exists
mkdir -p "$ANALYSIS_DIR"
cd "$ANALYSIS_DIR"

echo "┌─────────────────────────────────────────────┐"
echo "│  Holocron Analyzer - Powered by Claude AI  │"
echo "├─────────────────────────────────────────────┤"
echo "│  Watching: $DUMP_FILE"
echo "│  Analysis Dir: $ANALYSIS_DIR"
echo "│  Model: Claude Haiku"
echo "│  Detection: Content-based (md5sum)"
echo "└─────────────────────────────────────────────┘"
echo ""
echo "Waiting for dumps... Press Alt+a in any pane to start."
echo ""

while true; do
    if [[ -f "$DUMP_FILE" ]]; then
        # Get content hash instead of mtime (more reliable)
        if command -v md5sum &> /dev/null; then
            CURRENT_HASH=$(md5sum "$DUMP_FILE" 2>/dev/null | awk '{print $1}')
        elif command -v md5 &> /dev/null; then
            # macOS
            CURRENT_HASH=$(md5 -q "$DUMP_FILE" 2>/dev/null)
        else
            # Fallback to file size + mtime
            if [[ "$OSTYPE" == "darwin"* ]]; then
                CURRENT_HASH=$(stat -f "%z:%m" "$DUMP_FILE" 2>/dev/null)
            else
                CURRENT_HASH=$(stat -c "%s:%Y" "$DUMP_FILE" 2>/dev/null)
            fi
        fi

        # Check if content has changed
        if [[ -n "$CURRENT_HASH" && "$CURRENT_HASH" != "$LAST_CONTENT_HASH" ]]; then
            LAST_CONTENT_HASH="$CURRENT_HASH"

            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🔍 NEW DUMP DETECTED at $(date '+%H:%M:%S')"
            echo "   Hash: ${CURRENT_HASH:0:8}..."
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
            echo "Waiting for next dump..."
            echo ""
        fi
    fi

    sleep 0.5
done
