#!/bin/bash
set -e

# Create directories if they don't exist
mkdir -p /app/user

# Ensure the script passes on exit signals to the child process
trap 'kill -TERM $PID' TERM INT

# Print the expanded command
resolved_cmd=""
for arg in "$@"; do
    # Replace environment variables in the argument
    eval "resolved_arg=\"$arg\""
    resolved_cmd="$resolved_cmd $resolved_arg"
done
echo "Starting ComfyUI with resolved command:$resolved_cmd"

"$@" &
PID=$!
wait $PID
trap - TERM INT
wait $PID
EXIT_STATUS=$?

exit $EXIT_STATUS 