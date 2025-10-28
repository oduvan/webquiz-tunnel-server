# Ansible Configuration Documentation

This directory contains the Ansible playbook and configuration for setting up the WebQuiz Tunnel Server.

## Overview

The playbook configures a server to act as a reverse proxy for SSH tunnels, routing HTTP/WebSocket traffic from nginx to Unix domain sockets created by SSH tunnels.

## Directory Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── playbook.yml             # Main playbook
├── files/
│   ├── scripts/             # Maintenance scripts
│   │   └── cleanup-sockets.sh   # Socket cleanup script
│   └── ssh_keys/            # SSH public keys for tunnel users
│       ├── README.md
│       └── *.pub            # Individual public key files
├── templates/
│   ├── nginx-tunnel-proxy.conf.j2  # Nginx configuration template
│   └── tunnel_config.yaml.j2       # Tunnel configuration YAML template
├── roles/                   # (Empty, for future role-based organization)
├── group_vars/              # (Empty, for group-specific variables)
└── host_vars/               # (Empty, for host-specific variables)
```

## Templates vs Static Files

The nginx configuration uses a **Jinja2 template** (`nginx-tunnel-proxy.conf.j2`) instead of a static file to:

1. **Inject Ansible variables**: 
   - `{{ tunnel_socket_dir }}` - dynamically sets the socket directory path
   - `{{ nginx_proxy_timeout }}` - configurable timeout values
   - `{{ nginx_websocket_timeout }}` - customizable WebSocket timeouts

2. **Enable environment-specific configuration**: Different deployments can override variables without modifying the template

3. **Maintain consistency**: Variables defined once in `playbook.yml` are used throughout the configuration

The template approach allows the same playbook to work across different environments by simply changing variable values.

## Multiple Tunnels Support

The nginx configuration supports **unlimited concurrent tunnels** using a regex-based location block:

```nginx
location ~ ^/wsaio/([^/]+)/(.*)$ {
    set $socket_name $1;
    proxy_pass http://unix:/var/run/tunnels/$socket_name.sock:/$2;
}
```

This pattern dynamically routes requests:
- `/wsaio/app1/api/data` → `/var/run/tunnels/app1.sock`
- `/wsaio/app2/health` → `/var/run/tunnels/app2.sock`
- `/wsaio/service3/ws` → `/var/run/tunnels/service3.sock`

No nginx reconfiguration is needed when adding new tunnels.

## Playbook Details

### Variables

The playbook uses the following variables (defined in `playbook.yml`):

- `tunnel_user`: Username for tunnel connections (default: `tunneluser`)
- `tunnel_group`: Group for tunnel user (default: `tunneluser`)
- `tunnel_socket_dir`: Directory for Unix sockets (default: `/var/run/tunnels`)
- `ssh_keys_dir`: Directory containing SSH public keys
- `nginx_proxy_timeout`: Timeout for proxy connections in seconds (default: 300)
- `nginx_websocket_timeout`: Timeout for WebSocket connections in seconds (default: 3600)

### Tasks Overview

1. **System Package Installation**
   - Updates apt cache
   - Installs nginx, certbot, python3-certbot-nginx, openssh-server

2. **User Management**
   - Creates dedicated `tunneluser` account
   - Sets up home directory and shell

3. **Socket Directory Setup**
   - Creates `/var/run/tunnels` directory
   - Sets appropriate ownership and permissions

4. **SSH Key Authorization**
   - Scans `files/ssh_keys/` for `.pub` files
   - Adds all public keys to `tunneluser`'s `authorized_keys`

5. **SSH Configuration**
   - Configures ClientAliveInterval and ClientAliveCountMax
   - Increases MaxSessions and MaxStartups
   - Enables TCP keepalive
   - Restricts tunnel user to tunneling only (no shell, no command execution)

6. **System Limits**
   - Increases file descriptor limits (65,536)
   - Increases process limits (4,096)
   - Applies to both `tunneluser` and globally

7. **Kernel Parameters**
   - Optimizes network stack for high concurrency
   - Configures TCP keepalive and connection tracking
   - Increases socket queue sizes

8. **Tunnel Configuration File**
   - Creates `/var/www/html/tunnel_config.yaml` with server information
   - Contains username, socket directory, base URL, and usage examples
   - Served by nginx at `/tunnel_config.yaml`

9. **Nginx Configuration**
   - Deploys nginx configuration from template
   - Configures proxy to Unix sockets
   - Sets up WebSocket support
   - Configures timeouts and buffering
   - Serves tunnel configuration file

10. **Service Management**
   - Enables and starts nginx
   - Enables and starts sshd
   - Configures automatic restart/reload handlers

11. **Socket Cleanup Automation**
   - Installs lsof utility for socket monitoring
   - Deploys cleanup script to `/usr/local/bin/cleanup-sockets.sh`
   - Sets up cron job running every 5 minutes
   - Automatically removes inactive socket files without SSH connections
   - Logs cleanup activities to `/var/log/tunnel-cleanup.log`

## Running the Playbook

### Via Ansible Pull (Recommended)

```bash
sudo ansible-pull \
  -U https://github.com/oduvan/webquiz-tunnel-server.git \
  -C main \
  -i localhost, \
  ansible/playbook.yml
```

### Manually

```bash
cd ansible/
ansible-playbook playbook.yml
```

## Customization

### Changing Variables

You can override variables in several ways:

1. **Edit playbook.yml directly** (not recommended for deployment)
2. **Use group_vars or host_vars**
3. **Pass extra vars on command line**:

```bash
ansible-playbook playbook.yml \
  -e "tunnel_user=myuser" \
  -e "nginx_websocket_timeout=7200"
```

### Adding Custom Tasks

For custom server-specific tasks, create a new playbook that imports the main playbook:

```yaml
---
- import_playbook: playbook.yml

- name: Custom server configuration
  hosts: localhost
  become: yes
  tasks:
    - name: Your custom task
      # ... your task here
```

## Post-Deployment Steps

### 1. Configure Let's Encrypt

After the playbook runs, set up SSL certificates:

```bash
sudo certbot --nginx -d your-domain.com
```

### 2. Enable HTTPS in Nginx

Edit `/etc/nginx/sites-available/tunnel-proxy` and uncomment the HTTPS server block.

```bash
sudo nano /etc/nginx/sites-available/tunnel-proxy
# Uncomment the HTTPS server block and SSL configuration
sudo nginx -t
sudo systemctl reload nginx
```

### 3. Test Tunnel Connection

From a client machine with an authorized SSH key:

```bash
ssh -N -R /var/run/tunnels/test.sock:localhost:8000 tunneluser@server.example.com
```

### 4. Verify Proxy

```bash
curl http://your-domain.com/wsaio/test/
```

## Maintenance

### Adding New SSH Keys

1. Add `.pub` file to `files/ssh_keys/`
2. Commit and push
3. Re-run ansible-pull (or wait for GitHub Action)

### Updating Configuration

1. Modify templates or playbook
2. Commit and push changes
3. Deployment happens automatically via GitHub Actions

### Troubleshooting

**Check Ansible syntax:**
```bash
ansible-playbook --syntax-check playbook.yml
```

**Dry-run mode:**
```bash
ansible-playbook --check playbook.yml
```

**Verbose output:**
```bash
ansible-playbook -vvv playbook.yml
```

## Security Notes

- The playbook runs with `become: yes` (sudo privileges)
- SSH keys should be carefully managed and audited
- Regularly review authorized_keys for the tunnel user
- Monitor system logs for unauthorized access attempts
- Keep Ansible and system packages updated

### Tunnel User Security Restrictions

The `tunneluser` account is hardened with the following SSH restrictions:

```
Match User tunneluser
    PermitTTY no                  # No interactive terminal
    X11Forwarding no              # No X11 forwarding
    AllowAgentForwarding no       # No SSH agent forwarding
    AllowTcpForwarding remote     # Only remote port forwarding (tunnels)
    ForceCommand /bin/false       # No command execution
```

**What this means:**
- ✓ User can create SSH tunnels (remote port forwarding)
- ✗ User cannot get an interactive shell
- ✗ User cannot execute commands on the server
- ✗ User cannot forward X11 or SSH agent
- ✗ User cannot do local port forwarding

This ensures the account is strictly limited to its intended purpose: creating reverse SSH tunnels.

## Future Enhancements

Potential improvements for this configuration:

- [ ] Add monitoring and alerting (Prometheus, Grafana)
- [ ] Implement automatic SSL certificate renewal checks
- [ ] Add rate limiting to nginx configuration
- [ ] Create roles for better organization
- [ ] Add firewall configuration (ufw/iptables)
- [ ] Implement log rotation for tunnel logs
- [ ] Add backup and restore procedures
- [ ] Create health check scripts
