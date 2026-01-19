# CLAUDE.md

This is claude-sops - a wrapper script that runs Claude Code with SOPS-decrypted secrets as environment variables.

## Project Structure

```
claude-sops/
├── bin/
│   └── claude-sops      # Main wrapper script (bash)
├── install.sh           # Interactive installer
├── uninstall.sh         # Removes symlink (preserves secrets)
├── README.md            # User documentation
├── CLAUDE.md            # This file
└── LICENSE              # MIT
```

## How It Works

1. User runs `claude-sops`
2. Script validates: sops installed, age key exists, secrets file exists
3. Calls `sops exec-env <secrets-file> 'claude "$@"'`
4. Claude runs with decrypted secrets as ENV vars
5. MCP servers inherit ENV vars from parent process

## Key Files

### bin/claude-sops

The main wrapper script. Features:
- Dependency checking (sops, age, claude)
- Configurable paths via env vars
- `--check` flag for validation
- `--secrets` flag to override secrets path
- Helpful error messages with fix instructions

### install.sh

Interactive installer that:
- Creates symlink to `~/.local/bin/`
- Optionally generates age key pair
- Optionally creates secrets template
- Checks if PATH includes install directory

### Configuration Defaults

| Setting | Default Path |
|---------|--------------|
| Secrets file | `~/.config/sops/secrets.yaml` |
| Age private key | `~/.config/sops/age/keys.txt` |
| SOPS config | `~/.config/sops/.sops.yaml` |

## Common Development Tasks

### Testing the Script

```bash
# Check without running Claude
./bin/claude-sops --check

# Verbose mode
./bin/claude-sops -v

# Override secrets file
./bin/claude-sops --secrets /path/to/other/secrets.yaml
```

### Modifying the Script

The script uses standard bash with:
- `set -euo pipefail` for safety
- Color-coded output functions
- Clear argument parsing with while loop
- `exec` to replace process (no subshell)

## Related Projects

- [claude-sudo](https://github.com/jordanburke/claude-sudo) - Similar wrapper for sudo access
- [SOPS](https://github.com/getsops/sops) - Mozilla's secrets management
- [age](https://github.com/FiloSottile/age) - Modern encryption tool
