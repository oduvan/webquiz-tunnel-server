# WebQuiz Tunnel Server

This repository contains Ansible configuration for setting up a WebQuiz tunnel server with nginx reverse proxy, Let's Encrypt SSL, and SSH tunnel support.

## Features

- **Multi-User Subdomains**: Each user gets their own subdomain with isolated socket directory
- **Custom Domain Proxying**: Support for custom domains that proxy to HTTP backends (NEW)
- **Nginx Reverse Proxy**: Proxies WebSocket and HTTP requests to Unix domain sockets or HTTP backends
- **Let's Encrypt SSL**: Automated HTTPS certificate management per subdomain and custom domain
- **SSH Tunnel Support**: Dedicated SSH users for creating secure SSH tunnels
- **High Performance**: Optimized system limits and timeouts for production workloads
- **Automated Deployment**: GitHub Actions workflow for ansible-pull deployment
- **Backward Compatible**: Legacy single-user mode still supported

## Architecture

The server supports three modes:

### Multi-User Mode (Recommended)

Each user folder in `ansible/files/users/{username}/` creates:
- SSH user: `{username}`
- Subdomain: `{username}.webquiz.xyz`
- Socket directory: `/var/run/tunnels/{username}/`
- SSL certificate for the subdomain

```
Client Request → Nginx (HTTPS) → Unix Socket → Application
https://alice.webquiz.xyz/start/myapp/api/data → /var/run/tunnels/alice/myapp
```

### Legacy Mode (Backward Compatible)

Single `tunneluser` with shared socket directory at `/var/run/tunnels/`.

```
Client Request → Nginx (HTTPS) → Unix Socket → Application
https://webquiz.xyz/start/myapp/api/data → /var/run/tunnels/myapp
```

### Custom Domain Mode (NEW)

Proxy entire custom domains to HTTP backends (e.g., for proxying to local devices or services).

```
Client Request → Nginx (HTTPS) → HTTP Backend
https://example.com/ → http://backend-host:backend-port
```

Each custom domain configuration in `ansible/files/custom_domains/{domain}.yml` creates:
- Full domain nginx configuration
- SSL certificate for the domain
- Reverse proxy to specified backend host:port

## Quick Start

### Prerequisites

- Ubuntu/Debian server with SSH access
- Domain name (webquiz.xyz) pointing to the server (for Let's Encrypt)
- GitHub repository secrets configured

### Setup GitHub Secrets

Configure the following secrets in your GitHub repository (Settings → Secrets and variables → Actions):

**Server Access (Required):**
- `SERVER_HOST`: Your server's hostname or IP address (e.g., webquiz.xyz)
- `SERVER_USER`: SSH user with sudo privileges (e.g., `ubuntu`, `root`)
- `SERVER_SSH_KEY`: Private SSH key for server access
- `SERVER_PORT`: (Optional) SSH port, defaults to 22

**Custom Domain Backends (Optional):**
- Add secrets for each custom domain backend as referenced in your domain configuration files
- Example: `JETSON_HOST`, `JETSON_HTTP_PORT` for cvitanok.lyabah.com

### Initial Deployment

1. Push changes to the `main` branch or trigger the workflow manually
2. The GitHub Action will execute ansible-pull on your remote server
3. The playbook will configure nginx, SSH, system limits, and create the tunnel user

### Manual Deployment

You can also run ansible-pull directly on the server:

```bash
sudo ansible-pull \
  -U https://github.com/oduvan/webquiz-tunnel-server.git \
  -i localhost, \
  ansible/playbook.yml
```

## Configuration

### Multi-User Setup (Recommended)

Add users by creating directories in `ansible/files/users/`:

```bash
# Create a new user 'alice'
mkdir ansible/files/users/alice

# Add SSH public keys for alice
cp alice-laptop.pub ansible/files/users/alice/
cp alice-desktop.pub ansible/files/users/alice/

# Commit and push
git add ansible/files/users/alice/
git commit -m "Add user alice"
git push
```

After deployment:
- User `alice` can SSH to create tunnels
- Subdomain `alice.webquiz.xyz` is configured
- SSL certificate for `alice.webquiz.xyz` is obtained
- Socket directory `/var/run/tunnels/alice/` is created

**Important**: Subdomain DNS records (wildcards or individual A records) must point to your server.

### Creating Tunnels (Multi-User)

Users create tunnels to their own subdomain:

```bash
# Alice creates a tunnel for her app
ssh -N -R /var/run/tunnels/alice/myapp:localhost:8080 alice@webquiz.xyz

# Access at: https://alice.webquiz.xyz/start/myapp/

# Bob creates a tunnel for his app
ssh -N -R /var/run/tunnels/bob/api:localhost:3000 bob@webquiz.xyz

# Access at: https://bob.webquiz.xyz/start/api/
```

### Custom Domain Setup (NEW)

Add custom domains that proxy to HTTP backends by creating configuration files in `ansible/files/custom_domains/`:

```bash
# Create a configuration for cvitanok.lyabah.com
cat > ansible/files/custom_domains/cvitanok.lyabah.com.yml <<EOF
domain: cvitanok.lyabah.com
backend_host_secret: JETSON_HOST
backend_port_secret: JETSON_HTTP_PORT
EOF

# Commit and push
git add ansible/files/custom_domains/cvitanok.lyabah.com.yml
git commit -m "Add custom domain cvitanok.lyabah.com"
git push
```

**Configure GitHub Secrets:**

Add the backend host and port secrets referenced in your configuration:
- `JETSON_HOST`: Backend server IP or hostname (e.g., `192.168.1.100`)
- `JETSON_HTTP_PORT`: Backend server port (e.g., `8080`)

After deployment:
- Domain `cvitanok.lyabah.com` is configured in nginx
- SSL certificate for `cvitanok.lyabah.com` is obtained
- All requests to `https://cvitanok.lyabah.com/` are proxied to `http://JETSON_HOST:JETSON_HTTP_PORT/`

**Important**: The domain DNS A record must point to your server's IP address.

### Legacy Single-User Setup

Add public SSH keys to `ansible/files/ssh_keys/`:

```bash
cp username.pub ansible/files/ssh_keys/
git add ansible/files/ssh_keys/username.pub
git commit -m "Add SSH key for username"
git push
```

The deployment will authorize these keys for the `tunneluser`.

### Creating Tunnels (Legacy Mode)

```bash
# Create tunnel
ssh -N -R /var/run/tunnels/myapp:localhost:8080 tunneluser@webquiz.xyz

# Access at: https://webquiz.xyz/start/myapp/
```

### SSL Certificate Setup

The deployment automatically obtains Let's Encrypt certificates:

**For Multi-User Setup:**
- Root domain certificate: `webquiz.xyz`
- User subdomain certificates: `alice.webquiz.xyz`, `bob.webquiz.xyz`, etc.

**For Legacy Setup:**
- Single certificate for `webquiz.xyz`

**Certificate Process:**
1. **Initial Deployment**: Nginx is deployed with HTTP server blocks
2. **Certificate Acquisition**: Certbot automatically obtains SSL certificates
3. **HTTPS Configuration**: Nginx is reconfigured with HTTPS support
4. **Automatic Renewal**: Certbot sets up automatic renewal via cron

Manual certificate acquisition (if needed):

```bash
# Root domain
sudo certbot --nginx -d webquiz.xyz

# User subdomain
sudo certbot --nginx -d alice.webquiz.xyz
```

**Prerequisites**: 
- The domain `webquiz.xyz` and all subdomains point to your server's IP
- For multi-user: Use wildcard DNS (*.webquiz.xyz) or individual A records
- Port 80 is accessible (required for Let's Encrypt validation)
- Port 443 is accessible (required for HTTPS)

**Certificate Renewal**: Certbot automatically renews certificates via cron. No manual intervention needed.

### Server Configuration Information

Configuration files provide connection details:

**Multi-User:**
```bash
# User-specific configuration
curl https://alice.webquiz.xyz/tunnel_config.yaml
```

Example output:
```yaml
username: alice
socket_directory: /var/run/tunnels/alice
base_url: https://alice.webquiz.xyz/start/
subdomain: alice.webquiz.xyz
```

**Legacy:**
```bash
# Legacy configuration
curl https://webquiz.xyz/tunnel_config.yaml
```

Example output:
```yaml
username: tunneluser
socket_directory: /var/run/tunnels
base_url: https://webquiz.xyz/start/
```
- HTTPS URL for SSL access (requires domain name and SSL certificate)

## Server Configuration

### Nginx Configuration

- **Proxy Timeout**: 300 seconds (5 minutes)
- **WebSocket Timeout**: 3600 seconds (1 hour)
- **WebSocket Support**: Full upgrade header handling
- **Buffering**: Disabled for real-time communication

### SSH Configuration

- **ClientAliveInterval**: 60 seconds
- **ClientAliveCountMax**: 10 attempts
- **MaxSessions**: 100 concurrent sessions
- **TCPKeepAlive**: Enabled

**Security Restrictions for Tunnel Users:**
- **No Interactive Shell**: PermitTTY disabled
- **Tunneling Only**: AllowTcpForwarding set to remote only
- **No Command Execution**: ForceCommand /bin/false
- **No X11/Agent Forwarding**: Disabled for security

All tunnel user accounts (both multi-user and legacy) are restricted to SSH tunnel operations only and cannot:
- Log in with an interactive shell
- Execute commands directly
- Forward X11 or SSH agent

### System Limits

- **File Descriptors**: 65,536 per user
- **Process Limit**: 4,096 per user
- **Global File Max**: 2,097,152
- **Network Connection Queue**: 4,096

### Kernel Parameters

Optimized for high-concurrency network operations:
- TCP keepalive settings for long-lived connections
- Increased socket backlog and connection tracking
- TCP port range optimization

## Directory Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml                    # GitHub Actions deployment
├── ansible/
│   ├── files/
│   │   ├── scripts/
│   │   │   └── cleanup-sockets.sh        # Socket cleanup script
│   │   ├── ssh_keys/                     # Legacy SSH keys
│   │   │   ├── README.md
│   │   │   └── *.pub
│   │   ├── users/                        # Multi-user configs
│   │   │   ├── README.md
│   │   │   ├── alice/                    # User 'alice'
│   │   │   │   └── *.pub                 # Alice's SSH keys
│   │   │   └── bob/                      # User 'bob'
│   │   │       └── *.pub                 # Bob's SSH keys
│   │   └── custom_domains/               # Custom domain configs (NEW)
│   │       ├── README.md
│   │       └── *.yml                     # Domain config files
│   ├── templates/
│   │   ├── nginx-root-domain.conf.j2     # Root domain nginx config
│   │   ├── nginx-user-subdomain.conf.j2  # User subdomain config
│   │   ├── nginx-custom-domain.conf.j2   # Custom domain config (NEW)
│   │   ├── nginx-tunnel-proxy.conf.j2    # Legacy nginx config
│   │   ├── tunnel_config.yaml.j2         # Legacy tunnel config
│   │   └── user_tunnel_config.yaml.j2    # User tunnel config
│   └── playbook.yml                      # Main Ansible playbook
└── README.md                             # This file
```

## Automated Maintenance

### Socket Cleanup

A cron job runs every 5 minutes to check and remove inactive socket files:

- **Script**: `/usr/local/bin/cleanup-sockets.sh`
- **Schedule**: Every 5 minutes (`*/5 * * * *`)
- **Log**: `/var/log/tunnel-cleanup.log`
- **Scope**: Cleans both legacy and user-specific socket directories

The script uses `lsof` to detect sockets without active SSH connections and removes them automatically. This prevents stale socket files from accumulating when tunnels disconnect unexpectedly.

## Security Considerations

1. **Multi-User Isolation**: Each user has their own subdomain and socket directory
2. **SSH Key Management**: Only add keys/users for trusted individuals
2. **Firewall**: Ensure only necessary ports (22, 80, 443) are open
3. **Regular Updates**: Keep system packages and SSL certificates up to date
4. **Monitoring**: Monitor socket directory and active connections
5. **Log Review**: Regularly review nginx and SSH logs

## Troubleshooting

### Check Nginx Status

```bash
sudo systemctl status nginx
sudo nginx -t  # Test configuration
```

### Check Active Tunnels

```bash
# List active SSH tunnels
sudo ss -lx | grep tunnels

# List socket files
ls -la /var/run/tunnels/
```

### View Logs

```bash
# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log

# SSH authentication logs
sudo tail -f /var/log/auth.log
```

### Test Proxy Connection

```bash
# Test if nginx can connect to a socket
curl http://localhost/start/myapp/health
```

## Maintenance

### Update Configuration

1. Modify Ansible playbook or templates
2. Commit and push changes
3. Deployment happens automatically via GitHub Actions

### Renew SSL Certificate

Certbot automatically renews certificates. To manually renew:

```bash
sudo certbot renew
```

### Update System Packages

```bash
sudo apt-get update
sudo apt-get upgrade
```

## Contributing

When adding new features or modifying configuration:

1. Test changes in a development environment
2. Update documentation
3. Create a pull request with description of changes

## License

[Specify your license here]

## Support

For issues or questions, please open an issue in this repository
