# Lab 2 DOM Skimming – Refactor Plan

## Your analysis: validated

Reviewing the repo confirms:

1. **Malicious code is not in the vulnerable-site container**
   - `vulnerable-site/Dockerfile` only does `COPY . /usr/share/nginx/html/` (vulnerable-site content only). Nothing from `../malicious-code/` is copied.
   - `banking.html` loads only `js/banking.js`; there is no reference to `dom-monitor.js`, `form-overlay.js`, or `shadow-skimmer.js`.
   - The three variant files (`dom-monitor.js`, `form-overlay.js`, `shadow-skimmer.js`) live in `02-dom-skimming/malicious-code/` and are never added to any image that serves the banking site. So the lab cannot demonstrate an injected skimmer when using the containerized site alone.

2. **C2 is at lab root, not a sibling of vulnerable-site**
   - Lab 2 C2 is built from `./labs/02-dom-skimming` with `Dockerfile.c2`, which copies `malicious-code/c2-server.js` and `malicious-code/c2-server/dashboard.html` into the C2 image. There is no dedicated `c2-server/` sibling to `vulnerable-site/` (unlike Lab 1, where `malicious-code/c2-server/` has its own Dockerfile).

3. **Combined image (02-dom-skimming/Dockerfile) also omits skimmer variants**
   - That Dockerfile copies `vulnerable-site/` to nginx html and copies only C2 files into `/app/c2-server`. The three skimmer `.js` files are never copied into the image, so even the combined setup does not serve or inject them.

4. **Tests work only by injecting from the host**
   - Tests use `page.addScriptTag({ path: './malicious-code/dom-monitor.js' })`, i.e. a **filesystem path** on the test runner. So the skimmer runs only because Playwright injects it from the host; the served page itself never loads any variant. That’s why “the lab doesn’t work” when you just open the vulnerable site in a browser.

---

## Agreed direction

- **c2-server as sibling to vulnerable-site**  
  Mirror Lab 1: have `02-dom-skimming/c2-server/` (sibling of `vulnerable-site/`) with its own Dockerfile, `server.js`, `dashboard.html`, `package.json`. Build lab2-c2-server from that directory.

- **malicious-code as subfolder of vulnerable-site**  
  Move the three skimmer variants into `vulnerable-site/malicious-code/` (e.g. `dom-monitor.js`, `form-overlay.js`, `shadow-skimmer.js`) so they are part of the vulnerable-site build context and get copied into the nginx root. Then the container can serve them and/or inject one based on a variant selector.

- **User-selectable variant (default: dom-monitor)**  
  Introduce a variable (e.g. `LAB2_VARIANT`, default `dom-monitor`) that chooses which of the three scripts is “active” (injected or served as the single skimmer). Prefer runtime selection via env so the same image can switch variants without rebuild.

---

## Proposed changes (concrete)

### 1. Folder structure (target)

```
02-dom-skimming/
├── c2-server/                    # NEW: sibling to vulnerable-site (like Lab 1)
│   ├── Dockerfile
│   ├── package.json
│   ├── server.js                 # from current malicious-code/c2-server.js
│   └── dashboard.html            # from current malicious-code/c2-server/dashboard.html
├── vulnerable-site/
│   ├── malicious-code/           # NEW: subfolder of vulnerable-site
│   │   ├── dom-monitor.js        # moved from 02-dom-skimming/malicious-code/
│   │   ├── form-overlay.js
│   │   └── shadow-skimmer.js
│   ├── banking.html
│   ├── js/
│   │   ├── banking.js
│   │   └── skimmer.js            # optional: symlink or copy of selected variant (see below)
│   ├── Dockerfile                # updated
│   ├── nginx-env.conf
│   └── ...
├── malicious-code/               # DEPRECATED / REMOVED after move
│   ├── c2-server.js             → moved to c2-server/server.js
│   ├── c2-server/dashboard.html  → moved to c2-server/dashboard.html
│   ├── dom-monitor.js           → moved to vulnerable-site/malicious-code/
│   ├── form-overlay.js          → moved to vulnerable-site/malicious-code/
│   └── shadow-skimmer.js        → moved to vulnerable-site/malicious-code/
├── Dockerfile                    # combined image; update to use new layout
├── Dockerfile.c2                 # remove; C2 built from c2-server/
└── ...
```

- **c2-server/**  
  New directory; contents taken from current `malicious-code/c2-server.js` and `malicious-code/c2-server/dashboard.html`, plus a `package.json` and a Dockerfile that builds a Node image (same idea as Lab 1’s `malicious-code/c2-server`).

- **vulnerable-site/malicious-code/**  
  New directory; hold the three variant scripts only. No C2 code here.

- **malicious-code/** at lab root  
  After moving files, it can be removed or kept only for backwards compatibility (e.g. symlinks or README pointing at the new locations). Prefer removing it to avoid confusion.

### 2. Vulnerable-site Dockerfile and variant selection

- **Copy malicious-code into the image**
  - In `vulnerable-site/Dockerfile`, ensure `COPY . /usr/share/nginx/html/` includes `vulnerable-site/malicious-code/`, so the image contains e.g. `/usr/share/nginx/html/malicious-code/dom-monitor.js`, `form-overlay.js`, `shadow-skimmer.js`.

- **Single “active” skimmer via env**
  - **LAB2_VARIANT** (runtime): Override for a given run (e.g. `docker run -e LAB2_VARIANT=form-overlay` or `LAB2_VARIANT=shadow-skimmer docker-compose up`).
  - **LAB2_VARIANT_DEFAULT** (config): Default when LAB2_VARIANT is not set (e.g. in `.env` or compose env). Fallback: `dom-monitor`.
  - Entrypoint uses: `VARIANT="${LAB2_VARIANT:-${LAB2_VARIANT_DEFAULT:-dom-monitor}}"`, then copies `malicious-code/${VARIANT}.js` to `js/skimmer.js` and execs nginx.
  - So one URL always: `js/skimmer.js`. Same image can serve any variant.

- **banking.html**
  - Add one script tag that loads the “active” skimmer, e.g. `<script src="js/skimmer.js"></script>` (after existing scripts). No need to reference the variant name in HTML; the entrypoint prepares `js/skimmer.js`.

- **docker-compose**
  - For `lab2-vulnerable-site`, pass `LAB2_VARIANT` and `LAB2_VARIANT_DEFAULT` so the default is configurable and runtime override works. Build context remains `./labs/02-dom-skimming/vulnerable-site`.

### 3. C2 server as sibling

- **Create `02-dom-skimming/c2-server/`**
  - `server.js`: current `malicious-code/c2-server.js` (rename and adjust paths if needed).
  - `dashboard.html`: current `malicious-code/c2-server/dashboard.html`.
  - `package.json`: same dependencies as current C2 (express, cors, etc.).
  - `Dockerfile`: multi-stage or single-stage Node image that copies these files and runs `node server.js`; expose port 3000 (or PORT); create `stolen-data` if needed.

- **docker-compose**
  - `lab2-c2-server`:
    - `build.context`: `./labs/02-dom-skimming/c2-server`
    - `build.dockerfile`: `Dockerfile`
  - Remove use of `Dockerfile.c2` and lab-root context for C2.
  - Keep volume for stolen data, e.g. `./labs/02-dom-skimming/c2-server/stolen-data:/app/stolen-data` (or a shared path under `02-dom-skimming`).

### 4. Combined image (02-dom-skimming/Dockerfile)

- If you keep the combined “all-in-one” image:
  - Build C2 from `./c2-server` (or copy from a built stage).
  - Copy `vulnerable-site/` (including `vulnerable-site/malicious-code/`) into nginx html.
  - `init.sh` (or equivalent) can: start C2 in background; run the same entrypoint logic for `LAB2_VARIANT` → `js/skimmer.js`; then start nginx. So the combined image also respects `LAB2_VARIANT` and serves one injected variant.

### 5. Tests

- Tests currently use `path: './malicious-code/dom-monitor.js'` (and similar for form-overlay, shadow-skimmer). That path is relative to the test runner’s cwd (typically `02-dom-skimming` or `02-dom-skimming/test`).
- **After move:** Point tests at the new location. For example, from `02-dom-skimming/test/tests/`, use a path relative to the lab root, e.g. `path: path.join(__dirname, '../../vulnerable-site/malicious-code/dom-monitor.js')` (or set a `LAB_ROOT` and use `LAB_ROOT/vulnerable-site/malicious-code/dom-monitor.js`). Update all `addScriptTag` calls for the three variants similarly.
- Optional: add a small helper in test config that resolves `malicious-code/<variant>.js` to `vulnerable-site/malicious-code/<variant>.js` so tests stay robust if you move again.

### 6. Cleanup

- Remove or repurpose `Dockerfile.c2` once C2 builds from `c2-server/`.
- Remove `02-dom-skimming/malicious-code/` after moving the three `.js` files and C2 files, or document that it’s deprecated and redirect to `c2-server/` and `vulnerable-site/malicious-code/`.
- Ensure `package.json` and any shared deps at lab root (e.g. for C2) are not broken; C2’s `package.json` should live under `c2-server/`.

---

## Summary

| Item | Current | Proposed |
|------|--------|----------|
| C2 location | Built from lab root via Dockerfile.c2, files in malicious-code/ | Dedicated `02-dom-skimming/c2-server/` (sibling to vulnerable-site), own Dockerfile |
| Skimmer variants | In `02-dom-skimming/malicious-code/`, not in any image | In `vulnerable-site/malicious-code/`, copied into vulnerable-site image |
| Injection | None; banking.html has no skimmer script | Entrypoint sets `js/skimmer.js` from selected variant; banking.html loads `js/skimmer.js` |
| Variant selection | N/A | Env `LAB2_VARIANT` (default `dom-monitor`) |
| Tests | `path: './malicious-code/...'` (lab root) | `path` to `vulnerable-site/malicious-code/...` (or helper) |

This refactor makes the vulnerable site container own and serve the malicious variants, uses a single env-driven “active” variant (default dom-monitor), and aligns Lab 2 with the Lab 1 pattern of a dedicated c2-server sibling plus clear separation between site content and malicious scripts.
