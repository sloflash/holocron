#!/usr/bin/env bash
# Simple on-demand analyzer - run this each time to analyze latest dump

DUMP_FILE="/tmp/k9s-dump-latest.txt"

if [[ ! -f "$DUMP_FILE" ]]; then
    echo "No dump file found at $DUMP_FILE"
    echo "Press Alt+a in any pane first"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Analyzing dump from $(date '+%H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v claude &> /dev/null; then
    echo "❌ Claude CLI not found"
    exit 1
fi

claude --model haiku "Analyze this Kubernetes/system output for issues, errors, warnings, anomalies, and patterns. Be concise and highlight critical findings." < "$DUMP_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
