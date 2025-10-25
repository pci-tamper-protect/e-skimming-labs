import js from '@eslint/js'
import globals from 'globals'

export default [
  { ignores: ['dist', 'node_modules', 'test-results', 'playwright-report'] },
  {
    files: ['**/*.{js,jsx}'],
    languageOptions: {
      ecmaVersion: 2020,
      globals: {
        ...globals.browser,
        ...globals.node,
        ...globals.jest,
        // Chrome extension globals
        chrome: 'readonly',
        browser: 'readonly'
      },
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module'
      }
    },
    rules: {
      ...js.configs.recommended.rules,
      'no-unused-vars': ['error', { varsIgnorePattern: '^[A-Z_]' }],
      'no-console': 'off', // Allow console in lab/demo code
      'no-debugger': 'error',
      'no-alert': 'off', // Allow alert in lab/demo code
      'no-eval': 'error',
      'no-implied-eval': 'error',
      'no-new-func': 'error',
      'no-script-url': 'error',
      eqeqeq: ['error', 'always'],
      curly: ['error', 'all'],
      'brace-style': ['error', '1tbs', { allowSingleLine: true }],
      camelcase: ['error', { properties: 'never' }],
      'no-var': 'error',
      'prefer-const': 'error',
      'prefer-arrow-callback': 'error',
      'arrow-spacing': 'error',
      'no-undef': 'error'
    }
  },
  {
    files: ['**/*.test.js', '**/*.spec.js'],
    languageOptions: {
      globals: {
        ...globals.jest
      }
    },
    rules: {
      'no-console': 'off',
      'no-unused-vars': 'off', // Test files may have unused vars for assertions
      'prefer-const': 'off' // Test files may use let for reassignment
    }
  },
  {
    files: ['**/playwright.config.js'],
    rules: {
      'no-console': 'off'
    }
  },
  {
    files: [
      '**/malicious-code/**/*.js',
      '**/vulnerable-site/**/*.js',
      '**/legitimate-extension/**/*.js',
      '**/malicious-extension/**/*.js',
      '**/test-automation.js',
      '**/extension-data-server.js',
      '**/manual-test.js',
      '**/test/**/*.js'
    ],
    rules: {
      'no-console': 'off',
      'no-alert': 'off',
      'no-eval': 'off', // May be needed for obfuscated code
      'no-implied-eval': 'off',
      'no-new-func': 'off',
      'prefer-const': 'off', // May need var for compatibility
      'no-var': 'off',
      'no-unused-vars': 'off', // Lab code may have unused vars for demo purposes
      'no-undef': 'off', // Lab code may reference undefined functions
      'curly': 'off', // Lab code may use single-line if statements
      'brace-style': 'off', // Lab code may use different brace styles
      'prefer-arrow-callback': 'off', // Lab code may use function expressions
      'no-debugger': 'off', // Lab code may contain debugger statements
      'no-useless-escape': 'off', // Lab code may have intentional escapes
      'no-case-declarations': 'off' // Lab code may declare vars in case blocks
    }
  }
]
