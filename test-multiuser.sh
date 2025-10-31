#!/bin/bash
# Test script to validate multi-user configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Multi-User Configuration Test ==="
echo ""

# Check for user directories
echo "Checking user directories..."
if [ -d "ansible/files/users" ]; then
    USER_COUNT=$(find ansible/files/users -mindepth 1 -maxdepth 1 -type d | wc -l)
    echo "✓ Found $USER_COUNT user director(ies)"
    
    for user_dir in ansible/files/users/*/; do
        if [ -d "$user_dir" ]; then
            username=$(basename "$user_dir")
            key_count=$(find "$user_dir" -name "*.pub" -type f | wc -l)
            echo "  - User: $username ($key_count SSH key(s))"
        fi
    done
else
    echo "✗ No users directory found"
    exit 1
fi

echo ""
echo "Checking template files..."

required_templates=(
    "ansible/templates/nginx-root-domain.conf.j2"
    "ansible/templates/nginx-user-subdomain.conf.j2"
    "ansible/templates/user_tunnel_config.yaml.j2"
    "ansible/templates/tunnel_config.yaml.j2"
)

for template in "${required_templates[@]}"; do
    if [ -f "$template" ]; then
        echo "✓ $template"
    else
        echo "✗ Missing: $template"
        exit 1
    fi
done

echo ""
echo "Validating Ansible playbook syntax..."
if ansible-playbook --syntax-check ansible/playbook.yml > /dev/null 2>&1; then
    echo "✓ Playbook syntax is valid"
else
    echo "✗ Playbook has syntax errors"
    exit 1
fi

echo ""
echo "Checking cleanup script..."
if [ -f "ansible/files/scripts/cleanup-sockets.sh" ]; then
    if grep -q "user_dir" ansible/files/scripts/cleanup-sockets.sh; then
        echo "✓ Cleanup script supports multi-user directories"
    else
        echo "⚠ Cleanup script might not support multi-user directories"
    fi
else
    echo "✗ Cleanup script not found"
    exit 1
fi

echo ""
echo "Checking documentation..."
if grep -q "Multi-User" README.md && grep -q "ansible/files/users" README.md; then
    echo "✓ README.md documents multi-user setup"
else
    echo "⚠ README.md might need multi-user documentation"
fi

if grep -q "Multi-User" ARCHITECTURE.md; then
    echo "✓ ARCHITECTURE.md documents multi-user architecture"
else
    echo "⚠ ARCHITECTURE.md might need multi-user documentation"
fi

echo ""
echo "=== All Tests Passed ==="
echo ""
echo "Next steps:"
echo "1. Add user directories in ansible/files/users/{username}/"
echo "2. Add SSH public keys to user directories"
echo "3. Configure wildcard DNS for *.webquiz.xyz"
echo "4. Deploy using ansible-pull or GitHub Actions"
