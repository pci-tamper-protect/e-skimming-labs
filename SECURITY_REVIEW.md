# Security Review - E-Skimming Labs

**Date:** 2025-01-20  
**Scope:** All user inputs in lab servers (C2 servers and data collection endpoints)  
**Focus:** RCE (Remote Code Execution) and SSRF (Server-Side Request Forgery) vulnerabilities

## Executive Summary

A security review was conducted on all user input handling in the e-skimming labs. The review focused on identifying vulnerabilities that could allow attackers to:
- Execute arbitrary code on the server (RCE)
- Make server-side requests to internal/external resources (SSRF)
- Access arbitrary files on the filesystem (Path Traversal)

## Vulnerabilities Found

### 🔴 CRITICAL: Path Traversal Vulnerabilities

#### 1. Lab 2 C2 Server - `/attack/:filename` endpoint
**Location:** `labs/02-dom-skimming/malicious-code/c2-server.js:381-396`

**Vulnerability:**
```javascript
app.get('/attack/:filename', (req, res) => {
  const filename = req.params.filename
  const filepath = path.join(DATA_DIR, filename)  // ⚠️ No validation
  const data = JSON.parse(fs.readFileSync(filepath, 'utf8'))
  res.json(data)
})
```

**Risk:** An attacker can read arbitrary files by using path traversal sequences:
- `GET /attack/../../../etc/passwd`
- `GET /attack/../../../etc/shadow`
- `GET /attack/../../package.json`

**Impact:** HIGH - Can read sensitive system files, configuration files, or source code.

#### 2. Lab 2 C2 Server - `/analysis/:filename` endpoint
**Location:** `labs/02-dom-skimming/malicious-code/c2-server.js:399-414`

**Vulnerability:**
```javascript
app.get('/analysis/:filename', (req, res) => {
  const filename = req.params.filename
  const analysisPath = path.join(ANALYSIS_DIR, `analysis_${filename}`)  // ⚠️ No validation
  const analysis = JSON.parse(fs.readFileSync(analysisPath, 'utf8'))
  res.json(analysis)
})
```

**Risk:** Similar path traversal vulnerability, though slightly mitigated by the `analysis_` prefix.

**Impact:** MEDIUM-HIGH - Can read files outside the analysis directory.

#### 3. Lab 3 Extension Server - `/export/:date?` endpoint
**Location:** `labs/03-extension-hijacking/test-server/extension-data-server.js:481-499`

**Vulnerability:**
```javascript
app.get('/export/:date?', async (req, res) => {
  const date = req.params.date || new Date().toISOString().split('T')[0]
  const dataFile = path.join(stolenDataDir, `full-data-${date}.json`)  // ⚠️ No validation
  const data = await fs.readFile(dataFile, 'utf8')
  res.send(JSON.stringify(jsonData, null, 2))
})
```

**Risk:** An attacker can read arbitrary files by manipulating the date parameter:
- `GET /export/../../../etc/passwd`

**Impact:** HIGH - Can read sensitive system files.

### 🟡 MEDIUM: JSON Parsing on User Input

#### 4. Lab 1 C2 Server - Base64 Decode and Parse
**Location:** `labs/01-basic-magecart/malicious-code/c2-server/server.js:187-194`

**Vulnerability:**
```javascript
app.get('/collect', async (req, res) => {
  if (req.query.d) {
    const decoded = Buffer.from(req.query.d, 'base64').toString('utf8')
    const stolenData = JSON.parse(decoded)  // ⚠️ No validation
    // ... uses stolenData directly
  }
})
```

**Risk:** Prototype pollution if the parsed JSON contains `__proto__` or `constructor.prototype` properties that are later used unsafely. However, the code only uses the data for logging, so the risk is lower.

**Impact:** LOW-MEDIUM - Potential prototype pollution, but limited impact in current usage.

## Vulnerabilities NOT Found

### ✅ No RCE Vulnerabilities
- No use of `eval()`, `exec()`, `spawn()`, `execFile()`, or `child_process` with user input
- No dynamic `require()` with user input
- No `new Function()` with user input
- No template injection vulnerabilities

### ✅ No SSRF Vulnerabilities
- No `fetch()`, `axios()`, `http.get()`, or `https.get()` calls with user-controlled URLs
- All network requests use hardcoded or server-controlled URLs

### ✅ Safe File Operations (Most)
- Lab 1 C2 Server: File paths are generated server-side (timestamp-based)
- Most file reads are from server-controlled directory listings

## Recommendations

### Immediate Fixes Required

1. **Fix Path Traversal in Lab 2 `/attack/:filename`**
   - Validate filename to only allow alphanumeric, hyphens, and underscores
   - Use `path.basename()` to strip directory separators
   - Verify file exists in DATA_DIR using `path.resolve()` and check it's within the directory

2. **Fix Path Traversal in Lab 2 `/analysis/:filename`**
   - Same validation as above
   - Ensure filename doesn't contain path separators

3. **Fix Path Traversal in Lab 3 `/export/:date?`**
   - Validate date parameter to match ISO date format (YYYY-MM-DD)
   - Reject any date containing path separators or special characters

4. **Harden JSON Parsing (Lab 1)**
   - Consider using a JSON parser that doesn't support prototype pollution
   - Or sanitize the parsed object to remove dangerous properties

## Implementation

See the fixes applied in the following files:
- `labs/02-dom-skimming/malicious-code/c2-server.js`
- `labs/03-extension-hijacking/test-server/extension-data-server.js`
- `labs/01-basic-magecart/malicious-code/c2-server/server.js` (if needed)

## Testing

After fixes are applied, test with:
- `GET /attack/../../../etc/passwd` (should fail)
- `GET /attack/..%2F..%2F..%2Fetc%2Fpasswd` (URL-encoded, should fail)
- `GET /export/../../../etc/passwd` (should fail)
- `GET /export/2025-01-20` (should succeed)

## Conclusion

The labs are generally secure against RCE and SSRF attacks. However, **path traversal vulnerabilities were found in 3 endpoints** that could allow reading arbitrary files. These have been fixed with proper input validation and path resolution checks.

**Overall Security Posture:** 🟢 SECURE - All identified vulnerabilities have been patched.

## Fixes Applied

### ✅ Lab 2 C2 Server - `/attack/:filename` and `/analysis/:filename`
- Added filename validation (alphanumeric, hyphens, underscores, dots only)
- Added explicit check for `..` sequences
- Used `path.basename()` to strip directory separators
- Added path resolution check to ensure file is within allowed directory

### ✅ Lab 3 Extension Server - `/export/:date?`
- Added date format validation (YYYY-MM-DD only)
- Added checks for path traversal sequences (`..`, `/`, `\`)
- Used `path.basename()` to strip directory separators
- Added path resolution check to ensure file is within allowed directory

### ✅ Lab 1 C2 Server - `/collect` (GET)
- Added prototype pollution protection
- Sanitize parsed JSON by removing dangerous properties
- Create clean object copy without prototype pollution

## Additional Security Notes

- **POST /clear endpoints**: Safe - only deletes files from controlled directories using `readdirSync()` which returns filenames only
- **All file writes**: Safe - use server-generated filenames (timestamp-based)
- **All file reads from directory listings**: Safe - filenames come from `readdirSync()`, not user input

