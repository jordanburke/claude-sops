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
