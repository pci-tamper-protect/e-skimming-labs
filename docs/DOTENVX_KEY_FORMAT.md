# dotenvx Key File Format

## Correct Format for `.env.keys.stg`

The `.env.keys.stg` file should contain **plaintext private keys**, NOT encrypted values.

### ✅ Correct Format (Verified Working)

```bash
#/-------------------[DOTENV_PUBLIC_KEY]--------------------/
#/            public-key encryption for .env files          /
#/       [how it works](https://dotenvx.com/encryption)     /
#/----------------------------------------------------------/
DOTENV_PUBLIC_KEY_KEYS_STG="03ed68a7f1bb4784d52c0df7b8dc6ba3f4db7120b4a4f5625b1a68045a03436a01"

# .env.keys.stg
#/------------------!DOTENV_PRIVATE_KEYS!-------------------/
#/ private decryption keys. DO NOT commit to source control /
#/     [how it works](https://dotenvx.com/encryption)       /
#/----------------------------------------------------------/

DOTENV_PRIVATE_KEY_STG_SECRETS=54b219bfe2faa52b41102d44036ff49712952473d6092360ff5062d09b30e9a4
```

**Key Points:**
- `DOTENV_PRIVATE_KEY_STG_SECRETS` should be a **plain hex string** (no quotes needed, but quotes are OK)
- **NO `encrypted:` prefix** - the private key itself is never encrypted
- The value should be a long hexadecimal string (typically 64+ characters)
- ✅ **Verified**: This format works correctly with `dotenvx get -f .env.stg -fk .env.keys.stg`

**Note:** Any stray lines with `value="encrypted:..."` in the file are harmless comments/leftovers and don't affect functionality.

## Variable Naming: `DOTENV_PRIVATE_KEY_STG_SECRETS` vs `DOTENV_PRIVATE_KEY_STG`

### Current Usage

The entrypoint scripts in `e-skimming-labs` use `DOTENV_PRIVATE_KEY_STG_SECRETS`:

```bash
# deploy/shared-components/home-index-service/entrypoint.sh
DOTENV_PRIVATE_KEY=$(grep -E "^DOTENV_PRIVATE_KEY_STG_SECRETS=" /etc/secrets/dotenvx-key | cut -d'=' -f2)
```

### Standard dotenvx Format

By default, `dotenvx keys -fk .env.keys.stg` generates:
- `DOTENV_PUBLIC_KEY_KEYS_STG` (public key)
- `DOTENV_PRIVATE_KEY_STG` (private key) - **Note: No `_SECRETS` suffix**

### Recommendation

**Keep using `DOTENV_PRIVATE_KEY_STG_SECRETS`** because:
1. It's already used in the entrypoint scripts
2. It's more descriptive (indicates it's for secrets)
3. It avoids confusion with other potential `DOTENV_PRIVATE_KEY_STG` variables

**To fix the key file format:**

1. If you have the correct private key (plain hex string), update `.env.keys.stg`:
   ```bash
   # Remove the encrypted value and add the correct private key
   DOTENV_PRIVATE_KEY_STG_SECRETS="496b6d9a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8"
   ```

2. If you need to regenerate the key file:
   ```bash
   # Generate new keys
   dotenvx keys -fk .env.keys.stg
   
   # Then manually rename the private key variable
   sed -i.bak 's/^DOTENV_PRIVATE_KEY_STG=/DOTENV_PRIVATE_KEY_STG_SECRETS=/' .env.keys.stg
   ```

3. Verify the format:
   ```bash
   # Should show a plain hex string (no "encrypted:" prefix)
   grep "DOTENV_PRIVATE_KEY_STG_SECRETS" .env.keys.stg
   ```

## How to Get the Correct Private Key

If you've lost the correct private key:

1. **Check git history** (if the key file was committed):
   ```bash
   git log --all --full-history -- .env.keys.stg
   git show <commit-hash>:.env.keys.stg
   ```

2. **Check dotenvx-ops** (if you're using it):
   ```bash
   dotenvx-ops pull .env.keys.stg
   ```

3. **Check GitHub Secrets** (for CI/CD):
   ```bash
   gh secret get DOTENV_KEYS_STG --repo <your-repo> > .env.keys.stg
   ```

4. **Regenerate** (⚠️ This will make all existing encrypted values unreadable):
   ```bash
   dotenvx keys -fk .env.keys.stg
   # Then re-encrypt all values with the new key
   ```

## Testing the Key File

```bash
# Test if the key file works
dotenvx get FIREBASE_API_KEY -f .env.stg -fk .env.keys.stg

# If you get [WRONG_PRIVATE_KEY] error, the key is incorrect
# If you get a value, the key is correct
```
