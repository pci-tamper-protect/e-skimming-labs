# Sharing .env.keys Files with dotenvx-ops

When you have a `dotenvx-ops` subscription, you can securely share `.env.keys.*` files with your team without committing them to git.

## Setup

1. **Install dotenvx-ops** (if not already installed):
   ```bash
   npm install -g @dotenvx/dotenvx-ops
   ```

2. **Login to your dotenvx-ops account**:
   ```bash
   dotenvx-ops login
   ```

3. **Sync your project** (if not already synced):
   ```bash
   cd /path/to/e-skimming-labs
   dotenvx-ops sync
   ```

## Sharing .env.keys Files

### Push .env.keys to dotenvx-ops

To share your `.env.keys.stg` file with the team:

```bash
# Push the staging keys file
dotenvx-ops push .env.keys.stg

# Push the production keys file
dotenvx-ops push .env.keys.prd
```

This uploads the private key file to dotenvx-ops cloud storage, where team members with access can pull it.

### Pull .env.keys from dotenvx-ops

Team members can pull the shared keys:

```bash
# Pull staging keys
dotenvx-ops pull .env.keys.stg

# Pull production keys
dotenvx-ops pull .env.keys.prd
```

### Sync All Files

To sync all `.env` and `.env.keys` files:

```bash
# Sync all files (push local changes, pull remote changes)
dotenvx-ops sync

# Or sync specific environment
dotenvx-ops sync --env stg
dotenvx-ops sync --env prd
```

## Workflow

### Initial Setup (First Time)

1. **Team lead uploads keys**:
   ```bash
   dotenvx-ops push .env.keys.stg
   dotenvx-ops push .env.keys.prd
   ```

2. **Team members pull keys**:
   ```bash
   dotenvx-ops pull .env.keys.stg
   dotenvx-ops pull .env.keys.prd
   ```

### Daily Workflow

1. **Before starting work** (pull latest):
   ```bash
   dotenvx-ops pull .env.keys.stg
   ```

2. **After updating keys** (push changes):
   ```bash
   dotenvx-ops push .env.keys.stg
   ```

3. **Or use sync** (bidirectional):
   ```bash
   dotenvx-ops sync
   ```

## Security Notes

- ✅ `.env.keys.*` files are encrypted in transit and at rest
- ✅ Only team members with access to your dotenvx-ops subscription can pull keys
- ✅ Keys are never committed to git (should be in `.gitignore`)
- ✅ Each environment (stg/prd) can have different access controls

## Troubleshooting

### Check if project is linked:
```bash
dotenvx-ops status
```

### List available files:
```bash
dotenvx-ops list
```

### Check subscription status:
```bash
dotenvx-ops whoami
```

## Integration with Existing Workflow

The `.env.keys.*` files pulled from dotenvx-ops work exactly the same as local files:

- `dotenvx encrypt` uses them automatically
- `dotenvx decrypt` uses them automatically
- `dotenvx run` uses them automatically
- All existing scripts continue to work

No changes needed to your existing dotenvx workflows!

