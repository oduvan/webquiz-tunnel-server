# Custom Domain Support - Implementation Summary

## Overview

This implementation adds support for custom domains that proxy all traffic to HTTP backends, with automatic SSL certificate provisioning via Let's Encrypt.

## Use Case

The primary use case is proxying entire domains to backend services, such as:
- IoT devices (e.g., Jetson Nano)
- Internal services
- Development servers
- Any HTTP/HTTPS backend

## Architecture

### Request Flow

```
User → https://cvitanok.lyabah.com/ 
     → Nginx (SSL termination) 
     → http://JETSON_HOST:JETSON_HTTP_PORT/
```

### Components

1. **Configuration Files** (`ansible/files/custom_domains/*.yml`)
   - Simple YAML files, one per domain
   - Specifies domain name and secret names for backend host/port
   
2. **Nginx Template** (`ansible/templates/nginx-custom-domain.conf.j2`)
   - HTTP server block (port 80) for Let's Encrypt challenges
   - HTTPS redirect when SSL is available
   - HTTPS server block (port 443) with SSL termination
   - Reverse proxy to backend
   - WebSocket support
   
3. **Ansible Playbook** (`ansible/playbook.yml`)
   - Discovers YAML configuration files
   - Reads backend host/port from environment variables
   - Validates configuration
   - Creates nginx configurations
   - Obtains SSL certificates
   - Updates nginx after SSL acquisition

4. **GitHub Actions Workflow** (`.github/workflows/deploy.yml`)
   - Passes secrets as environment variables to the server
   - Uses `sudo -E` to preserve environment for ansible-pull

## Adding a New Custom Domain

### Step 1: Create Configuration File

Create `ansible/files/custom_domains/example.com.yml`:

```yaml
domain: example.com
backend_host_secret: EXAMPLE_BACKEND_HOST
backend_port_secret: EXAMPLE_BACKEND_PORT
```

### Step 2: Configure GitHub Secrets

Add secrets in GitHub repository settings:
- `EXAMPLE_BACKEND_HOST`: Backend IP or hostname (e.g., `10.0.0.5`)
- `EXAMPLE_BACKEND_PORT`: Backend port (e.g., `3000`)

### Step 3: Update DNS

Point `example.com` A record to your tunnel server's IP.

### Step 4: Deploy

Commit and push:
```bash
git add ansible/files/custom_domains/example.com.yml
git commit -m "Add custom domain example.com"
git push
```

The GitHub Actions workflow will:
1. SSH to the server
2. Export the secrets as environment variables
3. Run ansible-pull
4. Create nginx configuration
5. Obtain SSL certificate
6. Configure HTTPS redirect
7. Start proxying traffic

## Security Features

1. **SSL/TLS Encryption**
   - Automatic Let's Encrypt certificates
   - HTTPS redirect enforced
   - Modern SSL configuration

2. **Validation**
   - Backend host/port must be configured
   - Deployment fails with clear error if secrets are missing
   - Prevents accidental misconfiguration

3. **WebSocket Support**
   - Full WebSocket upgrade support
   - Long-lived connections supported

## Configuration Example: cvitanok.lyabah.com

```yaml
# ansible/files/custom_domains/cvitanok.lyabah.com.yml
domain: cvitanok.lyabah.com
backend_host_secret: JETSON_HOST
backend_port_secret: JETSON_HTTP_PORT
```

GitHub Secrets:
- `JETSON_HOST`: IP/hostname of Jetson device
- `JETSON_HTTP_PORT`: HTTP port on Jetson device

Result:
- All traffic to `https://cvitanok.lyabah.com/` is proxied to `http://JETSON_HOST:JETSON_HTTP_PORT/`
- SSL certificate automatically obtained
- HTTP automatically redirects to HTTPS
- WebSocket connections supported

## Differences from User Subdomain Mode

| Feature | User Subdomain Mode | Custom Domain Mode |
|---------|-------------------|-------------------|
| Backend | Unix domain sockets | HTTP backends |
| Use Case | SSH tunnel forwarding | Proxy to remote services |
| URL Pattern | `username.domain.com/start/app/` | `custom.domain.com/` |
| Configuration | SSH keys in user directory | YAML file + GitHub secrets |
| User Isolation | Per-user socket directories | N/A (single backend per domain) |

## Troubleshooting

### Certificate Not Obtained

1. Verify DNS A record points to server
2. Check ports 80 and 443 are accessible
3. Review Let's Encrypt rate limits
4. Check nginx error logs: `sudo tail -f /var/log/nginx/error.log`

### Backend Not Reachable

1. Verify backend host/port are correct in GitHub secrets
2. Check network connectivity from server to backend
3. Ensure backend service is running
4. Check nginx error logs

### Configuration Validation Failed

Error message will indicate which secret is missing:
```
Custom domain example.com is missing backend_host or backend_port. 
Ensure EXAMPLE_BACKEND_HOST and EXAMPLE_BACKEND_PORT are set as environment variables.
```

Solution: Add the required secrets to GitHub repository settings.

## Future Enhancements

Potential improvements for future versions:

1. **HTTPS Backends**: Support proxying to HTTPS backends
2. **Authentication**: Add basic auth or OAuth protection
3. **Rate Limiting**: Implement request rate limiting
4. **Custom Headers**: Allow custom header configuration
5. **Path Rewriting**: Support URL path rewriting rules
6. **Multiple Backends**: Load balancing across multiple backends
7. **Health Checks**: Automatic backend health monitoring

## Testing

The implementation was tested using:
1. `ansible-playbook --syntax-check` - Validates playbook syntax
2. `ansible-playbook --check` - Dry run without making changes
3. Manual testing with environment variables set
4. Validation of error handling when secrets are missing

All tests passed successfully.
