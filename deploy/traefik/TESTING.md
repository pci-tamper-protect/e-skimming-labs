# Testing Traefik Label-Based Routing

This document explains how to test the Traefik label-based routing system layer by layer.

## Quick Start

Run all tests:
```bash
./deploy/traefik/test-label-generation.sh
```

## Test Suite Overview

The test suite verifies 5 layers of the label-based routing system:

### Test 1: Label Extraction ✅
**What it tests:** Can we extract Traefik labels from Cloud Run service JSON?

**How it works:**
- Creates a mock Cloud Run service JSON with Traefik labels
- Uses `jq` to extract labels (same as the actual script)
- Verifies `traefik.enable=true` is found
- Verifies router labels are present

**Key learning:** The script uses `jq` to parse JSON and extract labels from `.spec.template.metadata.labels`

### Test 2: Router Name Extraction ✅
**What it tests:** Can we extract router names from label keys?

**How it works:**
- Finds all labels matching `traefik.http.routers.*`
- Extracts router name using regex: `traefik.http.routers.<name>.<property>`
- Verifies the router name is correctly extracted

**Key learning:** Router names are extracted from label keys using pattern matching

### Test 3: YAML Route Generation ✅
**What it tests:** Can we generate valid YAML routes from labels?

**How it works:**
- Extracts router properties (rule, priority, entrypoints)
- Generates YAML router definition
- Validates YAML syntax using Python's yaml module

**Key learning:** Labels are transformed into Traefik YAML configuration format

### Test 4: Multiple Router Handling ✅
**What it tests:** Can we handle services with multiple routers?

**How it works:**
- Creates a mock lab service with 2 routers (static + main)
- Verifies both routers are detected
- Verifies router names are correctly extracted

**Key learning:** Services can have multiple routers (e.g., static files + main route)

### Test 5: Full Workflow Simulation ✅
**What it tests:** Does the complete label-to-routes process work?

**How it works:**
- Simulates the full script workflow
- Processes service JSON
- Generates complete routes.yml file
- Validates output is correct YAML

**Key learning:** End-to-end verification of the label generation pipeline

## Running Individual Tests

You can modify the test script to run only specific tests by commenting out others:

```bash
# In test-label-generation.sh, comment out tests you don't want to run
# echo "📋 Test 1: Label Extraction"
# ... test 1 code ...
```

## Understanding the Output

Each test shows:
- ✅ **PASS**: Test succeeded
- ❌ **FAIL**: Test failed (script exits)

The final summary explains:
1. **Label Extraction**: How labels are read from Cloud Run
2. **Router Parsing**: How router names and properties are extracted
3. **YAML Generation**: How routes.yml is built
4. **Integration**: How it all fits together in Traefik

## Debugging Failed Tests

If a test fails:

1. **Check the error message** - It shows what was expected vs. what was found
2. **Inspect test files** - Check `/tmp/traefik-label-tests/` for generated files
3. **Verify dependencies** - Ensure `jq` and `python3` with `yaml` module are installed

## Testing with Real Cloud Run Services

To test with actual Cloud Run services (requires gcloud access):

```bash
# Set environment variables
export ENVIRONMENT=stg
export LABS_PROJECT_ID=labs-stg
export HOME_PROJECT_ID=labs-home-stg
export REGION=us-central1

# Run the actual generation script
./deploy/traefik/generate-routes-from-labels.sh /tmp/test-routes.yml

# Inspect the output
cat /tmp/test-routes.yml
```

## Next Steps

After all tests pass:
1. Deploy services with Traefik labels
2. Run the actual generation script in Cloud Run
3. Verify Traefik picks up the routes
4. Check Traefik dashboard: `https://traefik-<env>-xxxxx-uc.a.run.app/dashboard/`
