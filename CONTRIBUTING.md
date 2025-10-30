# Contributing to WebQuiz Tunnel Server

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Issues

- Use the GitHub issue tracker
- Provide clear description and reproduction steps
- Include relevant logs and error messages
- Specify your environment (OS, versions, etc.)

### Adding SSH Keys for New Tunnel Users

1. Get the user's SSH public key
2. Create a new file in `ansible/files/ssh_keys/`
3. Name it descriptively: `username.pub` or `username-device.pub`
4. Add the public key content
5. Commit and push - deployment is automatic

### Modifying Server Configuration

#### Changing Timeouts

Edit `ansible/playbook.yml`:
```yaml
vars:
  nginx_proxy_timeout: 300        # Proxy timeout in seconds
  nginx_websocket_timeout: 3600   # WebSocket timeout in seconds
```

#### Modifying Nginx Configuration

Edit `ansible/templates/nginx-tunnel-proxy.conf.j2` and commit changes.

#### Adjusting System Limits

Edit the limits in `ansible/playbook.yml` under:
- "Configure system limits" task
- "Configure sysctl for network tuning" task

### Development Workflow

1. **Fork the repository**
2. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
4. **Test your changes**:
   ```bash
   ./validate.sh
   yamllint ansible/playbook.yml
   ansible-playbook --syntax-check ansible/playbook.yml
   ```
5. **Commit with clear messages**:
   ```bash
   git commit -m "Add feature: description"
   ```
6. **Push and create a Pull Request**

### Testing Changes

#### Local Validation

```bash
# Run validation script
./validate.sh

# Check YAML syntax
yamllint ansible/

# Check Ansible syntax
cd ansible/
ansible-playbook --syntax-check playbook.yml
```

#### Testing on a Server

For major changes, test on a development server first:

```bash
# On dev server
sudo ansible-pull \
  -U https://github.com/YOUR_USERNAME/webquiz-tunnel-server.git \
  -C your-branch-name \
  -i localhost, \
  ansible/playbook.yml
```

### Code Style

#### YAML Files

- Use 2 spaces for indentation
- Follow yamllint rules (run `yamllint` before committing)
- Keep lines under 120 characters when possible
- Use descriptive task names in Ansible

#### Bash Scripts

- Use shellcheck for validation
- Include error handling
- Add comments for complex logic
- Use meaningful variable names

#### Ansible Playbooks

- Use descriptive task names
- Group related tasks with comments
- Use handlers for service restarts
- Add tags for selective execution where appropriate

### Documentation

When adding features:

1. Update relevant documentation files
2. Add examples where appropriate
3. Update troubleshooting section if needed
4. Keep documentation clear and concise

Documentation files to consider:
- `README.md` - Main project documentation
- `SETUP.md` - Detailed setup guide
- `QUICKSTART.md` - Quick reference
- `ansible/README.md` - Ansible-specific docs

### Pull Request Guidelines

#### Before Submitting

- [ ] Code follows project style
- [ ] All tests pass (`./validate.sh`)
- [ ] Documentation is updated
- [ ] Commit messages are clear
- [ ] No sensitive data in commits

#### PR Description Should Include

- Clear description of changes
- Motivation and context
- Related issue numbers
- Testing performed
- Breaking changes (if any)

### Security Considerations

When contributing:

- Never commit secrets or credentials
- Review security implications of changes
- Test with restricted permissions
- Follow principle of least privilege
- Report security issues privately

### Getting Help

- Open an issue for questions
- Tag issues appropriately
- Be patient and respectful
- Provide context and details

## Project Structure

```
.
├── .github/workflows/    # CI/CD workflows
├── ansible/
│   ├── files/
│   │   └── ssh_keys/    # SSH public keys
│   ├── templates/       # Jinja2 templates
│   ├── playbook.yml     # Main playbook
│   └── ansible.cfg      # Ansible config
├── README.md            # Main documentation
├── SETUP.md             # Setup guide
├── QUICKSTART.md        # Quick reference
└── validate.sh          # Validation script
```

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Questions?

Open an issue or discussion on GitHub for any questions about contributing.

Thank you for contributing!
