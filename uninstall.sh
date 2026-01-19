#!/usr/bin/env bash
#
# claude-sops uninstaller
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="${HOME}/.local/bin"
REPO_DIR="${HOME}/.local/share/claude-sops"
CONFIG_DIR="${HOME}/.config/sops"

log_info() {
    echo -e "${GREEN}[+]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

main() {
    echo ""
    echo "claude-sops uninstaller"
    echo "======================="
    echo ""

    # Remove symlink/script
    if [ -L "$INSTALL_DIR/claude-sops" ] || [ -f "$INSTALL_DIR/claude-sops" ]; then
        rm -f "$INSTALL_DIR/claude-sops"
        log_info "Removed $INSTALL_DIR/claude-sops"
    else
        log_warn "claude-sops not found in $INSTALL_DIR"
    fi

    # Check for remote install repo
    if [ -d "$REPO_DIR" ]; then
        echo ""
        read -p "Remove cloned repository at $REPO_DIR? [y/N] " -n 1 -r < /dev/tty
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$REPO_DIR"
            log_info "Removed $REPO_DIR"
        else
            log_warn "Kept $REPO_DIR"
        fi
    fi

    echo ""
    echo "Note: Your secrets and age keys were NOT removed."
    echo ""
    echo "To fully remove all data (DESTRUCTIVE):"
    echo "  rm -rf $CONFIG_DIR"
    echo ""
    echo "To remove just the age key:"
    echo "  rm -rf $CONFIG_DIR/age"
    echo ""

    log_info "Uninstallation complete"
}

main "$@"
