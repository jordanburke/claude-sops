# claude-sops

Run [Claude Code](https://claude.ai/code) with SOPS-encrypted secrets automatically loaded as environment variables.

## Why?

- **Git-friendly secrets**: Store encrypted secrets in your repo with visible keys
- **Zero config MCP**: MCP servers inherit environment variables automatically
- **Team sharing**: Multiple age keys can decrypt the same file
- **CI/CD ready**: Same secrets file works locally and in pipelines

## Quick Start

### 1. Install Dependencies

```bash
# macOS
brew install sops age

# Debian/Ubuntu
sudo apt install age
# SOPS: https://github.com/getsops/sops/releases
```

### 2. Install claude-sops

```bash
git clone https://github.com/jordanburke/claude-sops.git
cd claude-sops
./install.sh
```

The installer will:
- Symlink `claude-sops` to `~/.local/bin/`
- Generate an age key pair (optional)
- Create a secrets template (optional)

### 3. Create Your Secrets

```bash
# Create and encrypt secrets in one step
sops ~/.config/sops/secrets.yaml
```

This opens your `$EDITOR` with a template. Save and it's encrypted.

### 4. Run Claude

```bash
claude-sops
```

That's it! Your secrets are now available as environment variables.

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

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_SOPS_FILE` | `~/.config/sops/secrets.yaml` | Path to encrypted secrets |
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
~/.config/sops/
├── .sops.yaml           # SOPS config (which keys can decrypt)
├── age/
│   ├── keys.txt         # Your private key (NEVER share)
│   └── public.txt       # Your public key (share freely)
└── secrets.yaml         # Encrypted secrets
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

## Security Notes

- Private keys (`keys.txt`) should **never** be committed to git
- Add `*.txt` to `.gitignore` in your age directory
- Secrets are decrypted only in memory, never written to disk
- Use separate secrets files for dev/staging/prod

## Uninstall

```bash
cd claude-sops
./uninstall.sh
```

This removes the symlink but preserves your secrets and keys.

## License

MIT
