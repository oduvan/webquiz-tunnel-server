# Setup Guide for WebQuiz Tunnel Server

This guide walks you through the complete setup process for the WebQuiz Tunnel Server.

## Prerequisites

1. **Server Requirements:**
   - Ubuntu 20.04 LTS or later / Debian 10 or later
   - Minimum 1GB RAM
   - Root or sudo access
   - SSH access configured

2. **Domain Name:**
   - webquiz.space pointing to your server's IP address
   - Required for Let's Encrypt SSL certificates

3. **GitHub Repository:**
   - Fork or clone this repository
   - Admin access to configure secrets

## Step-by-Step Setup

### 1. Configure GitHub Secrets

Go to your GitHub repository settings:

1. Navigate to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** and add the following:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `SERVER_HOST` | Server hostname or IP | `webquiz.space` |
| `SERVER_USER` | SSH user with sudo access | `ubuntu`, `root`, or `admin` |
| `SERVER_SSH_KEY` | Private SSH key for server | Contents of your `~/.ssh/id_rsa` |
| `SERVER_PORT` | (Optional) SSH port | `22` (default if not set) |

**To get your SSH private key:**
```bash
cat ~/.ssh/id_rsa
```

Copy the entire content including `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----`.

### 2. Add SSH Keys for Tunnel Users

1. Create SSH key pairs for users who will create tunnels
2. Copy their public keys to `ansible/files/ssh_keys/`
3. Name files descriptively: `username.pub`

**Example:**
```bash
# On user's machine
ssh-keygen -t ed25519 -C "user@example.com" -f ~/.ssh/tunnel_key

# Copy the public key
cat ~/.ssh/tunnel_key.pub
```

Add the public key content to a new file in `ansible/files/ssh_keys/`:
```bash
# In your local repository
echo "ssh-ed25519 AAAAC3Nza...rest_of_key user@example.com" > ansible/files/ssh_keys/user.pub
```

### 3. Initial Deployment

1. **Commit and push your changes:**
```bash
git add ansible/files/ssh_keys/*.pub
git commit -m "Add SSH keys for tunnel users"
git push origin main
```

2. **GitHub Actions will automatically deploy:**
   - Go to **Actions** tab in GitHub
   - Watch the "Deploy Server Configuration" workflow
   - Check for any errors

**Alternative - Manual deployment:**
```bash
# SSH into your server
ssh ubuntu@webquiz.space

# Run ansible-pull
sudo ansible-pull \
  -U https://github.com/YOUR_USERNAME/webquiz-tunnel-server.git \
  -C main \
  -i localhost, \
  ansible/playbook.yml
```

### 4. Configure SSL Certificate

After the initial deployment, SSH into your server and run:

```bash
# Replace with your actual domain
sudo certbot --nginx -d webquiz.space

# Follow the prompts:
# - Enter your email address
# - Agree to terms of service
# - Choose whether to redirect HTTP to HTTPS (recommended: yes)
```

**Enable HTTPS in nginx:**
```bash
sudo nano /etc/nginx/sites-available/tunnel-proxy
```

Uncomment the HTTPS server block (lines starting with `# server {` through the closing `# }`).

Remove the comment markers (`#`) from:
- The entire `server { ... }` block for port 443
- SSL certificate lines
- All location blocks inside the HTTPS server

**Test and reload nginx:**
```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 5. Test the Setup

#### Test SSH Tunnel Connection

From a client machine with an authorized SSH key:

```bash
# Start a test application (example: simple Python HTTP server)
python3 -m http.server 8080

# In another terminal, create the tunnel
ssh -v -N -R /var/run/tunnels/mytest.sock:localhost:8080 \
  -i ~/.ssh/tunnel_key \
  tunneluser@webquiz.space
```

#### Test Proxy Access

Open a browser and navigate to:
```
https://webquiz.space/wsaio/mytest/
```

You should see the directory listing from your Python HTTP server.

**Test with curl:**
```bash
curl https://webquiz.space/wsaio/mytest/
```

### 6. Production Setup

#### Setup Autossh for Reliable Tunnels

Install autossh on client machines:
```bash
# Ubuntu/Debian
sudo apt-get install autossh

# macOS
brew install autossh
```

Create a systemd service for the tunnel (on client machine):

```bash
sudo nano /etc/systemd/system/tunnel-myapp.service
```

Add the following content:
```ini
[Unit]
Description=SSH Tunnel for MyApp
After=network.target

[Service]
Type=simple
User=YOUR_USERNAME
ExecStart=/usr/bin/autossh -M 0 -N \
  -o "ServerAliveInterval=60" \
  -o "ServerAliveCountMax=3" \
  -o "ExitOnForwardFailure=yes" \
  -R /var/run/tunnels/myapp.sock:localhost:8080 \
  -i /home/YOUR_USERNAME/.ssh/tunnel_key \
  tunneluser@webquiz.space
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable tunnel-myapp
sudo systemctl start tunnel-myapp
sudo systemctl status tunnel-myapp
```

## Verification Checklist

- [ ] GitHub secrets configured
- [ ] SSH keys added to repository
- [ ] Initial deployment successful
- [ ] SSL certificate obtained and configured
- [ ] HTTPS enabled in nginx
- [ ] Test tunnel created successfully
- [ ] Proxy access working via HTTPS
- [ ] Production tunnels configured with autossh

## Troubleshooting

### Deployment Fails

**Check GitHub Actions logs:**
- Go to Actions tab → Click on failed workflow
- Review error messages

**Common issues:**
- Incorrect SSH credentials
- Server not accessible
- Insufficient permissions

### SSL Certificate Issues

**Let's Encrypt rate limits:**
- Use `--dry-run` flag to test: `sudo certbot --nginx --dry-run`
- Check rate limits: https://letsencrypt.org/docs/rate-limits/

**Domain not pointing to server:**
```bash
# Check DNS resolution
dig +short webquiz.space

# Should return your server's IP address
```

### Tunnel Connection Issues

**Check SSH connection:**
```bash
ssh -v tunneluser@webquiz.space
# You should be able to connect and see a shell prompt
```

**Check socket directory permissions:**
```bash
# On server
ls -la /var/run/tunnels/
# Should be owned by tunneluser:tunneluser
```

**Check nginx error logs:**
```bash
sudo tail -f /var/log/nginx/error.log
```

### Proxy Not Working

**Test if socket exists:**
```bash
# On server
sudo ss -lx | grep tunnels
# Should show active sockets
```

**Test nginx configuration:**
```bash
sudo nginx -t
```

**Check nginx can access socket:**
```bash
# Add nginx user to tunneluser group (if needed)
sudo usermod -a -G tunneluser www-data
sudo systemctl restart nginx
```

## Maintenance

### Adding New Users

1. Get their SSH public key
2. Add to `ansible/files/ssh_keys/username.pub`
3. Commit and push
4. Deployment happens automatically

### Updating Configuration

1. Edit `ansible/playbook.yml` or templates
2. Commit and push changes
3. Monitor GitHub Actions deployment

### Monitoring

**Check active tunnels:**
```bash
sudo ss -lx | grep tunnels
sudo lsof | grep tunnels
```

**Check nginx access:**
```bash
sudo tail -f /var/log/nginx/access.log
```

**Check system limits:**
```bash
ulimit -n  # File descriptors
cat /proc/sys/fs/file-max  # System-wide file limit
```

## Next Steps

1. **Setup Monitoring:**
   - Configure Prometheus/Grafana for metrics
   - Setup log aggregation (ELK, Loki)

2. **Add Firewall Rules:**
   - Configure ufw or iptables
   - Limit access to necessary ports

3. **Backup Strategy:**
   - Backup SSH keys
   - Backup nginx configuration
   - Document server setup

4. **High Availability:**
   - Consider load balancer setup
   - Multiple tunnel servers
   - Failover configuration

## Security Best Practices

1. **Regular Updates:**
```bash
sudo apt-get update && sudo apt-get upgrade
sudo certbot renew --dry-run  # Test renewal
```

2. **SSH Hardening:**
   - Disable password authentication
   - Use fail2ban for brute force protection
   - Regular audit of authorized_keys

3. **Monitoring:**
   - Setup alerts for unusual traffic
   - Monitor failed login attempts
   - Track active connections

4. **Access Control:**
   - Regularly review SSH keys
   - Remove unused keys promptly
   - Use descriptive key comments

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Check existing issues for solutions
- Contribute improvements via pull requests

## Additional Resources

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Ansible Documentation](https://docs.ansible.com/)
- [SSH Tunneling Guide](https://www.ssh.com/academy/ssh/tunneling)
