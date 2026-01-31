# Deprecated: Malicious Code Moved

This folder is kept for reference. After the Lab 2 refactor:

- **C2 server**: Use `../c2-server/` (sibling to vulnerable-site). Build from `02-dom-skimming/c2-server`.
- **Skimmer variants** (dom-monitor, form-overlay, shadow-skimmer): Now in `../vulnerable-site/malicious-code/`. The vulnerable-site image copies them and selects one via `LAB2_VARIANT` (default: dom-monitor).

See `../REFACTOR-PLAN.md` for details.
