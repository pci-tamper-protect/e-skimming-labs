# Traefik Design Review Tools

Tools for reviewing Traefik deployments to ensure they follow design principles.

## check-routing-violations.py

Scans JavaScript and HTML files for patterns that violate the Traefik design principle:

> **"Traefik handles ALL routing. Services should be simple and not know about routing."**

### What It Detects

The script identifies these violation patterns:

1. **Hostname Checks** (HIGH severity)
   - `window.location.hostname`
   - `location.hostname`
   - Direct hostname comparisons

2. **Environment Detection** (MEDIUM severity)
   - Checking for `localhost`, `127.0.0.1`, staging/production domains
   - Variables like `isLocal`, `isStaging`, `isProduction`

3. **URL Construction** (MEDIUM/HIGH severity)
   - `baseUrl = ...`
   - `homeUrl = ...`
   - `c2Url = ...`
   - Any variable ending in `Url` being constructed

4. **Hardcoded Domains** (MEDIUM severity)
   - `https://labs.stg.pcioasis.com`
   - `https://labs.pcioasis.com`
   - `http://localhost:8080`
   - Cloud Run URLs

5. **Conditional BaseURL** (HIGH severity)
   - `if (hostname === ...) { baseUrl = ... }`
   - Ternary operators with hostname checks

6. **Environment-Aware Comments** (LOW severity)
   - Comments mentioning "Environment-aware URL"

### Usage

```bash
# Check current directory
python3 check-routing-violations.py .

# Check specific directory
python3 check-routing-violations.py labs/

# Exclude directories
python3 check-routing-violations.py . --exclude node_modules --exclude .git

# JSON output
python3 check-routing-violations.py . --format json > violations.json

# Exit with error code if violations found (useful for CI/CD)
python3 check-routing-violations.py . --exit-code
```

### Output Format

**Text Report:**
- Summary statistics
- Violations grouped by file
- Line numbers and context
- Severity indicators (🔴 HIGH, 🟡 MEDIUM, 🟢 LOW)

**JSON Report:**
- Machine-readable format
- All violation details
- Suitable for automated processing

### Example Output

```
================================================================================
ROUTING VIOLATIONS REPORT
================================================================================

Total violations found: 936
Files affected: 54

Summary by Type:
  url_construction               291
  hostname_check                 224
  env_detection                  192
  hardcoded_domain               158
  environment_aware_comment       48
  conditional_baseurl             23

Summary by Severity:
  HIGH       247
  MEDIUM     641
  LOW         48

================================================================================

📄 labs/01-basic-magecart/vulnerable-site/index.html
--------------------------------------------------------------------------------

🔴 Line 108: hostname_check
   Pattern: window.location.hostname
   Context:
   105 |     <script>
   106 |       // Environment-aware URL configuration with uniform path-based routing
   107 |       ;(function () {
   108 |         const hostname = window.location.hostname
   109 |         const port = window.location.port
   110 |         const protocol = window.location.protocol
```

### Integration with CI/CD

Add to GitHub Actions workflow:

```yaml
- name: Check for routing violations
  run: |
    python3 test/traefik/check-routing-violations.py . --exit-code
```

### Correct Pattern

**❌ WRONG (violation):**
```javascript
const hostname = window.location.hostname
let baseUrl
if (hostname === 'localhost') {
  baseUrl = 'http://localhost:8080'
} else if (hostname === 'labs.stg.pcioasis.com') {
  baseUrl = ''
} else {
  baseUrl = 'https://labs.pcioasis.com'
}
const homeUrl = baseUrl + '/'
```

**✅ CORRECT (no violation):**
```html
<base href="/lab1/" />
<a href="/">Back to Labs</a>
<a href="/lab1/c2">C2 Dashboard</a>
<a href="/lab-01-writeup">Writeup</a>
```

Or minimal JavaScript:
```javascript
document.querySelector('.back-button').href = '/'
document.querySelector('.c2-button').href = '/lab1/c2'
```

### Requirements

- Python 3.6+
- No external dependencies (uses only standard library)

---

**See Also:**
- [docs/ROUTING_REFACTOR_PLAN.md](../../docs/ROUTING_REFACTOR_PLAN.md) - Plan for removing violations
- [docs/TRAEFIK-ARCHITECTURE.md](../../docs/TRAEFIK-ARCHITECTURE.md) - Traefik design principles
