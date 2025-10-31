# WebQuiz Tunnel Server

This repository contains Ansible configuration for setting up a WebQuiz tunnel server with nginx reverse proxy, Let's Encrypt SSL, and SSH tunnel support.

## Features

- **Nginx Reverse Proxy**: Proxies WebSocket and HTTP requests to Unix domain sockets
- **Let's Encrypt SSL**: Automated HTTPS certificate management
- **SSH Tunnel Support**: Dedicated user for creating secure SSH tunnels
- **High Performance**: Optimized system limits and timeouts for production workloads
- **Automated Deployment**: GitHub Actions workflow for ansible-pull deployment

## Architecture

The server acts as a reverse proxy that routes requests from `/wsaio/{socket_name}/path/` to Unix domain sockets at `/var/run/tunnels/{socket_name}.sock`.

### Request Flow

```
Client Request → Nginx (HTTPS) → Unix Socket → Application
https://server.com/wsaio/myapp/api/data → /var/run/tunnels/myapp.sock
```

## Quick Start

### Prerequisites

- Ubuntu/Debian server with SSH access
- Domain name (webquiz.xyz) pointing to the server (for Let's Encrypt)
- GitHub repository secrets configured

### Setup GitHub Secrets

Configure the following secrets in your GitHub repository (Settings → Secrets and variables → Actions):

- `SERVER_HOST`: Your server's hostname or IP address (e.g., webquiz.xyz)
- `SERVER_USER`: SSH user with sudo privileges (e.g., `ubuntu`, `root`)
- `SERVER_SSH_KEY`: Private SSH key for server access
- `SERVER_PORT`: (Optional) SSH port, defaults to 22

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

### Adding SSH Keys for Tunnel Access

1. Add public SSH keys to `ansible/files/ssh_keys/`
2. Name files descriptively (e.g., `username.pub`)
3. Commit and push changes
4. The deployment will automatically authorize these keys for the `tunneluser`

### SSL Certificate Setup

After initial deployment, obtain Let's Encrypt certificate:

```bash
sudo certbot --nginx -d webquiz.xyz
```

Certbot will automatically:
- Obtain SSL certificate
- Configure nginx for HTTPS
- Set up automatic renewal

### Creating Tunnels

Users with authorized SSH keys can create tunnels. **Multiple tunnels are supported** - each tunnel uses a unique socket name:

```bash
# Create first tunnel: myapp
ssh -N -R /var/run/tunnels/myapp:localhost:8080 tunneluser@webquiz.xyz

# Create second tunnel: api (in another terminal/session)
ssh -N -R /var/run/tunnels/api:localhost:3000 tunneluser@webquiz.xyz

# Create third tunnel: frontend (in another terminal/session)
ssh -N -R /var/run/tunnels/frontend:localhost:5000 tunneluser@webquiz.xyz

# Or using autossh for automatic reconnection
autossh -M 0 -N -R /var/run/tunnels/myapp:localhost:8080 tunneluser@webquiz.xyz \
  -o "ServerAliveInterval=60" -o "ServerAliveCountMax=3"
```

Each application will be accessible at its own URL path:
```
https://webquiz.xyz/wsaio/myapp/     → localhost:8080
https://webquiz.xyz/wsaio/api/       → localhost:3000
https://webquiz.xyz/wsaio/frontend/  → localhost:5000
```

### Server Configuration Information

The server provides a static configuration file at `/tunnel_config.yaml` with connection details:

```bash
# Access the configuration (use http:// if SSL is not configured yet)
curl http://webquiz.xyz/tunnel_config.yaml
# Or via HTTPS if SSL certificate is configured
curl https://webquiz.xyz/tunnel_config.yaml
```

Example output:
```yaml
username: tunneluser
socket_directory: /var/run/tunnels
base_url: https://webquiz.xyz/wsaio/
http_url: http://webquiz.xyz/wsaio/
https_url: https://webquiz.xyz/wsaio/
```

This file contains:
- SSH username for tunnel connections
- Socket directory path
- Base URL for accessing tunnels (HTTP by default, use HTTPS after SSL setup)
- HTTP URL for non-SSL access (works with IP addresses)
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

**Security Restrictions for Tunnel User:**
- **No Interactive Shell**: PermitTTY disabled
- **Tunneling Only**: AllowTcpForwarding set to remote only
- **No Command Execution**: ForceCommand /bin/false
- **No X11/Agent Forwarding**: Disabled for security

The `tunneluser` account is restricted to SSH tunnel operations only and cannot:
- Log in with an interactive shell
- Execute commands directly
- Forward X11 or SSH agent
- **TCPKeepAlive**: Enabled

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
│       └── deploy.yml          # GitHub Actions deployment workflow
├── ansible/
│   ├── files/
│   │   ├── scripts/            # Maintenance scripts
│   │   │   └── cleanup-sockets.sh  # Socket cleanup cron script
│   │   └── ssh_keys/           # SSH public keys for tunnel users
│   │       ├── README.md
│   │       └── *.pub           # Public key files
│   ├── templates/
│   │   ├── nginx-tunnel-proxy.conf.j2  # Nginx configuration template
│   │   └── tunnel_config.yaml.j2       # Tunnel configuration YAML
│   └── playbook.yml            # Main Ansible playbook
└── README.md                   # This file
```

## Automated Maintenance

### Socket Cleanup

A cron job runs every 5 minutes to check and remove inactive socket files:

- **Script**: `/usr/local/bin/cleanup-sockets.sh`
- **Schedule**: Every 5 minutes (`*/5 * * * *`)
- **Log**: `/var/log/tunnel-cleanup.log`

The script uses `lsof` to detect sockets without active SSH connections and removes them automatically. This prevents stale socket files from accumulating when tunnels disconnect unexpectedly.

## Security Considerations

1. **SSH Key Management**: Only add keys for trusted users
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
curl http://localhost/wsaio/myapp/health
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
