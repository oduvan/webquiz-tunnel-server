#!/bin/bash
# Cleanup inactive socket files in the tunnel directory
# This script removes socket files that don't have active SSH connections

SOCKET_DIR="/var/run/tunnels"
LOG_FILE="/var/log/tunnel-cleanup.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check if socket directory exists
if [ ! -d "$SOCKET_DIR" ]; then
    log_message "ERROR: Socket directory $SOCKET_DIR does not exist"
    exit 1
fi

log_message "Starting socket cleanup check"

# Counter for removed sockets
removed_count=0

# Iterate through all socket files in the directory
for socket_file in "$SOCKET_DIR"/*; do
    # Skip if no socket files exist or if it's not a socket
    [ -e "$socket_file" ] || continue
    [ -S "$socket_file" ] || continue
    
    socket_name=$(basename "$socket_file")
    
    # Check if the socket file has an active connection
    # Use lsof to check if the socket is in use
    if lsof "$socket_file" >/dev/null 2>&1; then
        log_message "Socket $socket_name is active (has connections)"
    else
        # Socket exists but has no connections - remove it
        log_message "Removing inactive socket: $socket_name"
        if rm -f "$socket_file"; then
            removed_count=$((removed_count + 1))
            log_message "Successfully removed $socket_name"
        else
            log_message "ERROR: Failed to remove $socket_name"
        fi
    fi
done

log_message "Cleanup completed. Removed $removed_count inactive socket(s)"

exit 0
