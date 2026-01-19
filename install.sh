#!/usr/bin/env bash
#
# claude-sops installer
#
# Remote install:
#   curl -fsSL https://raw.githubusercontent.com/jordanburke/claude-sops/main/install.sh | bash
#
# Local install:
#   git clone https://github.com/jordanburke/claude-sops.git
#   cd claude-sops && ./install.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/jordanburke/claude-sops.git"
INSTALL_DIR="${HOME}/.local/bin"
REPO_DIR="${HOME}/.local/share/claude-sops"
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

check_git() {
    if ! command -v git &> /dev/null; then
        log_error "git is required but not installed"
        echo ""
        echo "Install with:"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  xcode-select --install"
        else
            echo "  sudo apt install git"
        fi
        exit 1
    fi
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

clone_or_update_repo() {
    log_step "Setting up claude-sops repository"

    if [ -d "$REPO_DIR/.git" ]; then
        log_info "Repository exists, pulling latest changes"
        git -C "$REPO_DIR" pull --quiet origin main || true
    else
        log_info "Cloning repository to $REPO_DIR"
        mkdir -p "$(dirname "$REPO_DIR")"
        git clone --quiet "$REPO_URL" "$REPO_DIR"
    fi
}

detect_install_source() {
    # Check if we're running from a local clone or remotely
    local script_dir=""

    # If BASH_SOURCE is empty or stdin, we're being piped
    if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "bash" ]; then
        return 1  # Remote install
    fi

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

    # Check if we're in a git repo with the expected structure
    if [ -f "$script_dir/bin/claude-sops" ] && [ -d "$script_dir/.git" ]; then
        echo "$script_dir"
        return 0  # Local install
    fi

    return 1  # Remote install
}

install_script() {
    local source_dir="$1"

    log_step "Installing claude-sops to $INSTALL_DIR"

    mkdir -p "$INSTALL_DIR"

    # Remove existing installation
    if [ -L "$INSTALL_DIR/claude-sops" ] || [ -f "$INSTALL_DIR/claude-sops" ]; then
        log_warn "Removing existing installation"
        rm -f "$INSTALL_DIR/claude-sops"
    fi

    # Create symlink to allow updates via git pull
    ln -s "$source_dir/bin/claude-sops" "$INSTALL_DIR/claude-sops"
    log_info "Installed claude-sops (symlinked to $source_dir)"
}

setup_age_key() {
    if [ -f "$AGE_KEY_DIR/keys.txt" ]; then
        log_info "Age key already exists at $AGE_KEY_DIR/keys.txt"
        return
    fi

    # Check if age is installed before trying to generate key
    if ! command -v age &> /dev/null; then
        log_warn "age not installed, skipping key generation"
        echo "After installing age, generate a key with:"
        echo "  mkdir -p ~/.config/sops/age"
        echo "  age-keygen -o ~/.config/sops/age/keys.txt"
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

    mkdir -p "$CONFIG_DIR"

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
        echo "Add to your shell config (~/.bashrc or ~/.zshrc):"
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

    check_git
    check_dependencies

    # Determine installation source
    local source_dir
    if source_dir=$(detect_install_source); then
        log_info "Installing from local repository: $source_dir"
    else
        log_info "Installing from remote repository"
        clone_or_update_repo
        source_dir="$REPO_DIR"
    fi

    install_script "$source_dir"
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
    echo "Update anytime with:"
    echo "  git -C $source_dir pull"
    echo ""
}

main "$@"
