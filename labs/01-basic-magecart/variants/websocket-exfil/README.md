# WebSocket Exfiltration Variant

This variant demonstrates the same e-skimming attack but with **WebSocket
communication** instead of HTTP POST for data exfiltration, based on the Kritec
skimmer pattern that used WebSocket C2 channels.

## Key Differences from Base Lab

### Communication Method Changes

1. **WebSocket Protocol**: Uses `ws://` instead of HTTP POST for data
   transmission
2. **Real-Time Channel**: Establishes persistent bidirectional communication
   with C2
3. **Connection Management**: Handles WebSocket connection lifecycle and
   reconnection
4. **Message Protocol**: Uses structured JSON messages over WebSocket frames
5. **Fallback Mechanism**: Falls back to HTTP POST if WebSocket connection fails

### What Stays the Same

- **Functionality**: Identical form field extraction and data structure
- **Target Elements**: Same CSS selectors and form fields
- **Data Collection**: Same JSON payload structure and metadata
- **Trigger Events**: Same form submission monitoring approach

## ML Training Value

This variant tests whether detection models can:

- **Recognize different C2 protocols** vs standard HTTP communication
- **Detect WebSocket abuse** for malicious data exfiltration
- **Identify persistent connection patterns** used by advanced skimmers
- **Spot protocol switching** and fallback mechanisms
- **Generalize across communication variations** of the same attack

## Detection Signatures

Expected detection patterns:

- WebSocket connection establishment (`new WebSocket()`)
- `ws://` or `wss://` protocol usage in URLs
- WebSocket event handlers (`onopen`, `onmessage`, `onerror`, `onclose`)
- Structured message protocols over WebSocket
- Connection retry and fallback logic

## Technical Details

Based on the Kritec skimmer analysis:

- **Dual exfiltration methods**: WebSocket primary, HTTP POST fallback
- **Persistent connections**: Maintains long-lived C2 channel
- **Structured messaging**: JSON protocol over WebSocket frames
- **Connection monitoring**: Handles disconnections and reconnections
- **Stealth communication**: Uses standard WebSocket ports to blend in

## C2 Server Requirements

The WebSocket variant requires a C2 server that supports both:

1. **WebSocket endpoint**: `ws://localhost:3001/ws` for real-time communication
2. **HTTP fallback**: `http://localhost:3000/collect` for backup exfiltration

## Usage

1. **Copy vulnerable site files**:
   `cp -r ../../vulnerable-site/* ./vulnerable-site/`
2. **Replace skimmer**: Use `checkout-compromised.js` from this variant
3. **Start WebSocket C2**: Extended C2 server with WebSocket support
4. **Run tests**: Playwright tests should validate both protocols

This variant validates that communication protocol changes don't break
functionality while providing training data for network-based detection systems.
