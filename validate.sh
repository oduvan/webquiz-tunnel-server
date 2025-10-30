#!/bin/bash
# Validation script for WebQuiz Tunnel Server configuration
# This script checks that all required files and configurations are in place

echo "=== WebQuiz Tunnel Server Configuration Validation ==="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SUCCESS=0
WARNINGS=0
FAILURES=0

# Function to print success
success() {
    echo -e "${GREEN}✓${NC} $1"
    ((SUCCESS++))
}

# Function to print warning
warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# Function to print failure
failure() {
    echo -e "${RED}✗${NC} $1"
    ((FAILURES++))
}

# Check repository structure
echo "Checking repository structure..."

if [ -f "ansible/playbook.yml" ]; then
    success "Ansible playbook found"
else
    failure "Ansible playbook missing"
fi

if [ -f "ansible/ansible.cfg" ]; then
    success "Ansible config found"
else
    failure "Ansible config missing"
fi

if [ -f "ansible/templates/nginx-tunnel-proxy.conf.j2" ]; then
    success "Nginx template found"
else
    failure "Nginx template missing"
fi

if [ -d "ansible/files/ssh_keys" ]; then
    success "SSH keys directory found"
else
    failure "SSH keys directory missing"
fi

if [ -f ".github/workflows/deploy.yml" ]; then
    success "GitHub workflow found"
else
    failure "GitHub workflow missing"
fi

if [ -f "README.md" ]; then
    success "README.md found"
else
    failure "README.md missing"
fi

if [ -f "SETUP.md" ]; then
    success "SETUP.md found"
else
    failure "SETUP.md missing"
fi

echo ""
echo "Checking SSH keys..."

# Count SSH public keys (excluding README)
KEY_COUNT=$(find ansible/files/ssh_keys -name "*.pub" -type f 2>/dev/null | wc -l)
if [ "$KEY_COUNT" -gt 0 ]; then
    success "Found $KEY_COUNT SSH public key(s)"
else
    warning "No SSH public keys found in ansible/files/ssh_keys/"
    echo "  Add .pub files to authorize tunnel users"
fi

echo ""
echo "Checking YAML syntax..."

# Check if yamllint is available
if command -v yamllint &> /dev/null; then
    YAML_FILES="ansible/playbook.yml .github/workflows/deploy.yml"
    if yamllint -d "{extends: default, rules: {line-length: {max: 120}}}" $YAML_FILES 2>&1 | grep -q "error"; then
        failure "YAML syntax errors found"
        yamllint $YAML_FILES 2>&1 | grep "error"
    else
        success "YAML syntax is valid"
    fi
else
    warning "yamllint not available, skipping YAML validation"
fi

echo ""
echo "Checking Ansible playbook syntax..."

# Check if ansible-playbook is available
if command -v ansible-playbook &> /dev/null; then
    PLAYBOOK_OUTPUT=$(ansible-playbook --syntax-check --inventory=localhost, ansible/playbook.yml 2>&1)
    if [ $? -eq 0 ]; then
        success "Ansible playbook syntax is valid"
    else
        failure "Ansible playbook has syntax errors"
        echo "$PLAYBOOK_OUTPUT" | grep -E "(ERROR|error|fatal)"
    fi
else
    warning "ansible-playbook not available, skipping Ansible validation"
fi

echo ""
echo "Checking GitHub workflow configuration..."

if [ -f ".github/workflows/deploy.yml" ]; then
    # Check for required secrets references
    if grep -q "SERVER_HOST" .github/workflows/deploy.yml; then
        success "SERVER_HOST secret referenced"
    else
        failure "SERVER_HOST secret not referenced"
    fi
    
    if grep -q "SERVER_USER" .github/workflows/deploy.yml; then
        success "SERVER_USER secret referenced"
    else
        failure "SERVER_USER secret not referenced"
    fi
    
    if grep -q "SERVER_SSH_KEY" .github/workflows/deploy.yml; then
        success "SERVER_SSH_KEY secret referenced"
    else
        failure "SERVER_SSH_KEY secret not referenced"
    fi
fi

echo ""
echo "Checking nginx template..."

if [ -f "ansible/templates/nginx-tunnel-proxy.conf.j2" ]; then
    if grep -q "proxy_pass.*unix.*tunnel_socket_dir" ansible/templates/nginx-tunnel-proxy.conf.j2; then
        success "Nginx template has Unix socket proxy configuration"
    else
        failure "Nginx template missing Unix socket proxy configuration"
    fi
    
    if grep -q "proxy_http_version 1.1" ansible/templates/nginx-tunnel-proxy.conf.j2; then
        success "Nginx template has WebSocket support (HTTP 1.1)"
    else
        failure "Nginx template missing WebSocket support"
    fi
    
    if grep -q "Upgrade.*http_upgrade" ansible/templates/nginx-tunnel-proxy.conf.j2; then
        success "Nginx template has WebSocket upgrade headers"
    else
        failure "Nginx template missing WebSocket upgrade headers"
    fi
    
    # Check if the regex allows optional trailing slash
    if grep -q 'location ~ .*\^/wsaio/.*/?(' ansible/templates/nginx-tunnel-proxy.conf.j2; then
        success "Nginx template URL pattern supports optional trailing slash"
    else
        failure "Nginx template URL pattern does not support optional trailing slash"
    fi
fi

echo ""
echo "=== Validation Summary ==="
echo -e "${GREEN}Successes: $SUCCESS${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Failures: $FAILURES${NC}"
echo ""

if [ $FAILURES -gt 0 ]; then
    echo "⚠️  Validation failed with $FAILURES error(s)"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "✓ Validation passed with $WARNINGS warning(s)"
    exit 0
else
    echo "✓ All checks passed successfully!"
    exit 0
fi
