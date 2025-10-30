# WebQuiz Tunnel Server Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client Machine                          │
│                                                                 │
│  ┌──────────────────┐         SSH Tunnel (Remote Forward)      │
│  │  Web Application │         ssh -R socket:localhost:port     │
│  │  (localhost:8080)│                                           │
│  └─────────┬────────┘                                           │
│            │                                                     │
│            ▼                                                     │
│  ┌──────────────────┐                                           │
│  │  SSH Client      │───────────────────────────────────────────┼─┐
│  │  (autossh)       │                                           │ │
│  └──────────────────┘                                           │ │
└─────────────────────────────────────────────────────────────────┘ │
                                                                     │
                        SSH Connection (Port 22)                    │
                        with Keepalive (60s)                        │
                                                                     │
┌─────────────────────────────────────────────────────────────────┐ │
│                         Tunnel Server                           │ │
│                                                                 │ │
│  ┌──────────────────────────────────────────────────────────┐  │ │
│  │                    SSH Server (sshd)                     │  │ │
│  │  • User: tunneluser                                      │◄─┼─┘
│  │  • Auth: SSH keys only                                   │  │
│  │  • ClientAliveInterval: 60s                              │  │
│  │  • MaxSessions: 100                                      │  │
│  └───────────────────────┬──────────────────────────────────┘  │
│                          │ Creates Unix Socket                  │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         Socket Directory: /var/run/tunnels/              │  │
│  │                                                           │  │
│  │  • myapp.sock  ◄─── tunneluser creates sockets here     │  │
│  │  • test.sock                                             │  │
│  │  • api.sock                                              │  │
│  │                                                           │  │
│  │  Permissions: tunneluser:tunneluser (755)                │  │
│  └───────────────────────┬──────────────────────────────────┘  │
│                          │ Nginx reads from sockets             │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Nginx Web Server                      │  │
│  │                                                           │  │
│  │  URL Pattern Matching:                                   │  │
│  │  /wsaio/{socket_name}/path → unix socket proxy          │  │
│  │                                                           │  │
│  │  Example:                                                │  │
│  │  /wsaio/myapp/api/users                                  │  │
│  │      ↓                                                    │  │
│  │  unix:/var/run/tunnels/myapp.sock:/api/users            │  │
│  │                                                           │  │
│  │  • WebSocket Support: ✓                                  │  │
│  │  • Timeout: 3600s (1 hour)                               │  │
│  │  • HTTPS with Let's Encrypt                              │  │
│  └───────────────────────┬──────────────────────────────────┘  │
│                          │                                      │
└──────────────────────────┼──────────────────────────────────────┘
                           │
                   HTTPS (Port 443)
                   HTTP (Port 80)
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Internet Users                           │
│                                                                 │
│  Browser → https://webquiz.space/wsaio/myapp/api/users         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Request Flow

### 1. Client Creates Tunnel

```bash
ssh -N -R /var/run/tunnels/myapp.sock:localhost:8080 tunneluser@webquiz.space
```

- SSH client authenticates using authorized public key
- Remote forward creates Unix socket: `/var/run/tunnels/myapp.sock`
- Socket owned by `tunneluser`
- Connection kept alive with TCP keepalive

### 2. User Makes Request

```
GET https://webquiz.space/wsaio/myapp/api/users
```

### 3. Nginx Processing

1. **SSL Termination**: HTTPS request decrypted
2. **Pattern Matching**: `/wsaio/myapp/` matches nginx location block
3. **Socket Extraction**: Extracts `myapp` as socket name
4. **Proxy Pass**: Forwards to `unix:/var/run/tunnels/myapp.sock:/api/users`
5. **Headers Added**: X-Real-IP, X-Forwarded-For, etc.

### 4. Socket Communication

1. Nginx connects to Unix socket
2. Request forwarded through SSH tunnel
3. Reaches application on client machine (localhost:8080)
4. Application processes request
5. Response flows back through tunnel

### 5. Response Delivery

1. Application responds to socket
2. Through SSH tunnel to server
3. Nginx receives response
4. SSL encryption applied
5. Response sent to user's browser

## WebSocket Flow

For WebSocket connections:

```
User → HTTPS Upgrade Request → Nginx → Unix Socket → SSH Tunnel → Client App
User ← Persistent Connection ← Nginx ← Unix Socket ← SSH Tunnel ← Client App
```

- Connection upgrade headers handled by nginx
- Buffering disabled for real-time communication
- 1-hour timeout for long-lived connections
- TCP keepalive maintains connection

## Security Layers

```
┌─────────────────────────────────────┐
│     SSL/TLS (Let's Encrypt)         │  ← HTTPS encryption
├─────────────────────────────────────┤
│     Nginx Reverse Proxy             │  ← Request filtering
├─────────────────────────────────────┤
│     Unix Socket (Local only)        │  ← No network exposure
├─────────────────────────────────────┤
│     SSH Tunnel (Encrypted)          │  ← Encrypted transport
├─────────────────────────────────────┤
│     SSH Key Authentication          │  ← No password auth
└─────────────────────────────────────┘
```

## File System Layout

```
/var/run/tunnels/          # Socket directory
├── myapp.sock             # Application sockets
├── test.sock
└── api.sock

/etc/nginx/
├── sites-available/
│   └── tunnel-proxy       # Nginx configuration
└── sites-enabled/
    └── tunnel-proxy → ../sites-available/tunnel-proxy

/home/tunneluser/
└── .ssh/
    └── authorized_keys    # Authorized SSH keys

/etc/ssh/
└── sshd_config            # SSH server configuration
```

## Network Ports

- **22**: SSH (tunnel connections)
- **80**: HTTP (Let's Encrypt challenges, redirects to HTTPS)
- **443**: HTTPS (main application traffic)

## Performance Characteristics

| Metric | Value |
|--------|-------|
| Max concurrent tunnels | 100 (MaxSessions) |
| Max file descriptors | 65,536 per user |
| WebSocket timeout | 3600s (1 hour) |
| SSH keepalive interval | 60s |
| TCP keepalive time | 600s |
| Connection queue | 4,096 |

## Deployment Flow

```
GitHub Push → GitHub Actions → SSH to Server → ansible-pull → Configure Server
     │              │                │               │              │
     └──────────────┴────────────────┴───────────────┴──────────────┘
                    Automated Deployment Pipeline
```

## High Availability Considerations

For production at scale:

```
        ┌─────────────┐
        │ Load        │
        │ Balancer    │
        └──────┬──────┘
               │
       ┌───────┴───────┐
       ▼               ▼
┌──────────┐    ┌──────────┐
│ Tunnel   │    │ Tunnel   │
│ Server 1 │    │ Server 2 │
└──────────┘    └──────────┘
```

- Multiple tunnel servers behind load balancer
- Shared configuration via Ansible
- Health checks on `/health` endpoint
- Session affinity for WebSocket connections

## Monitoring Points

1. **SSH Connections**: `ss -lx | grep tunnels`
2. **Nginx Status**: `systemctl status nginx`
3. **Active Sockets**: `ls -la /var/run/tunnels/`
4. **System Limits**: `ulimit -n`, `cat /proc/sys/fs/file-max`
5. **Network Stats**: `netstat -s`, `ss -s`

## Troubleshooting Flow

```
Issue Reported
     │
     ▼
Check Nginx Logs (/var/log/nginx/)
     │
     ├─ OK → Check Socket Exists (ls /var/run/tunnels/)
     │        │
     │        ├─ OK → Check SSH Connection (ss -lx)
     │        │        │
     │        │        └─ Check Client Application
     │        │
     │        └─ Missing → Check SSH Tunnel Creation
     │
     └─ Errors → Check Nginx Config (nginx -t)
```
