# Obfuscated Base64 Variant

This variant demonstrates the same e-skimming attack as the base lab, but with **Base64 obfuscation** techniques commonly used by Magecart groups.

## Key Differences from Base Lab

### Obfuscation Techniques Applied
1. **Base64 Encoding**: Critical strings (URLs, function names) are Base64 encoded
2. **String Concatenation**: Variables split across multiple concatenated strings
3. **Variable Name Mangling**: Short, meaningless variable names (a, b, c, etc.)
4. **Execution Delay**: Random delays to evade detection timing
5. **Anti-Debug Checks**: Basic detection of developer tools

### What Stays the Same
- **Functionality**: Identical form field extraction and POST exfiltration
- **Target Elements**: Same CSS selectors and form fields
- **C2 Communication**: Same HTTP POST to localhost:3000/collect
- **Data Structure**: Identical JSON payload structure

## ML Training Value

This variant tests whether detection models can:
- **Recognize obfuscated patterns** vs clear text implementations
- **Detect Base64 encoded strings** containing suspicious URLs or keywords
- **Identify string concatenation patterns** used to hide malicious intent
- **Spot anti-debugging code** commonly found in skimmers
- **Generalize across syntactic variations** of the same attack

## Detection Signatures

Expected detection patterns:
- Multiple Base64 `atob()` calls
- String concatenation patterns: `"he"+"llo"`
- Eval-like dynamic code execution
- DevTools detection checks
- Suspicious timing delays

## Usage

1. **Copy vulnerable site files**: `cp -r ../../vulnerable-site/* ./vulnerable-site/`
2. **Replace skimmer**: Use `checkout-compromised.js` from this variant
3. **Start C2 server**: Use same malicious-code infrastructure as base lab
4. **Run tests**: Playwright tests should still pass (same functionality)

This variant validates that obfuscation doesn't break functionality while providing training data for detection systems.