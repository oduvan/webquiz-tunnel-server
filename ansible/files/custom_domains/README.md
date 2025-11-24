# Custom Domains Configuration

This directory contains configuration files for custom domains that proxy to HTTP backends.

## Adding a New Custom Domain

To add a new custom domain:

1. Create a YAML file in this directory named after your domain (e.g., `example.com.yml`)
2. Configure the backend host and port in the YAML file
3. Commit and push the changes
4. The deployment will automatically:
   - Create nginx configuration for the domain
   - Obtain Let's Encrypt SSL certificate
   - Start proxying requests to the backend

## Configuration File Format

Create a file named `{domain}.yml` with the following structure:

```yaml
domain: example.com
backend_host_secret: BACKEND_HOST_SECRET_NAME
backend_port_secret: BACKEND_PORT_SECRET_NAME
```

Where:
- `domain`: The full domain name (e.g., cvitanok.lyabah.com)
- `backend_host_secret`: Name of the GitHub secret containing the backend host/IP
- `backend_port_secret`: Name of the GitHub secret containing the backend port

## Example

For `cvitanok.lyabah.com.yml`:

```yaml
domain: cvitanok.lyabah.com
backend_host_secret: JETSON_HOST
backend_port_secret: JETSON_HTTP_PORT
```

## Requirements

1. DNS A record for the domain must point to your server's IP
2. GitHub secrets must be configured with the backend host and port values
3. Backend service must be accessible from the tunnel server
4. Ports 80 and 443 must be accessible for SSL certificate acquisition
