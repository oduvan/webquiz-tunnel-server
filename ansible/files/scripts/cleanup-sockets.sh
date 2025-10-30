#!/bin/bash
# Cleanup inactive socket files in the tunnel directory
# This script removes socket files that don't have active SSH connections
# and ensures proper permissions on active sockets

SOCKET_DIR="/var/run/tunnels"
LOG_FILE="/var/log/tunnel-cleanup.log"
TUNNEL_GROUP="tunneluser"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check if socket directory exists
if [ ! -d "$SOCKET_DIR" ]; then
    log_message "ERROR: Socket directory $SOCKET_DIR does not exist"
    exit 1
fi

log_message "Starting socket cleanup and permission check"

# Counter for removed sockets
removed_count=0
# Counter for permission fixes
permission_fixes=0

# Iterate through all .sock files in the directory
for socket_file in "$SOCKET_DIR"/*.sock; do
    # Skip if no socket files exist
    [ -e "$socket_file" ] || continue
    
    socket_name=$(basename "$socket_file")
    
    # Check if the socket file has an active connection
    # Use lsof to check if the socket is in use
    if lsof "$socket_file" >/dev/null 2>&1; then
        log_message "Socket $socket_name is active (has connections)"
        
        # Fix permissions if needed - ensure group has read/write access
        current_perms=$(stat -c "%a" "$socket_file" 2>/dev/null)
        if [ -n "$current_perms" ]; then
            # Check if group has read and write permissions (check for 6 or 7 in group position)
            group_perms=${current_perms:1:1}
            if [ "$group_perms" -lt 6 ]; then
                log_message "Fixing permissions for $socket_name (current: $current_perms)"
                if chmod g+rw "$socket_file" 2>/dev/null; then
                    permission_fixes=$((permission_fixes + 1))
                    log_message "Successfully fixed permissions for $socket_name"
                else
                    log_message "WARNING: Failed to fix permissions for $socket_name"
                fi
            fi
        fi
        
        # Ensure the socket has the correct group
        current_group=$(stat -c "%G" "$socket_file" 2>/dev/null)
        if [ "$current_group" != "$TUNNEL_GROUP" ]; then
            log_message "Fixing group ownership for $socket_name (current: $current_group)"
            if chgrp "$TUNNEL_GROUP" "$socket_file" 2>/dev/null; then
                log_message "Successfully fixed group ownership for $socket_name"
            else
                log_message "WARNING: Failed to fix group ownership for $socket_name"
            fi
        fi
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

log_message "Cleanup completed. Removed $removed_count inactive socket(s), fixed permissions on $permission_fixes socket(s)"

exit 0
