# Deployment Quick Reference

## Multi-User Setup (Recommended)

### 1. Add a New User

Create a directory for each user in `ansible/files/users/`:

```bash
# Create user directory
mkdir -p ansible/files/users/alice

# Add SSH public keys
cp ~/.ssh/id_rsa.pub ansible/files/users/alice/alice-laptop.pub

# Commit and push
git add ansible/files/users/alice/
git commit -m "Add user alice"
git push
```

### 2. Configure DNS

**Option A - Wildcard DNS (Recommended):**
```
*.webquiz.xyz  A  your.server.ip
webquiz.xyz    A  your.server.ip
```

**Option B - Individual Records:**
```
alice.webquiz.xyz  A  your.server.ip
bob.webquiz.xyz    A  your.server.ip
webquiz.xyz        A  your.server.ip
```

### 3. Deploy

After DNS is configured, deployment happens automatically via GitHub Actions when you push to `main`.

### 4. Create Tunnels

Users can now create tunnels to their subdomain:

```bash
# Alice creates a tunnel
ssh -N -R /var/run/tunnels/alice/myapp:localhost:8080 alice@webquiz.xyz

# Access at: https://alice.webquiz.xyz/start/myapp/
```

### 5. Get Configuration

Each user can retrieve their configuration:

```bash
curl https://alice.webquiz.xyz/tunnel_config.yaml
```

Output:
```yaml
username: alice
socket_directory: /var/run/tunnels/alice
base_url: https://alice.webquiz.xyz/start/
subdomain: alice.webquiz.xyz
```

## Legacy Single-User Setup

For backward compatibility, you can still use the legacy mode.

### 1. Add SSH Keys

```bash
cp username.pub ansible/files/ssh_keys/
git add ansible/files/ssh_keys/
git commit -m "Add SSH key"
git push
```

### 2. Create Tunnels

```bash
ssh -N -R /var/run/tunnels/myapp:localhost:8080 tunneluser@webquiz.xyz
# Access at: https://webquiz.xyz/start/myapp/
```

## Required GitHub Secrets

Set these in your GitHub repository settings:

```
Settings → Secrets and variables → Actions → New repository secret
```

| Secret | Value | Example |
|--------|-------|---------|
| SERVER_HOST | Your server hostname or IP | `webquiz.xyz` |
| SERVER_USER | SSH user with sudo | `ubuntu` or `root` |
| SERVER_SSH_KEY | Private SSH key | Contents of `~/.ssh/id_rsa` |
| SERVER_PORT | SSH port (optional) | `22` |

## Key Configuration

- **Socket Directory**: `/var/run/tunnels/`
- **Tunnel User**: `tunneluser`
- **Nginx Pattern**: `/start/{socket_name}/path/` → socket
- **WebSocket Timeout**: 3600s (1 hour)
- **SSH Keepalive**: 60s interval

## Support Commands

```bash
# Check tunnel sockets
sudo ss -lx | grep tunnels

# Check nginx status
sudo systemctl status nginx
sudo nginx -t

# View logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/auth.log

# Test configuration locally
./validate.sh
```

## Troubleshooting

See [SETUP.md](SETUP.md) for detailed troubleshooting guide.
