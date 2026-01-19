#!/usr/bin/env bash
#
# claude-sops installer
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/sops"
AGE_KEY_DIR="${CONFIG_DIR}/age"

log_info() {
    echo -e "${GREEN}[+]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[x]${NC} $1" >&2
}

log_step() {
    echo -e "${BLUE}[*]${NC} $1"
}

check_dependencies() {
    local missing=()

    if ! command -v sops &> /dev/null; then
        missing+=("sops")
    fi

    if ! command -v age &> /dev/null; then
        missing+=("age")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        log_warn "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install with:"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  brew install sops age"
        else
            echo "  # Debian/Ubuntu:"
            echo "  sudo apt install age"
            echo "  # SOPS: download from https://github.com/getsops/sops/releases"
        fi
        echo ""
        read -p "Continue installation anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

install_script() {
    log_step "Installing claude-sops to $INSTALL_DIR"

    mkdir -p "$INSTALL_DIR"

    # Copy or symlink the script
    if [ -L "$INSTALL_DIR/claude-sops" ] || [ -f "$INSTALL_DIR/claude-sops" ]; then
        log_warn "Removing existing installation"
        rm -f "$INSTALL_DIR/claude-sops"
    fi

    # Create symlink to allow updates via git pull
    ln -s "$SCRIPT_DIR/bin/claude-sops" "$INSTALL_DIR/claude-sops"
    log_info "Installed claude-sops (symlinked)"
}

setup_age_key() {
    if [ -f "$AGE_KEY_DIR/keys.txt" ]; then
        log_info "Age key already exists at $AGE_KEY_DIR/keys.txt"
        return
    fi

    log_step "Setting up age encryption key"

    read -p "Generate a new age key? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_warn "Skipping key generation"
        echo "You'll need to create or copy your age key to: $AGE_KEY_DIR/keys.txt"
        return
    fi

    mkdir -p "$AGE_KEY_DIR"
    chmod 700 "$AGE_KEY_DIR"

    age-keygen -o "$AGE_KEY_DIR/keys.txt" 2>&1 | tee /tmp/age-keygen-output.txt
    chmod 600 "$AGE_KEY_DIR/keys.txt"

    # Extract public key
    PUBLIC_KEY=$(grep "public key:" /tmp/age-keygen-output.txt | cut -d: -f2 | tr -d ' ')
    rm /tmp/age-keygen-output.txt

    log_info "Age key generated!"
    echo ""
    echo "Your public key (share this with your team):"
    echo -e "  ${GREEN}$PUBLIC_KEY${NC}"
    echo ""
    echo "Private key stored at: $AGE_KEY_DIR/keys.txt"
    echo ""

    # Save public key for easy reference
    echo "$PUBLIC_KEY" > "$AGE_KEY_DIR/public.txt"
    log_info "Public key also saved to $AGE_KEY_DIR/public.txt"
}

setup_secrets_file() {
    local secrets_file="$CONFIG_DIR/secrets.yaml"

    if [ -f "$secrets_file" ]; then
        log_info "Secrets file already exists at $secrets_file"
        return
    fi

    log_step "Setting up secrets file"

    read -p "Create a template secrets file? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_warn "Skipping secrets file creation"
        return
    fi

    # Create .sops.yaml config
    if [ -f "$AGE_KEY_DIR/public.txt" ]; then
        PUBLIC_KEY=$(cat "$AGE_KEY_DIR/public.txt")
        cat > "$CONFIG_DIR/.sops.yaml" << EOF
creation_rules:
  - path_regex: .*\.yaml$
    age: >-
      $PUBLIC_KEY
EOF
        log_info "Created SOPS config at $CONFIG_DIR/.sops.yaml"
    fi

    # Create template secrets file
    cat > "$secrets_file.template" << 'EOF'
# Secrets managed by SOPS
# Edit with: sops ~/.config/sops/secrets.yaml

# Infrastructure tokens
DOKPLOY_TOKEN: your-dokploy-token
BETTERSTACK_TOKEN: your-betterstack-token
INFISICAL_TOKEN: your-infisical-token

# API keys
ANTHROPIC_API_KEY: your-anthropic-key
GITHUB_TOKEN: your-github-token

# Database (if needed)
DATABASE_URL: postgres://user:pass@host:5432/db
EOF

    log_info "Created template at $secrets_file.template"
    echo ""
    echo "To create your encrypted secrets file:"
    echo "  1. Edit the template: $secrets_file.template"
    echo "  2. Encrypt it: cd $CONFIG_DIR && sops -e secrets.yaml.template > secrets.yaml"
    echo "  3. Delete the template: rm $secrets_file.template"
    echo ""
    echo "Or create directly with: sops $secrets_file"
}

check_path() {
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_warn "$INSTALL_DIR is not in your PATH"
        echo ""
        echo "Add to your shell config:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
    fi
}

main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║       claude-sops installer            ║"
    echo "║  Run Claude with encrypted secrets     ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    check_dependencies
    install_script
    setup_age_key
    setup_secrets_file
    check_path

    echo ""
    log_info "Installation complete!"
    echo ""
    echo "Quick start:"
    echo "  1. Create/edit secrets: sops ~/.config/sops/secrets.yaml"
    echo "  2. Run Claude: claude-sops"
    echo "  3. Verify setup: claude-sops --check"
    echo ""
}

main "$@"
