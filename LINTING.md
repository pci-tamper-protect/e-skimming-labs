# Linting Configuration

This repository uses consistent linting rules that match the e-skimming-app
conventions.

## Configuration Files

- **`.editorconfig`** - Basic editor settings (line endings, indentation)
- **`eslint.config.js`** - ESLint configuration using modern flat config
- **`.prettierrc.json`** - Prettier code formatting rules
- **`.golangci.yml`** - Go linting configuration
- **`.pre-commit-config.yaml`** - Pre-commit hooks for automated linting
- **`.vscode/settings.json`** - Cursor/VS Code settings for automatic formatting

## Key Conventions (matching e-skimming-app)

### JavaScript/TypeScript

- **No semicolons** (`semi: false`)
- **Single quotes** (`singleQuote: true`)
- **2-space indentation**
- **LF line endings**
- **No trailing commas**

### Go

- **Tab indentation** (4 spaces)
- **Standard Go formatting** via gofmt/goimports

## Usage

### Install Dependencies

```bash
npm install
```

### Run Linting

```bash
# JavaScript/TypeScript
npm run lint

# Fix auto-fixable issues
npm run lint:fix

# Format code
npm run format

# Check formatting
npm run format:check

# Go linting
npm run lint:go

# All linting
npm run lint:all
```

### Pre-commit Hooks

```bash
# Install pre-commit hooks
npm run pre-commit:install

# Run all hooks manually
npm run pre-commit:run
```

## Special Rules for Lab Code

The linting configuration includes special rules for lab/demo code:

- **Console statements allowed** - Lab code often needs console output
- **Alert statements allowed** - Demo code may use alerts
- **Relaxed rules for malicious code** - Obfuscated code may need `eval`, `var`,
  etc.

## Chrome Extension Support

Chrome extension globals (`chrome`, `browser`) are automatically recognized.

## Cursor Integration

The `.vscode/settings.json` file ensures Cursor automatically:

- Formats on save
- Fixes ESLint issues on save
- Uses Prettier for formatting
- Handles Go formatting with goimports

## Troubleshooting

### Common Issues

1. **Trailing newlines** - Fixed by EditorConfig and Prettier
2. **Mixed quotes** - Fixed by Prettier (single quotes)
3. **Missing semicolons** - Fixed by Prettier (no semicolons)
4. **Chrome undefined** - Fixed by ESLint globals configuration

### Manual Fixes

If automatic fixes don't work:

```bash
# Fix all auto-fixable issues
npm run lint:fix

# Format all files
npm run format
```

