# dotenvx Converter Tool

A tool to convert `.env` files to dotenvx encrypted format with SHA256 hash tracking for secrets.

## Overview

This tool helps manage environment files by:
1. **Scanning with trufflehog** - Detects exposed secrets before encryption (optional)
2. **Checking `.gitignore` safety** - Verifies production keys won't be committed
3. Reading `.env` files (supports both `.ini` and JSON formats)
4. Creating timestamped backups (`.bak` files)
5. **Encrypting ONLY secrets** - Pattern-based detection (KEY, CREDENTIAL, TOKEN, PASSWORD)
6. **Storing config as plaintext** - Non-secret values remain readable using `dotenvx set --plain`
7. **Smart re-encryption prevention** - Skips values already encrypted (starting with `encrypted:`)
8. Generating SHA256 hashes **only for secret values** (not config values or encrypted values)
9. **Automatic hash cleanup** - Removes hash entries for keys no longer in `.env` file
10. Storing hashes in `.env.hashes.<stg|prd>` for audit/verification

### Key Feature: Selective Encryption

The tool intelligently separates secrets from configuration:
- **Secrets** (e.g., `GITHUB_TOKEN`, `DATABASE_PASSWORD`, `API_KEY`) → **Encrypted**
- **Config** (e.g., `NODE_ENV`, `DATABASE_HOST`, `PORT`) → **Plaintext**

This allows you to read config values directly without decryption keys, while keeping sensitive secrets encrypted.

## Prerequisites

- Python 3.6+
- [dotenvx](https://dotenvx.com/) installed (`npm install -g @dotenvx/dotenvx`)
- [trufflehog](https://github.com/trufflesecurity/trufflehog) (optional, for secret detection)
  - macOS: `brew install trufflehog`
  - Linux: Download from [releases](https://github.com/trufflesecurity/trufflehog/releases)

## Usage

```bash
# Basic usage
./dotenvx-converter.py <env-file> --env <stg|prd>

# Examples
./dotenvx-converter.py .env.stg --env stg
./dotenvx-converter.py .env.prd --env prd
./dotenvx-converter.py config.json --env prd

# Hash only (skip encryption)
./dotenvx-converter.py .env.stg --env stg --skip-encryption

# Custom secret patterns
./dotenvx-converter.py .env.stg --env stg --secret-patterns TOKEN,KEY,PASSWORD,SECRET
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `env_file` | Path to .env file (required) | - |
| `--env` | Environment: `stg` or `prd` (required) | - |
| `--secret-patterns` | Comma-separated patterns to identify secrets | `KEY,CREDENTIAL,TOKEN,PASSWORD` |
| `--exclude-patterns` | Comma-separated patterns to exclude from encryption (takes precedence) | `FIREBASE_APP_ID,PUBLIC_KEY` |
| `--skip-encryption` | Skip dotenvx encryption (only create hashes) | False |
| `--skip-detector` | Skip trufflehog secret detection scan | False |
| `--skip-gitignore-check` | Skip .gitignore safety check (for automated pipelines) | False |

## Safety Features

### 1. Trufflehog Secret Detection

Before processing, the tool scans your file with [trufflehog](https://github.com/trufflesecurity/trufflehog) to detect exposed secrets.

**What it detects:**
- GitHub tokens, AWS keys, Stripe keys
- API keys from 700+ services
- Private keys, database credentials
- Slack tokens, OAuth secrets

**Example Output:**
```
=== Running Trufflehog Secret Detection ===
Scanning .env.prd for exposed secrets...
⚠️  Trufflehog detected 2 potential secret(s)!

Findings:
  1. GitHub: ghp_1A2b3C...
  2. AWS: AKIAIOSFODNN7...

⚠️  These appear to be real secrets (not encrypted/hashed)
Recommendations:
  1. Verify these are test values, not production secrets
  2. Use placeholder values like 'your_token_here' in examples
  3. Ensure real secrets are rotated after encryption

Continue anyway? [y/N]:
```

**Skip for test files:**
```bash
./dotenvx-converter.py .env.test --env stg --skip-detector
```

**If not installed:**
```
⚠️  trufflehog not installed - skipping secret detection
Install: brew install trufflehog (macOS)
```

### 2. .gitignore Protection

Before processing, the tool checks your `.gitignore` for required patterns:

**For Production (`--env prd`):**
- **CRITICAL** warnings if `.env.keys` or `.env.*.keys` are missing
- Offers to create/update `.gitignore` automatically
- Prevents accidental commits of production keys

**For Staging (`--env stg`):**
- Informational warnings only
- Staging keys are meant to be committed

**Example Output (Production):**
```
⚠️  .gitignore is missing important patterns:
  ✗ .env.keys
  ✗ .env.*.keys

CRITICAL: Production keys could be committed to git!
Add these lines to .gitignore:
  .env.keys
  .env.*.keys

Add to .gitignore now? [y/N]: y
✓ Updated .gitignore
```

**Skip for CI/CD:**
```bash
./dotenvx-converter.py .env.prd --env prd --skip-gitignore-check
```

## Secret Pattern Detection

The tool automatically identifies secrets based on naming patterns. By default, any environment variable containing these patterns (case-insensitive) is treated as a secret:

- `KEY`
- `CREDENTIAL`
- `TOKEN`
- `PASSWORD`

**Examples:**
- ✅ Secrets: `GITHUB_TOKEN`, `DATABASE_PASSWORD`, `API_KEY`, `AWS_ACCESS_KEY_ID`
- ❌ Config: `NODE_ENV`, `DATABASE_HOST`, `LOG_LEVEL`, `PORT`

### Exclude Patterns (Takes Precedence)

Some environment variables match secret patterns but should NOT be encrypted. The `--exclude-patterns` option allows you to specify exceptions.

**Default Exclude Patterns:**
- `FIREBASE_APP_ID` - Public Firebase identifier (not secret)
- `PUBLIC_KEY` - Public keys meant to be shared (e.g., `DOTENV_PUBLIC_KEY`, `ENCRYPTION_PUBLIC_KEY`)

**Why Exclude?**
- **FIREBASE_APP_ID**: Contains "APP_ID" which might match custom patterns, but it's a public identifier safe to commit
- **PUBLIC_KEY**: Contains "KEY" but public keys are meant to be shared, not encrypted
- **NEXT_PUBLIC_***: Next.js public env vars that get bundled into client code

**Example with Custom Exclude Patterns:**
```bash
# Exclude Next.js public vars and Firebase IDs
./dotenvx-converter.py .env.stg --env stg \
  --exclude-patterns "FIREBASE_APP_ID,PUBLIC_KEY,NEXT_PUBLIC"
```

**Warning Output:**
When a value matches both a secret pattern AND an exclude pattern, you'll see:
```
⚠ FIREBASE_APP_ID: excluded (matches exclude pattern: FIREBASE_APP_ID)
⚠️  1 value(s) matched secret patterns but were excluded
```

This helps you verify that the exclusions are working as intended.

## Smart Re-encryption Prevention

The tool automatically detects and preserves values that are already encrypted, preventing unnecessary re-encryption.

**How it works:**
- Detects values starting with `encrypted:` prefix
- Preserves them as-is in the output file
- Shows clear feedback about preserved values

**Example:**
```bash
# Input .env file with mixed values
GITHUB_TOKEN=encrypted:BObvjtbhZdHgMid2Z10g5abc123  # Already encrypted
API_KEY=new_secret_key_789                          # Needs encryption
NODE_ENV=staging                                     # Config (plaintext)
```

**Output:**
```
Processing 3 total variables:
  - 1 secrets to encrypt
  - 1 already encrypted
  - 1 config values (plaintext)

Encrypting 1 secret(s): dotenvx encrypt...
✔ encrypted (.env.stg.secrets.tmp)

Preserving 1 already encrypted value(s):
  ✓ GITHUB_TOKEN (preserved)

Adding 1 config values as plaintext:
  ✓ NODE_ENV (plaintext)
```

**Benefits:**
- Run the converter multiple times safely
- Update specific secrets while preserving others
- Faster processing (skips already encrypted values)

## Automatic Hash File Cleanup

The tool automatically synchronizes the hash file with your current environment variables, removing entries for keys that no longer exist.

**How it works:**
- Reads existing `.env.hashes.<env>` file if it exists
- Compares with current environment variables
- Removes hash entries for deleted keys
- Shows clear feedback about what was removed

**Example:**
```bash
# First run - creates hashes for API_KEY and STRIPE_SECRET_KEY
./dotenvx-converter.py .env.stg --env stg

# Remove STRIPE_SECRET_KEY from .env.stg
# Then run converter again
./dotenvx-converter.py .env.stg --env stg
```

**Output:**
```
🗑️  Removed 1 key(s) from hash file (no longer in .env):
  - STRIPE_SECRET_KEY

Hashed 1 secrets, skipped 2 config values
Hashes saved to: .env.hashes.stg
```

**Benefits:**
- Hash files stay synchronized with current env files
- Easy to track which secrets were removed
- Prevents stale hash entries from accumulating
- No manual cleanup required

## Input Format Support

### .env/.ini Format
```bash
# Secrets
GITHUB_TOKEN=ghp_1234567890abcdef
DATABASE_PASSWORD=super_secret_123
API_KEY=ak_test_1234567890

# Config (not hashed)
NODE_ENV=staging
DATABASE_HOST=localhost
DATABASE_PORT=5432
```

### JSON Format
```json
{
  "GITHUB_TOKEN": "ghp_1234567890abcdef",
  "DATABASE_PASSWORD": "super_secret_123",
  "API_KEY": "ak_test_1234567890",
  "NODE_ENV": "staging",
  "DATABASE_HOST": "localhost",
  "DATABASE_PORT": 5432
}
```

## Output Files

### 1. Backup File
**Format:** `<original-file>.bak.<timestamp>`

**Example:** `.env.stg.bak.20251220_141423`

Contains the original unencrypted file for recovery.

### 2. Encrypted File
**Format:** `.env.<stg|prd>`

Created by dotenvx with **encrypted secrets** and **plaintext config values**.

**Example `.env.stg`:**
```bash
#/-------------------[DOTENV_PUBLIC_KEY]--------------------/
DOTENV_PUBLIC_KEY_STG_SECRETS="02d5c7af..." # .env.keys.stg

# Encrypted secrets
GITHUB_TOKEN=encrypted:BObvjtbhZdHgMid2Z10g5...
DATABASE_PASSWORD=encrypted:BMho1+QPBLz/U8XLztfh...
API_KEY=encrypted:BKxL+J/sqyP4MYExF7A4Ql...

# Plaintext config (readable without decryption)
NODE_ENV="staging"
DATABASE_HOST="localhost"
PORT="5432"
```

### 3. Key File (Environment-Specific)
**Format:** `.env.keys.<stg|prd>`

**Critical for access control:**
- **`.env.keys.stg`** → **Commit to git** (all developers need it)
- **`.env.keys.prd`** → **CI/CD secrets only** (do NOT commit)

This separation allows you to:
- Share staging keys with all developers
- Restrict production keys to automated deployments only

### 4. Hash File
**Format:** `.env.hashes.<stg|prd>`

**Example:**
```bash
# SHA256 hashes of secret values
# Generated: 2025-12-20T14:14:23.233006
# Environment: stg

API_KEY=6b52058e2f3f0c655be11fd25ee47fbf11c353ac2c3c2d7931beec2387b44355
DATABASE_PASSWORD=292e6640d6f984141f5e3685047fa5a7116be7aae035d0f299f95ee5af61ea3d
GITHUB_TOKEN=bba784933d843a0d32d8ddc42b6209c1d5c6d27f296c3ba5aaffd68b015bcc6d
```

**Note:** Only secrets are hashed, config values are excluded.

## Workflow Example

```bash
# 1. Prepare your .env file
cat > .env.stg << 'EOF'
# Secrets
GITHUB_TOKEN=ghp_xxxxxxxxxxxxx
DATABASE_PASSWORD=my_secret_password

# Config
NODE_ENV=staging
DATABASE_HOST=db.staging.example.com
EOF

# 2. Run the converter
./dotenvx-converter.py .env.stg --env stg

# Output:
# === dotenvx Converter - Environment: STG ===
# Input file: .env.stg
# Secret patterns: KEY, CREDENTIAL, TOKEN, PASSWORD
#
# Reading environment variables...
# Found 4 environment variables
#
# Created backup: .env.stg.bak.20251220_141500
# === Computing SHA256 hashes for secrets ===
#   ✓ GITHUB_TOKEN: a1b2c3d4e5f6g7h8...
#   ✓ DATABASE_PASSWORD: 9i8j7k6l5m4n3o2p...
#   ○ NODE_ENV: skipped (config value)
#   ○ DATABASE_HOST: skipped (config value)
#
# Hashed 2 secrets, skipped 2 config values
# Hashes saved to: .env.hashes.stg
#
# Identified 2 secrets and 2 config values
# Encrypting secrets: dotenvx encrypt -f .env.stg.secrets.tmp -fk .env.keys.stg
# ✔ encrypted (.env.stg.secrets.tmp)
#
# Adding 2 config values as plaintext:
#   ✓ NODE_ENV (plaintext)
#   ✓ DATABASE_HOST (plaintext)
#
# ✓ Encrypted file: .env.stg
# ✓ Key file: .env.keys.stg
#   - 2 encrypted secrets
#   - 2 plaintext config values
# === Conversion Complete! ===
# Backup: .env.stg.bak.20251220_141500
# Encrypted: .env.stg
# Hashes: .env.hashes.stg

# 3. Verify the outputs
ls -la .env.stg*
# -rw-------  .env.stg
# -rw-------  .env.stg.bak.20251220_141500

cat .env.hashes.stg
# Shows hashes for GITHUB_TOKEN and DATABASE_PASSWORD only
```

## Access Control & Git Strategy

### Recommended Git Structure

```bash
# ✅ COMMIT these files
.env.stg                 # Encrypted staging vars (safe to commit)
.env.keys.stg           # Staging key (developers need it)
.env.hashes.stg         # Staging hashes (audit trail)

.env.prd                # Encrypted production vars (safe to commit)
.env.hashes.prd         # Production hashes (audit trail)

# ❌ DO NOT COMMIT these files (add to .gitignore)
.env.keys.prd           # Production key (CI/CD only!)
*.bak.*                 # Backup files (contain plaintext secrets)
test.env                # Test files
```

### CI/CD Setup for Production Keys

**Store `.env.keys.prd` as a GitHub Secret:**

```bash
# 1. After generating .env.keys.prd, add it to GitHub Secrets
gh secret set DOTENV_KEYS_PRD --body "$(cat .env.keys.prd)"

# 2. In CI/CD workflow (e.g., .github/workflows/deploy-prd.yml)
jobs:
  deploy:
    steps:
      - name: Setup dotenv keys
        run: echo "${{ secrets.DOTENV_KEYS_PRD }}" > .env.keys.prd

      - name: Load encrypted environment
        run: dotenvx run -- your-deploy-command
```

**Local Development (Staging):**

```bash
# Developers can decrypt staging vars directly from git
git clone repo
dotenvx run --env-file .env.stg -- npm run dev

# The .env.keys.stg is already in git, so it "just works"
```

## Benefits of Selective Encryption

**Why encrypt only secrets and keep config as plaintext?**

1. **Reduced friction**: Developers can read config values (NODE_ENV, DATABASE_HOST, PORT) without decryption keys
2. **Better debugging**: Plaintext config values are visible in logs, error messages, and version control diffs
3. **Selective access control**: Only sensitive secrets (tokens, passwords, keys) require decryption keys
4. **CI/CD compatibility**: Build configurations can read environment type without secrets access
5. **Audit clarity**: Easier to review what changed in config vs secrets

**Example use case:**
```bash
# Anyone can see the environment type without keys
cat .env.stg | grep NODE_ENV
# NODE_ENV="staging"

# But secrets require decryption
cat .env.stg | grep GITHUB_TOKEN
# GITHUB_TOKEN=encrypted:BObvjtbh...
```

## Security Best Practices

1. **Backup Files:** The `.bak` files contain unencrypted secrets. Store them securely or delete after verification.

2. **Hash Files:** The `.env.hashes.*` files can be committed to git for audit purposes since they only contain hashes (one-way, irreversible).

3. **Encrypted Files:** The encrypted `.env.<stg|prd>` files can be committed safely. Secrets are encrypted, config is readable.

4. **Key Files - Critical:**
   - **Staging keys (`.env.keys.stg`)**: Commit to git for developer access
   - **Production keys (`.env.keys.prd`)**: Store ONLY in CI/CD secrets, NEVER commit

5. **Custom Patterns:** If you have unique naming conventions, use `--secret-patterns` to customize detection:
   ```bash
   ./dotenvx-converter.py .env.stg --env stg --secret-patterns "TOKEN,PRIVATE,SENSITIVE"
   ```

## Integration with Existing Secrets Management

This tool complements the existing YAML-based secrets management in this repository:

- **YAML secrets** (`secrets.prd.yml`, `secrets.stg.yml`): For GCP Secret Manager and GitHub Secrets
- **dotenvx converter**: For local `.env` files and dotenvx-based deployments

Both use SHA256 hashing for secret verification and audit trails.

## Troubleshooting

### dotenvx not found
```bash
# Install dotenvx globally
npm install -g @dotenvx/dotenvx

# Or use npx
npx @dotenvx/dotenvx --version
```

### Permission denied
```bash
chmod +x dotenvx-converter.py
```

### Invalid format error
Ensure your `.env` file follows the standard format:
- Use `KEY=value` syntax (no spaces around `=`)
- One variable per line
- Comments start with `#`

## Related Tools

- `update-secret-hashes.py` - Updates hashes for YAML-based secrets
- `setup-secrets.sh` - Initial secrets setup
- `github/add-client-github-secrets.sh` - GitHub secrets management

## References

- [dotenvx Documentation](https://dotenvx.com/)
- [GitHub Issue #297](https://github.com/pci-tamper-protect/e-skimming-app/issues/297)
- [SECRETS_README.md](./SECRETS_README.md) - Overall secrets management guide
