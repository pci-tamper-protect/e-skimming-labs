# dotenvx Converter - Quick Start Guide

## TL;DR

```bash
# Convert staging (share with all devs)
./dotenvx-converter.py .env.stg --env stg

# Convert production (CI/CD only)
./dotenvx-converter.py .env.prd --env prd
gh secret set DOTENV_KEYS_PRD --body "$(cat .env.keys.prd)"
rm .env.keys.prd  # Don't commit!
```

## Key Concepts

### Separate Keys Per Environment = Better Access Control

| File | Staging (STG) | Production (PRD) |
|------|--------------|------------------|
| Encrypted vars | `.env.stg` ✅ commit | `.env.prd` ✅ commit |
| Decryption key | `.env.keys.stg` ✅ commit | `.env.keys.prd` ❌ CI/CD only |
| Hash audit | `.env.hashes.stg` ✅ commit | `.env.hashes.prd` ✅ commit |

**Why?**
- Devs get staging key → can work locally
- Devs DON'T get prod key → can't decrypt production secrets
- CI/CD gets prod key from GitHub Secrets → can deploy

## Workflow

### Initial Setup (One-time)

```bash
# 1. Add to .gitignore
cat >> .gitignore << 'EOF'
.env.keys.prd
*.bak.*
test.env
EOF

# 2. Install dotenvx if not installed
npm install -g @dotenvx/dotenvx

# 3. Install trufflehog for secret detection (optional but recommended)
brew install trufflehog  # macOS
# or download from: https://github.com/trufflesecurity/trufflehog/releases
```

### Converting Staging Environment

```bash
# 1. Prepare your staging secrets
cat > .env.stg << 'EOF'
GITHUB_TOKEN=ghp_stg_xxxxx
DATABASE_PASSWORD=stg_password
DATABASE_HOST=staging.example.com
EOF

# 2. Convert to encrypted format
./dotenvx-converter.py .env.stg --env stg

# 3. Commit everything
git add .env.stg .env.keys.stg .env.hashes.stg
git commit -m "Add encrypted staging environment"
git push

# 4. Other devs can now decrypt locally
dotenvx run -f .env.stg -fk .env.keys.stg -- npm run dev
```

### Converting Production Environment

```bash
# 1. Prepare your production secrets
cat > .env.prd << 'EOF'
GITHUB_TOKEN=ghp_prd_xxxxx
DATABASE_PASSWORD=prd_super_secret
DATABASE_HOST=production.example.com
EOF

# 2. Convert to encrypted format
./dotenvx-converter.py .env.prd --env prd

# 3. Store production key in GitHub Secrets (NOT git!)
gh secret set DOTENV_KEYS_PRD --body "$(cat .env.keys.prd)"

# 4. Commit encrypted file and hashes (NOT the key!)
git add .env.prd .env.hashes.prd
git commit -m "Add encrypted production environment"

# 5. Delete local production key (safety)
rm .env.keys.prd

git push
```

### CI/CD Configuration

```yaml
# .github/workflows/deploy-prd.yml
name: Deploy Production
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup dotenvx key
        run: echo "${{ secrets.DOTENV_KEYS_PRD }}" > .env.keys.prd

      - name: Deploy with encrypted environment
        run: |
          dotenvx run -f .env.prd -fk .env.keys.prd -- ./deploy.sh

      - name: Cleanup
        if: always()
        run: rm -f .env.keys.prd
```

## Common Operations

### Update a Secret

```bash
# 1. Decrypt current file
dotenvx decrypt -f .env.stg -fk .env.keys.stg > temp.env

# 2. Edit the secret
sed -i 's/old_value/new_value/' temp.env

# 3. Re-encrypt
./dotenvx-converter.py temp.env --env stg
rm temp.env

# 4. Commit
git add .env.stg .env.hashes.stg
git commit -m "Update staging secret"
```

### View Encrypted Secrets (Decrypted)

```bash
# Staging (anyone can do this)
dotenvx decrypt -f .env.stg -fk .env.keys.stg

# Production (only works if you have .env.keys.prd)
dotenvx decrypt -f .env.prd -fk .env.keys.prd

# Or run commands with decrypted environment
dotenvx run -f .env.stg -fk .env.keys.stg -- npm run dev
```

### Verify Secrets Match

```bash
# Compare hashes to verify secrets haven't changed unexpectedly
cat .env.hashes.stg

# Each secret should show the same hash as when it was last updated
```

## Troubleshooting

### "Cannot decrypt" error

**Staging:**
- Make sure `.env.keys.stg` is committed to git
- Try `git pull` to get the latest key

**Production:**
- Check if `.env.keys.prd` exists locally
- In CI/CD, verify `DOTENV_KEYS_PRD` secret is set

### Wrong secret pattern detection

```bash
# Customize what's considered a secret
./dotenvx-converter.py .env.stg --env stg \
  --secret-patterns "TOKEN,KEY,PASS,CRED,PRIVATE"
```

### Skip trufflehog scan

```bash
# For test files or when trufflehog isn't needed
./dotenvx-converter.py .env.stg --env stg --skip-detector
```

### Need to skip encryption (testing)

```bash
# Just generate hashes, don't encrypt
./dotenvx-converter.py .env.stg --env stg --skip-encryption
```

## Security Checklist

- [ ] `trufflehog` is installed for secret detection
- [ ] `.env.keys.prd` is in `.gitignore`
- [ ] `.env.keys.prd` is stored as GitHub Secret `DOTENV_KEYS_PRD`
- [ ] `.env.keys.stg` is committed (developers need it)
- [ ] All `.bak.*` files are in `.gitignore`
- [ ] CI/CD workflow cleans up `.env.keys.prd` after use
- [ ] Production key is never in git history (`git log --all -p | grep "env.keys.prd"`)
- [ ] Real production secrets are rotated after initial encryption

## References

- [Full Documentation](./DOTENVX_CONVERTER_README.md)
- [dotenvx Official Docs](https://dotenvx.com/)
- [Example .gitignore](./.gitignore.example)
