# User Configuration Directory

This directory contains user-specific configurations for the WebQuiz Tunnel Server.

## Structure

Each subdirectory represents a user/subdomain configuration:

```
users/
├── alice/
│   ├── alice-laptop.pub
│   └── alice-desktop.pub
├── bob/
│   └── bob-key.pub
└── charlie/
    └── charlie.pub
```

## How It Works

- **Folder name**: Used as both the SSH username and subdomain
  - Folder `alice` creates user `alice` and subdomain `alice.webquiz.xyz`
  - Folder `bob` creates user `bob` and subdomain `bob.webquiz.xyz`

- **Files in folder**: SSH public keys authorized for that user
  - All `.pub` files in a user's folder are added to their `authorized_keys`

## What Gets Created

For each user folder:

1. **SSH User**: A dedicated SSH user with that username
2. **Subdomain**: `{username}.webquiz.xyz` with nginx configuration
3. **Socket Directory**: `/var/run/tunnels/{username}/` for that user's sockets
4. **SSL Certificate**: Separate Let's Encrypt certificate for the subdomain
5. **Tunnel Config**: Per-user configuration at `https://{username}.webquiz.xyz/tunnel_config.yaml`

## Adding a New User

1. Create a new folder with the desired username: `mkdir ansible/files/users/newuser`
2. Add SSH public keys to that folder: `cp key.pub ansible/files/users/newuser/`
3. Commit and push changes
4. The deployment will automatically:
   - Create the SSH user
   - Create the socket directory
   - Generate nginx configuration
   - Obtain SSL certificate
   - Configure everything for the new subdomain

## Creating Tunnels

After adding a user, they can create tunnels:

```bash
# User 'alice' creates a tunnel
ssh -N -R /var/run/tunnels/alice/myapp:localhost:8080 alice@webquiz.xyz

# Access the tunnel at:
# https://alice.webquiz.xyz/start/myapp/
```

## Security Notes

- Only add folders for trusted users
- Each user can only access their own socket directory
- SSH keys should be in standard OpenSSH format
- Review and remove unused user directories regularly
