# Versioning Policy

This document defines the versioning policy for dependencies and GitHub Actions used in this repository.

## General Policy

**Stay at latest - 1 version unless latest-1 has EOL < 1 year.**

### Policy Details

- **Latest - 1**: Use the second-most-recent major/minor version
- **EOL Exception**: Upgrade to latest if latest-1 has an End-of-Life (EOL) date less than 1 year away
- **Security Exception**: Upgrade to latest if it contains critical security fixes

### Examples

- If latest is `v8` and latest-1 is `v7`:
  - ✅ Use `v7` (latest - 1)
  - ❌ Don't upgrade to `v8` unless v7 has EOL < 1 year or v8 has critical security fixes

- If latest is `v3.2.0` and latest-1 is `v3.1.0`:
  - ✅ Use `v3.1.0` (latest - 1)
  - ❌ Don't upgrade to `v3.2.0` unless v3.1.0 has EOL < 1 year

## Dependabot Configuration

Dependabot is configured to automatically create PRs for dependency updates. However, **Dependabot PRs must be reviewed against this policy** before merging.

### Dependabot PR Review Checklist

When reviewing Dependabot PRs, check:

1. ✅ Does the PR upgrade to latest - 1? → **Approve**
2. ❌ Does the PR upgrade to latest? → **Check EOL status**
   - If latest-1 has EOL < 1 year → **Approve**
   - If latest-1 has no EOL or EOL > 1 year → **Reject** (comment with policy reference)
3. 🔒 Does the PR include critical security fixes? → **Approve** (even if it's latest)

### Dependabot Ignore Rules

For dependencies that should not be auto-updated, add ignore rules to `.github/dependabot.yml`:

```yaml
ignore:
  - dependency-name: "actions/github-script"
    update-types: ["version-update:semver-major"]  # Ignore major version updates
```

## GitHub Actions

GitHub Actions follow the same policy:

- **Current**: Use latest - 1 version
- **Example**: If `actions/checkout@v4` is latest and `actions/checkout@v3` is latest-1, use `v3`
- **Exception**: Upgrade to latest if latest-1 has EOL < 1 year

## Checking Version Status

To check if a dependency complies with this policy:

1. Find the latest version: Check GitHub releases or package registry
2. Identify latest - 1: Second-most-recent major/minor version
3. Check EOL status: Review package documentation or release notes
4. Verify current usage: Check `dependabot.yml` and workflow files

## Policy Exceptions

Exceptions to this policy may be made for:

1. **Security**: Critical security vulnerabilities in latest version
2. **Features**: Required new features only available in latest
3. **EOL**: Latest-1 approaching end-of-life (< 1 year remaining)
4. **Breaking Changes**: Latest-1 has breaking changes that need to be addressed

All exceptions should be documented in the PR description.

## Related Documentation

- [Dependabot Configuration](.github/dependabot.yml)
- [Branch Protection Rules](.github/BRANCH_PROTECTION.md)
- [Merge Order Guidelines](.github/MERGE_ORDER.md)

