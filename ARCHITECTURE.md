# WebQuiz Tunnel Server Architecture

## Multi-User Architecture Overview

The system now supports two modes:

### Multi-User Mode (Recommended)
- Each user folder creates a dedicated SSH user and subdomain
- Isolated socket directories per user
- Separate SSL certificates per subdomain
- URL pattern: `https://{username}.{domain}/start/{socket}/`

### Legacy Mode (Backward Compatible)
- Single shared `tunneluser` account
- Shared socket directory
- Single SSL certificate for root domain
- URL pattern: `https://{domain}/start/{socket}/`

## Multi-User System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Client Machine (Alice)                       │
│                                                                 │
│  ┌──────────────────┐         SSH Tunnel (Remote Forward)      │
│  │  Web Application │         ssh -R socket:localhost:port     │
│  │  (localhost:8080)│         as alice@webquiz.xyz            │
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
│  │  • Users: alice, bob, charlie, tunneluser (legacy)      │◄─┼─┘
│  │  • Auth: SSH keys only (per-user)                       │  │
│  │  • ClientAliveInterval: 60s                              │  │
│  │  • MaxSessions: 100                                      │  │
│  └───────────────────────┬──────────────────────────────────┘  │
│                          │ Creates Unix Socket                  │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │      Socket Directories: /var/run/tunnels/               │  │
│  │                                                           │  │
│  │  alice/                                                   │  │
│  │  ├── myapp    ◄─── alice creates sockets here           │  │
│  │  └── api                                                  │  │
│  │  bob/                                                     │  │
│  │  ├── webapp   ◄─── bob creates sockets here             │  │
│  │  └── test                                                 │  │
│  │  [legacy single files for backward compat]               │  │
│  │                                                           │  │
│  │  Permissions: user:user (660), www-data in user groups   │  │
│  └───────────────────────┬──────────────────────────────────┘  │
│                          │ Nginx reads from sockets             │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Nginx Web Server                      │  │
│  │                                                           │  │
│  │  Subdomain Routing:                                      │  │
│  │  alice.webquiz.xyz/start/{socket} → alice's sockets     │  │
│  │  bob.webquiz.xyz/start/{socket}   → bob's sockets       │  │
│  │  webquiz.xyz/start/{socket}       → legacy sockets      │  │
│  │                                                           │  │
│  │  Examples:                                               │  │
│  │  alice.webquiz.xyz/start/myapp/api                      │  │
│  │      ↓                                                    │  │
│  │  unix:/var/run/tunnels/alice/myapp:/api                 │  │
│  │                                                           │  │
│  │  • WebSocket Support: ✓                                  │  │
│  │  • Timeout: 3600s (1 hour)                               │  │
│  │  • HTTPS with Let's Encrypt (per subdomain)             │  │
│  │  • Static index.html on root domain                      │  │
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
│  Browser → https://alice.webquiz.xyz/start/myapp/api/users    │
│  Browser → https://bob.webquiz.xyz/start/webapp/              │
│  Browser → https://webquiz.xyz/  (static homepage)            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Legacy System Architecture Diagram

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
│  │  /start/{socket_name}/path → unix socket proxy          │  │
│  │                                                           │  │
│  │  Example:                                                │  │
│  │  /start/myapp/api/users                                  │  │
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
│  Browser → https://webquiz.xyz/start/myapp/api/users         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Request Flow

### Multi-User Request Flow

#### 1. Client Creates Tunnel (Alice)

```bash
ssh -N -R /var/run/tunnels/alice/myapp:localhost:8080 alice@webquiz.xyz
```

- SSH client authenticates using Alice's authorized public key
- Remote forward creates Unix socket: `/var/run/tunnels/alice/myapp`
- Socket owned by `alice:alice` (group readable by www-data)
- Connection kept alive with TCP keepalive

#### 2. User Makes Request

```
GET https://alice.webquiz.xyz/start/myapp/api/users
```

#### 3. Nginx Processing

1. **Subdomain Matching**: `alice.webquiz.xyz` routes to Alice's nginx config
2. **SSL Termination**: HTTPS request decrypted (Alice's certificate)
3. **Pattern Matching**: `/start/myapp/` matches nginx location block
4. **Socket Extraction**: Extracts `myapp` as socket name
5. **Proxy Pass**: Forwards to `unix:/var/run/tunnels/alice/myapp:/api/users`
6. **Headers Added**: X-Real-IP, X-Forwarded-For, etc.

#### 4. Socket Communication

1. Nginx connects to Unix socket in Alice's directory
2. Request forwarded through SSH tunnel
3. Reaches Alice's application (localhost:8080)
4. Application processes request
5. Response flows back through tunnel

#### 5. Response Delivery

1. Application responds to socket
2. Through SSH tunnel to server
3. Nginx receives response
4. SSL encryption applied (Alice's certificate)
5. Response sent to user's browser

### Legacy Request Flow

#### 1. Client Creates Tunnel (Legacy)

```bash
ssh -N -R /var/run/tunnels/myapp:localhost:8080 tunneluser@webquiz.xyz
```

- SSH client authenticates using authorized public key
- Remote forward creates Unix socket: `/var/run/tunnels/myapp`
- Socket owned by `tunneluser`
- Connection kept alive with TCP keepalive

#### 2. User Makes Request

```
GET https://webquiz.xyz/start/myapp/api/users
```

#### 3. Nginx Processing

1. **SSL Termination**: HTTPS request decrypted
2. **Pattern Matching**: `/start/myapp/` matches nginx location block
3. **Socket Extraction**: Extracts `myapp` as socket name
4. **Proxy Pass**: Forwards to `unix:/var/run/tunnels/myapp:/api/users`
5. **Headers Added**: X-Real-IP, X-Forwarded-For, etc.

#### 4. Socket Communication (Legacy)

1. Nginx connects to Unix socket
2. Request forwarded through SSH tunnel
3. Reaches application on client machine (localhost:8080)
4. Application processes request
5. Response flows back through tunnel

#### 5. Response Delivery (Legacy)

1. Application responds to socket
2. Through SSH tunnel to server
3. Nginx receives response
4. SSL encryption applied
5. Response sent to user's browser

## WebSocket Flow

For WebSocket connections (both multi-user and legacy):

```
User → HTTPS Upgrade Request → Nginx → Unix Socket → SSH Tunnel → Client App
User ← Persistent Connection ← Nginx ← Unix Socket ← SSH Tunnel ← Client App
```

- Connection upgrade headers handled by nginx
- Buffering disabled for real-time communication
- 1-hour timeout for long-lived connections
- TCP keepalive maintains connection

## Security Layers

### Multi-User Security Model

```
┌─────────────────────────────────────┐
│ SSL/TLS per Subdomain (Let's Encrypt)│ ← Per-user HTTPS encryption
├─────────────────────────────────────┤
│ Subdomain Isolation                  │ ← User separation at DNS level
├─────────────────────────────────────┤
│ Nginx Reverse Proxy                  │ ← Request filtering per subdomain
├─────────────────────────────────────┤
│ User-Specific Socket Directory       │ ← File system isolation
├─────────────────────────────────────┤
│ Unix Socket (Local only)             │ ← No network exposure
├─────────────────────────────────────┤
│ SSH Tunnel (Encrypted)               │ ← Encrypted transport
├─────────────────────────────────────┤
│ Per-User SSH Key Authentication      │ ← Individual user auth
└─────────────────────────────────────┘
```

### Legacy Security Model

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

### Multi-User Layout

```
/var/run/tunnels/              # Root socket directory
├── alice/                     # Alice's socket directory
│   ├── myapp                  # Alice's app socket
│   └── api                    # Alice's API socket
├── bob/                       # Bob's socket directory
│   └── webapp                 # Bob's webapp socket
└── [legacy single sockets]    # Backward compatibility

/home/alice/.ssh/
└── authorized_keys            # Alice's SSH keys

/home/bob/.ssh/
└── authorized_keys            # Bob's SSH keys

/etc/nginx/sites-available/
├── tunnel-proxy               # Root domain config
├── alice-subdomain            # Alice's subdomain config
└── bob-subdomain              # Bob's subdomain config

/etc/letsencrypt/live/
├── webquiz.xyz/               # Root domain certificate
├── alice.webquiz.xyz/         # Alice's certificate
└── bob.webquiz.xyz/           # Bob's certificate

/var/www/html/
├── index.html                 # Root domain static page
├── alice/
│   └── tunnel_config.yaml     # Alice's config
└── bob/
    └── tunnel_config.yaml     # Bob's config
```

### Legacy Layout

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
