# Multi-User Example Walkthrough

This document shows a practical example of setting up and using the multi-user subdomain system.

## Scenario

We have three users who need secure tunnels:
- **Alice**: Frontend developer testing her React app
- **Bob**: Backend developer running an API server
- **Charlie**: Data scientist running a Jupyter notebook

## Step 1: Repository Setup

Add each user to the repository:

```bash
# Add Alice
mkdir -p ansible/files/users/alice
echo "ssh-ed25519 AAAA...alice alice@laptop" > ansible/files/users/alice/laptop.pub
echo "ssh-ed25519 AAAA...alice alice@desktop" > ansible/files/users/alice/desktop.pub

# Add Bob
mkdir -p ansible/files/users/bob
echo "ssh-ed25519 AAAA...bob bob@workstation" > ansible/files/users/bob/work.pub

# Add Charlie
mkdir -p ansible/files/users/charlie
echo "ssh-ed25519 AAAA...charlie charlie@home" > ansible/files/users/charlie/home.pub

# Commit and push
git add ansible/files/users/
git commit -m "Add users: alice, bob, charlie"
git push
```

## Step 2: DNS Configuration

Configure wildcard DNS (or individual records):

```
*.webquiz.xyz  A  203.0.113.10
webquiz.xyz    A  203.0.113.10
```

Verify:
```bash
$ dig alice.webquiz.xyz +short
203.0.113.10
$ dig bob.webquiz.xyz +short
203.0.113.10
```

## Step 3: Automatic Deployment

GitHub Actions automatically deploys when you push. After deployment:

```
Created:
- SSH users: alice, bob, charlie
- Socket dirs: /var/run/tunnels/alice/, /var/run/tunnels/bob/, /var/run/tunnels/charlie/
- Nginx configs: alice-subdomain, bob-subdomain, charlie-subdomain
- SSL certs: alice.webquiz.xyz, bob.webquiz.xyz, charlie.webquiz.xyz
```

## Step 4: Users Create Tunnels

### Alice - React Development Server

Alice starts her React dev server locally:
```bash
# On Alice's laptop (localhost:3000 = React app)
npm start
```

Create the tunnel:
```bash
ssh -N -R /var/run/tunnels/alice/reactapp:localhost:3000 alice@webquiz.xyz
```

Access her app:
```
https://alice.webquiz.xyz/start/reactapp/
```

### Bob - API Server

Bob runs his API server:
```bash
# On Bob's workstation (localhost:8080 = API)
node server.js
```

Create the tunnel:
```bash
ssh -N -R /var/run/tunnels/bob/api:localhost:8080 bob@webquiz.xyz
```

Access his API:
```
https://bob.webquiz.xyz/start/api/
https://bob.webquiz.xyz/start/api/users
https://bob.webquiz.xyz/start/api/health
```

### Charlie - Jupyter Notebook

Charlie runs Jupyter:
```bash
# On Charlie's machine (localhost:8888 = Jupyter)
jupyter notebook --no-browser
```

Create the tunnel:
```bash
ssh -N -R /var/run/tunnels/charlie/notebook:localhost:8888 charlie@webquiz.xyz
```

Access Jupyter:
```
https://charlie.webquiz.xyz/start/notebook/
```

## Step 5: Get Configuration

Each user can fetch their configuration:

```bash
# Alice checks her config
$ curl https://alice.webquiz.xyz/tunnel_config.yaml
username: alice
socket_directory: /var/run/tunnels/alice
base_url: https://alice.webquiz.xyz/start/
subdomain: alice.webquiz.xyz

# Bob checks his config
$ curl https://bob.webquiz.xyz/tunnel_config.yaml
username: bob
socket_directory: /var/run/tunnels/bob
base_url: https://bob.webquiz.xyz/start/
subdomain: bob.webquiz.xyz
```

## Directory Structure on Server

After deployment, the server has:

```
/var/run/tunnels/
├── alice/
│   └── reactapp          (Alice's React app socket)
├── bob/
│   └── api               (Bob's API socket)
└── charlie/
    └── notebook          (Charlie's Jupyter socket)

/home/
├── alice/
│   └── .ssh/
│       └── authorized_keys (laptop.pub, desktop.pub)
├── bob/
│   └── .ssh/
│       └── authorized_keys (work.pub)
└── charlie/
    └── .ssh/
        └── authorized_keys (home.pub)

/etc/nginx/sites-enabled/
├── tunnel-proxy          (Root domain: webquiz.xyz)
├── alice-subdomain       (alice.webquiz.xyz)
├── bob-subdomain         (bob.webquiz.xyz)
└── charlie-subdomain     (charlie.webquiz.xyz)

/etc/letsencrypt/live/
├── webquiz.xyz/
├── alice.webquiz.xyz/
├── bob.webquiz.xyz/
└── charlie.webquiz.xyz/
```

## User Isolation Benefits

### Alice Cannot Access Bob's Sockets

```bash
# Alice tries to create a socket in Bob's directory (FAILS)
$ ssh -N -R /var/run/tunnels/bob/hack:localhost:9999 alice@webquiz.xyz
# ERROR: Permission denied

# Alice can only create sockets in her own directory
$ ssh -N -R /var/run/tunnels/alice/myapp:localhost:9999 alice@webquiz.xyz
# SUCCESS
```

### Subdomain Isolation

```
alice.webquiz.xyz/start/reactapp/  → /var/run/tunnels/alice/reactapp
bob.webquiz.xyz/start/api/         → /var/run/tunnels/bob/api
charlie.webquiz.xyz/start/notebook/ → /var/run/tunnels/charlie/notebook

# Cross-subdomain access doesn't work:
alice.webquiz.xyz/start/api/       → 404 (not in Alice's directory)
bob.webquiz.xyz/start/reactapp/    → 404 (not in Bob's directory)
```

## Adding a Fourth User (Dave)

```bash
# 1. Create directory
mkdir ansible/files/users/dave

# 2. Add key
echo "ssh-ed25519 AAAA...dave dave@laptop" > ansible/files/users/dave/dave.pub

# 3. Commit and push
git add ansible/files/users/dave/
git commit -m "Add user dave"
git push

# 4. Automatic deployment creates:
#    - SSH user: dave
#    - Socket dir: /var/run/tunnels/dave/
#    - Subdomain: dave.webquiz.xyz
#    - SSL cert: dave.webquiz.xyz
#    - Nginx config: dave-subdomain
```

## Removing a User (Charlie)

```bash
# 1. Remove directory
rm -rf ansible/files/users/charlie/

# 2. Commit and push
git commit -am "Remove user charlie"
git push

# Note: Manual cleanup on server may be needed for:
# - SSH user account (userdel charlie)
# - Socket directory (rm -rf /var/run/tunnels/charlie)
# - Nginx config (disabled automatically)
# - SSL cert (preserved for revocation)
```

## Monitoring

Check active tunnels:
```bash
# See all active sockets
sudo ss -lx | grep tunnels

# See Alice's sockets
sudo ls -la /var/run/tunnels/alice/

# Check socket cleanup logs
sudo tail -f /var/log/tunnel-cleanup.log
```

Check nginx access:
```bash
# Alice's subdomain access logs
sudo tail -f /var/log/nginx/access.log | grep alice.webquiz.xyz

# Bob's subdomain access logs
sudo tail -f /var/log/nginx/access.log | grep bob.webquiz.xyz
```

## Root Domain

The root domain serves a static page:
```
https://webquiz.xyz/  → Static HTML page with info
```

Legacy support still works:
```bash
ssh -N -R /var/run/tunnels/test:localhost:8080 tunneluser@webquiz.xyz
# Access at: https://webquiz.xyz/start/test/
```

## Summary

This multi-user system provides:
- ✅ Complete isolation between users
- ✅ Individual subdomains for each user
- ✅ Separate SSL certificates
- ✅ Easy user management via git
- ✅ Automatic deployment
- ✅ Backward compatibility
- ✅ Professional setup for teams
