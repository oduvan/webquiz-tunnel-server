# Deployment Quick Reference

## Required GitHub Secrets

Set these in your GitHub repository settings:

```
Settings → Secrets and variables → Actions → New repository secret
```

| Secret | Value | Example |
|--------|-------|---------|
| SERVER_HOST | Your server hostname or IP | `tunnel.example.com` |
| SERVER_USER | SSH user with sudo | `ubuntu` or `root` |
| SERVER_SSH_KEY | Private SSH key | Contents of `~/.ssh/id_rsa` |
| SERVER_PORT | SSH port (optional) | `22` |

## Deployment Steps

1. **Add SSH public keys** for tunnel users to `ansible/files/ssh_keys/`
2. **Commit and push** to `main` branch
3. **GitHub Actions** will automatically deploy via ansible-pull
4. **Configure SSL** on the server:
   ```bash
   ssh user@server
   sudo certbot --nginx -d your-domain.com
   ```
5. **Enable HTTPS** in nginx:
   ```bash
   sudo nano /etc/nginx/sites-available/tunnel-proxy
   # Uncomment HTTPS server block
   sudo nginx -t && sudo systemctl reload nginx
   ```

## Testing

```bash
# On client: Create test tunnel
ssh -N -R /var/run/tunnels/test.sock:localhost:8080 tunneluser@server

# In browser or curl
curl https://server/wsaio/test/
```

## Key Configuration

- **Socket Directory**: `/var/run/tunnels/`
- **Tunnel User**: `tunneluser`
- **Nginx Pattern**: `/wsaio/{socket_name}/path/` → socket
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
