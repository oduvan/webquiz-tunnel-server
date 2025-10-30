# SSH Public Keys for Tunnel Users

This directory contains SSH public keys that will be authorized to create tunnel connections.

## Adding SSH Keys

To add a new user's SSH key:

1. Add their public key file (`.pub` extension) to this directory
2. Run the ansible-pull command or GitHub Actions workflow to deploy the changes
3. The key will be automatically added to the `tunneluser` account's `authorized_keys` file

## File Naming Convention

- Name files descriptively: `username.pub` or `username-device.pub`
- Example: `john-laptop.pub`, `jane-workstation.pub`

## Key Format

Keys should be in standard OpenSSH public key format:
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... user@host
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@host
```

## Example Usage

After adding a key here, the user can create a tunnel with:
```bash
ssh -N -L /var/run/tunnels/myapp.sock:localhost:8080 tunneluser@server.example.com
```

## Security Notes

- Only add keys for trusted users
- Review keys regularly and remove unused ones
- Each key should have a descriptive comment identifying the owner
