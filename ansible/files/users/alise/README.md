# User: alise

This directory contains SSH public keys for user `alise`.

## Current Status

The directory currently contains a placeholder SSH public key. **This key should be replaced with the actual user's SSH public key(s).**

## What This User Gets

- **SSH Username**: `alise`
- **Subdomain**: `alise.webquiz.xyz`
- **Socket Directory**: `/var/run/tunnels/alise/`
- **SSL Certificate**: Automatically obtained for `alise.webquiz.xyz`
- **Tunnel Config**: Available at `https://alise.webquiz.xyz/tunnel_config.yaml`

## Replacing the Placeholder Key

1. Remove the `placeholder.pub` file
2. Add your actual SSH public key(s) to this directory (must have `.pub` extension)
3. Commit and push the changes
4. The deployment will automatically update the authorized keys

## Creating Tunnels

Once your actual SSH key is added, you can create tunnels:

```bash
# Create a tunnel for your application
ssh -N -R /var/run/tunnels/alise/myapp:localhost:8080 alise@webquiz.xyz

# Access your application at:
# https://alise.webquiz.xyz/start/myapp/
```

## Getting Your SSH Public Key

If you don't have an SSH key yet:

```bash
# Generate a new SSH key
ssh-keygen -t ed25519 -C "your-email@example.com"

# Display your public key
cat ~/.ssh/id_ed25519.pub
```

Copy the output and save it as a `.pub` file in this directory.
