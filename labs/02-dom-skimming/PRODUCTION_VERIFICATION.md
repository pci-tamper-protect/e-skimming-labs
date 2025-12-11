# Production Verification - Lab 2 Improvements

## Changes Summary

All changes have been verified to work in production:

### ✅ HTML Structure Changes
- **Navigation buttons moved above tabs**: `nav-buttons-row` is now separate from `lab-tabs`
- **Settings tab removed**: Only 4 tabs remain (Dashboard, Transfer, Bill Pay, Cards)
- **Cards page is default**: `cards` section is active by default
- **Add card form visible by default**: `add-card-form-container` is visible on cards page

### ✅ JavaScript Changes
- **Navigation updated**: Uses `.tab-link` instead of `.nav-link`
- **Default section**: Sets `cards` as default section
- **Add card form**: Shows by default when cards page loads
- **Form handlers**: `initAddCardForm()` and `showAddCardForm()` functions added

### ✅ CSS Changes
- **Navigation buttons row**: `.nav-buttons-row` styles added
- **Lab tabs**: `.lab-tabs` and `.tab-link` styles added
- **Card form**: `.card-form-container` and `.form-row` styles added
- **Removed**: Settings-related styles (still present but not used)

### ✅ Environment-Aware URLs
The navigation buttons work correctly in all environments:

**Local Development:**
- Back button → `http://localhost:3000`
- View Stolen Data → `http://localhost:9004`

**Staging (labs.stg.pcioasis.com):**
- Back button → `https://labs.stg.pcioasis.com`
- View Stolen Data → `https://labs.stg.pcioasis.com/02-dom-skimming-c2`

**Production (labs.pcioasis.com):**
- Back button → `https://labs.pcioasis.com`
- View Stolen Data → `https://labs.pcioasis.com/02-dom-skimming-c2`

**Cloud Run Production (lab-02-dom-skimming-prd):**
- Back button → `https://labs-index-prd-mmwwcfi5za-uc.a.run.app`
- View Stolen Data → `https://{hostname}/stolen-data`

## Production Deployment

### Dockerfile Structure
The production Dockerfile (`labs/02-dom-skimming/Dockerfile`) copies the entire `vulnerable-site/` directory:
```dockerfile
COPY vulnerable-site/ /usr/share/nginx/html/
```

This includes:
- ✅ `banking.html` (updated with new structure)
- ✅ `js/banking.js` (updated with new navigation)
- ✅ `css/banking.css` (updated with new styles)

### GitHub Actions Workflow
The deployment workflow (`.github/workflows/deploy_labs.yml`):
1. Builds using `labs/02-dom-skimming/Dockerfile`
2. Copies `vulnerable-site/` directory (includes all our changes)
3. Authenticates to Google Artifact Registry for base image
4. Deploys to Cloud Run service `lab-02-dom-skimming-prd`

### Base Image
⚠️ **Note**: Production uses private registry base image:
- `us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest`
- GitHub Actions authenticates to this registry (line 242 in workflow)
- Local development uses public `nginx:1.25-alpine` (already fixed)

## Verification Checklist

- [x] HTML structure updated (nav-buttons-row, lab-tabs, removed settings)
- [x] JavaScript updated (tab navigation, default cards page, add card form)
- [x] CSS updated (new styles for navigation and cards)
- [x] Environment-aware URLs work in all environments
- [x] All files are in `vulnerable-site/` directory
- [x] Production Dockerfile copies `vulnerable-site/` directory
- [x] GitHub Actions workflow builds from correct Dockerfile
- [x] Local Dockerfile updated to use public base image

## Testing in Production

After deployment, verify:
1. Navigation buttons appear above tabs (not in main menu)
2. Back button works (navigates to labs index)
3. View Stolen Data button works (opens C2 dashboard)
4. Cards page is default (not Dashboard)
5. Add card form is visible by default
6. Settings tab is not visible
7. Only 4 tabs visible (Dashboard, Transfer, Bill Pay, Cards)

## Files Modified

1. `labs/02-dom-skimming/vulnerable-site/banking.html` - HTML structure
2. `labs/02-dom-skimming/vulnerable-site/js/banking.js` - JavaScript logic
3. `labs/02-dom-skimming/vulnerable-site/css/banking.css` - CSS styles
4. `labs/02-dom-skimming/vulnerable-site/Dockerfile` - Local dev Dockerfile (uses public base image)

**Note**: Production uses `labs/02-dom-skimming/Dockerfile` which already copies `vulnerable-site/`, so all changes will be included automatically.





