#!/bin/bash
# Claude's feedback monitoring script
# This runs in background and tracks new feedback

REPO_DIR="/Users/mayankketkar/claude-tools/tmux"
FEEDBACK_LOG="$REPO_DIR/feedback.log"

echo "👀 Monitoring feedback log: $FEEDBACK_LOG"
echo "Waiting for new feedback..."

# Monitor the file for changes and output new lines
tail -f -n 0 "$FEEDBACK_LOG" | while IFS= read -r line; do
    echo "[FEEDBACK] $line"
done
