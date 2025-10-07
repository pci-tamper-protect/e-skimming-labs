# Event Listener Variant

This variant demonstrates the same e-skimming attack but with **different event triggers** based on the British Airways attack pattern that used `mouseup` and `touchend` events instead of form submission.

## Key Differences from Base Lab

### Event Trigger Changes
1. **Multiple Event Listeners**: Uses `mouseup`, `touchend`, and `blur` events instead of `submit`
2. **Field-Level Monitoring**: Monitors individual form fields rather than form submission
3. **Real-Time Collection**: Captures data as user completes each field
4. **Button Click Detection**: Triggers on "Complete Purchase" button interaction
5. **Mobile-Friendly**: Includes touch events for mobile devices

### What Stays the Same
- **Functionality**: Identical form field extraction and POST exfiltration
- **Target Elements**: Same CSS selectors and form fields
- **C2 Communication**: Same HTTP POST to localhost:3000/collect
- **Data Structure**: Identical JSON payload structure

## ML Training Value

This variant tests whether detection models can:
- **Recognize different event patterns** vs form submission monitoring
- **Detect real-time field monitoring** instead of batch collection
- **Identify touch event abuse** commonly used on mobile
- **Spot button interaction hijacking** techniques
- **Generalize across behavioral variations** of the same attack

## Detection Signatures

Expected detection patterns:
- Multiple `addEventListener` calls on form fields
- `mouseup` and `touchend` event listeners
- `blur` event monitoring on input fields
- Button-specific event interception
- Real-time data collection patterns

## Technical Details

Based on the British Airways attack analysis:
- **22 lines of JavaScript** (keeping original brevity)
- **Mouse and touch events** for cross-device compatibility
- **Field blur detection** to capture completed entries
- **Button interaction monitoring** to detect purchase intent
- **Progressive data collection** as user fills form

## Usage

1. **Copy vulnerable site files**: `cp -r ../../vulnerable-site/* ./vulnerable-site/`
2. **Replace skimmer**: Use `checkout-compromised.js` from this variant
3. **Start C2 server**: Use same malicious-code infrastructure as base lab
4. **Run tests**: Playwright tests should still pass (same functionality)

This variant validates that event pattern changes don't break functionality while providing training data for behavioral-based detection systems.