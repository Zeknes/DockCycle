#!/bin/bash

echo "Checking status of Click2Circle..."

# Check process
if pgrep -f "Click2Circle" > /dev/null || pgrep -f "main" > /dev/null; then
    echo "✅ Service is RUNNING."
else
    echo "❌ Service is NOT running."
fi

# Check logs
LOG_FILE="/tmp/click2circle.log"
ERR_FILE="/tmp/click2circle.err"

echo ""
echo "--- Standard Output ($LOG_FILE) ---"
if [ -f "$LOG_FILE" ]; then
    tail -n 10 "$LOG_FILE"
else
    echo "(Log file not found)"
fi

echo ""
echo "--- Error Output ($ERR_FILE) ---"
if [ -f "$ERR_FILE" ]; then
    tail -n 10 "$ERR_FILE"
else
    echo "(Error file not found)"
fi
