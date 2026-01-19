# claude-sops

Run [Claude Code](https://claude.ai/code) with SOPS-encrypted secrets automatically loaded as environment variables.

## Install

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/jordanburke/claude-sops/main/install.sh | bash
```

### Prerequisites

Install sops and age first:

```bash
# macOS
brew install sops age

# Debian/Ubuntu
sudo apt install age
# SOPS: download from https://github.com/getsops/sops/releases
```

### Manual Install

```bash
git clone https://github.com/jordanburke/claude-sops.git
cd claude-sops
./install.sh
```

## Why?

- **Git-friendly secrets**: Store encrypted secrets in your repo with visible keys
- **Zero config MCP**: MCP servers inherit environment variables automatically
- **Team sharing**: Multiple age keys can decrypt the same file
- **CI/CD ready**: Same secrets file works locally and in pipelines

## Quick Start

After installation:

```bash
# 1. Create and encrypt your secrets (per-project or global)
sops secrets/infra.yaml          # Project-local (recommended)
# or
sops ~/.config/sops/secrets.yaml # Global fallback

# 2. Run Claude with secrets loaded (auto-discovers secrets file)
claude-sops

# 3. Verify setup and see which file is being used
claude-sops --check
```

## Usage

```bash
# Run Claude with secrets
claude-sops

# Run Claude in a specific directory
claude-sops /path/to/project

# Use a different secrets file
claude-sops --secrets ~/projects/myapp/secrets.yaml

# Validate your setup
claude-sops --check

# Show help
claude-sops --help
```

## Configuration

### Secrets File Discovery

`claude-sops` automatically finds your secrets file (first match wins):

1. **`CLAUDE_SOPS_FILE`** environment variable (explicit override)
2. **`--secrets FILE`** flag (explicit override)
3. **Project-local files** (walks up from current directory to git root):
   - `secrets/infra.yaml`
   - `secrets/secrets.yaml`
   - `.secrets.yaml`
   - `secrets.yaml`
4. **Global fallback**: `~/.config/sops/secrets.yaml`

Use `claude-sops --check` to see which file is discovered and its source.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_SOPS_FILE` | *(auto-discovered)* | Override secrets file path |
| `SOPS_AGE_KEY_FILE` | `~/.config/sops/age/keys.txt` | Path to age private key |

### Secrets File Format

Your `secrets.yaml` can use any structure:

```yaml
# Flat format
DOKPLOY_TOKEN: dp_xxx
ANTHROPIC_API_KEY: sk-ant-xxx

# Nested format (flattened to ENV vars)
database:
  host: localhost
  password: secret123
```

Nested keys become: `database_host`, `database_password`

## How It Works

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────┐
│ secrets.yaml    │────▶│ sops exec-env│────▶│   claude    │
│ (encrypted)     │     │  (decrypt)   │     │ (with ENV)  │
└─────────────────┘     └──────────────┘     └─────────────┘
```

1. `claude-sops` validates your setup
2. Calls `sops exec-env` to decrypt secrets into memory
3. Spawns `claude` with secrets as environment variables
4. Secrets never touch disk in plaintext

## MCP Integration

MCP servers automatically inherit environment variables. In your `.mcp.json`:

```json
{
  "mcpServers": {
    "dokploy": {
      "command": "npx",
      "args": ["-y", "dokploy-mcp"],
      "env": {}
    }
  }
}
```

The `DOKPLOY_TOKEN` from your secrets file is automatically available to the MCP server.

## Team Setup

### Adding a Team Member

1. Get their age public key: `age1abc123...`
2. Add to your `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: .*\.yaml$
    age: >-
      age1your-key,
      age1their-key
```

3. Re-encrypt existing files:

```bash
sops updatekeys secrets.yaml
```

### CI/CD Integration

```yaml
# GitHub Actions
- name: Run with secrets
  run: |
    sops exec-env secrets.yaml 'npm run deploy'
  env:
    SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
```

## File Structure

```
# Project-local secrets (recommended)
my-project/
├── secrets/
│   └── infra.yaml       # Project secrets (git-ignored, SOPS-encrypted)
├── .sops.yaml           # SOPS config for this project
└── ...

# Global configuration
~/.config/sops/
├── .sops.yaml           # SOPS config (which keys can decrypt)
├── age/
│   ├── keys.txt         # Your private key (NEVER share)
│   └── public.txt       # Your public key (share freely)
└── secrets.yaml         # Global fallback secrets

# Installation
~/.local/share/claude-sops/  # Cloned repo (remote install)
~/.local/bin/claude-sops     # Symlink to script
```

## Update

```bash
# If installed via one-liner
git -C ~/.local/share/claude-sops pull

# If installed via manual clone
cd /path/to/claude-sops && git pull
```

## Commands Reference

```bash
# Edit secrets (decrypts, opens editor, re-encrypts on save)
sops ~/.config/sops/secrets.yaml

# View keys only (values stay encrypted)
cat ~/.config/sops/secrets.yaml

# Export to .env format
sops -d --output-type dotenv ~/.config/sops/secrets.yaml

# Rotate data key (after removing team member)
sops -r ~/.config/sops/secrets.yaml

# Add new key to existing file
sops updatekeys ~/.config/sops/secrets.yaml
```

## Troubleshooting

### "Cannot decrypt secrets file"

- Check your age key exists: `ls ~/.config/sops/age/keys.txt`
- Verify your public key is in the file's `.sops.yaml`
- Try: `sops -d ~/.config/sops/secrets.yaml`

### "sops: command not found"

```bash
brew install sops  # macOS
# or download from https://github.com/getsops/sops/releases
```

### "claude: command not found"

```bash
npm install -g @anthropic-ai/claude-code
```

### PATH issues

If `claude-sops` isn't found after install, add to your shell config:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Security Notes

- Private keys (`keys.txt`) should **never** be committed to git
- Secrets are decrypted only in memory, never written to disk
- Use separate secrets files for dev/staging/prod
- Rotate keys when team members leave: `sops -r secrets.yaml`

## Uninstall

```bash
# If you have the repo locally
cd claude-sops && ./uninstall.sh

# Or manually
rm ~/.local/bin/claude-sops
rm -rf ~/.local/share/claude-sops  # if remote installed
```

This removes the symlink but preserves your secrets and keys.

## License

MIT
