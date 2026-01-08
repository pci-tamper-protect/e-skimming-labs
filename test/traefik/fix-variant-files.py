#!/usr/bin/env python3
"""
Batch fix environment-aware routing in variant checkout files
"""

import os
import re
from pathlib import Path

# Variant directories and their base paths
VARIANTS = {
    'event-listener-variant': '/lab1/variants/event-listener/',
    'obfuscated-base64': '/lab1/variants/obfuscated/',
    'websocket-exfil': '/lab1/variants/websocket/'
}

# Pattern to find and replace
ENV_AWARE_PATTERN = re.compile(
    r'// Environment-aware URL configuration.*?\)\)\s*\)\s*</script>',
    re.DOTALL
)

REPLACEMENT = '''      // Update C2 dashboard links with relative paths
      ;(function () {
        const c2DashboardLinks = document.querySelectorAll('.c2-dashboard-link')
        c2DashboardLinks.forEach(link => {
          link.href = '/lab1/c2'
        })
      })()
    </script>'''

def fix_file(filepath, base_href):
    """Fix a single file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        original = content

        # Add base tag if not present
        if '<base href' not in content:
            content = re.sub(
                r'(<title>[^<]+</title>)',
                r'\1\n    <base href="' + base_href + '" />',
                content,
                count=1
            )

        # Replace environment-aware code
        content = ENV_AWARE_PATTERN.sub(REPLACEMENT, content)

        # Also fix any remaining hostname checks in cache busting
        content = re.sub(
            r'const hostname = window\.location\.hostname\s+const isLocal = hostname === [^\n]+\s+if \(isLocal\) \{',
            r'// Cache busting - always enabled',
            content
        )

        # Remove conditional script loading
        content = re.sub(
            r'if \(isLocal\) \{[^}]+script\.src = [^;]+;\s+script\.id[^}]+else \{[^}]+script\.src[^}]+',
            r'const timestamp = Date.now()\n          const script = document.createElement(\'script\')\n          script.src = \'js/checkout-compromised.js?v=\' + timestamp\n          script.id = \'main-js\'\n          document.body.appendChild(script)',
            content,
            flags=re.DOTALL
        )

        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error fixing {filepath}: {e}")
        return False

def main():
    base_dir = Path('labs/01-basic-magecart/variants')

    for variant_name, base_href in VARIANTS.items():
        variant_dir = base_dir / variant_name / 'vulnerable-site'

        if not variant_dir.exists():
            continue

        for file in ['checkout.html', 'checkout_separate.html', 'checkout_single.html']:
            filepath = variant_dir / file
            if filepath.exists():
                if fix_file(filepath, base_href):
                    print(f"✅ Fixed: {filepath}")
                else:
                    print(f"⚪ No changes: {filepath}")

if __name__ == '__main__':
    main()
