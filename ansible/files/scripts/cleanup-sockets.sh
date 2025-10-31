#!/bin/bash
# Cleanup inactive socket files in the tunnel directory
# This script removes socket files that don't have active SSH connections
# Supports both legacy single-user and multi-user subdirectory structure

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

# Function to check and cleanup a socket file
check_socket() {
    local socket_file="$1"
    local socket_name=$(basename "$socket_file")
    local socket_path=$(dirname "$socket_file")
    
    # Check if the socket file has an active connection
    if lsof "$socket_file" >/dev/null 2>&1; then
        log_message "Socket $socket_path/$socket_name is active (has connections)"
    else
        # Socket exists but has no connections - remove it
        log_message "Removing inactive socket: $socket_path/$socket_name"
        if rm -f "$socket_file"; then
            removed_count=$((removed_count + 1))
            log_message "Successfully removed $socket_name"
        else
            log_message "ERROR: Failed to remove $socket_name"
        fi
    fi
}

# Check sockets in the root tunnel directory (legacy support)
while IFS= read -r -d '' socket_file; do
    check_socket "$socket_file"
done < <(find "$SOCKET_DIR" -maxdepth 1 -type s -print0 2>/dev/null)

# Check sockets in user subdirectories (multi-user support)
if [ -d "$SOCKET_DIR" ]; then
    for user_dir in "$SOCKET_DIR"/*; do
        if [ -d "$user_dir" ]; then
            while IFS= read -r -d '' socket_file; do
                check_socket "$socket_file"
            done < <(find "$user_dir" -maxdepth 1 -type s -print0 2>/dev/null)
        fi
    done
fi

log_message "Cleanup completed. Removed $removed_count inactive socket(s)"

exit 0
