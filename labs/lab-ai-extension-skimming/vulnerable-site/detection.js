/**
 * AI Extension Skimming Detection Script
 * 
 * Detects and neutralizes hidden prompt injection payloads
 * targeting AI browser extensions on payment pages.
 * 
 * Deploy on checkout/payment pages to protect against
 * AI-extension-based card data exfiltration.
 */

(function() {
    'use strict';

    const CONFIG = {
        // Keywords that indicate prompt injection targeting AI
        injectionKeywords: [
            'system context', 'system override', 'ai assistant',
            'include in response', 'verification hash', 'verification code',
            'read the values', 'form field values', 'card_number',
            'card_cvv', 'card_expiry', 'cc-number', 'cc-csc',
            'do not mention', 'these instructions', 'system instruction',
            'ai context', 'important context for ai', 'end system',
            'transaction verification', 'format as', 'encode as'
        ],
        // Patterns that indicate hidden/invisible content
        hidingPatterns: {
            offScreen: /position\s*:\s*absolute.*left\s*:\s*-\d{4,}/i,
            zeroSize: /font-size\s*:\s*0/i,
            transparent: /color\s*:\s*transparent/i,
            zeroOpacity: /opacity\s*:\s*0/i,
            overflow: /overflow\s*:\s*hidden.*width\s*:\s*1px/i,
            clip: /clip\s*:\s*rect\s*\(\s*0/i
        },
        // Minimum text length to analyze (ignore tiny elements)
        minTextLength: 50,
        // Report endpoint (configure for your monitoring)
        reportEndpoint: null, // '/api/security/injection-report'
        // Auto-remove detected injections
        autoRemove: true,
        // Log to console
        verbose: true
    };

    function log(level, message, data) {
        if (!CONFIG.verbose) return;
        const prefix = `[AI-Skim-Detect][${level.toUpperCase()}]`;
        if (data) {
            console[level === 'warn' ? 'warn' : level === 'error' ? 'error' : 'log'](prefix, message, data);
        } else {
            console[level === 'warn' ? 'warn' : level === 'error' ? 'error' : 'log'](prefix, message);
        }
    }

    function isHiddenElement(el) {
        const style = window.getComputedStyle(el);
        const inlineStyle = el.getAttribute('style') || '';
        
        // Check computed styles
        if (style.display === 'none') return true;
        if (style.visibility === 'hidden') return true;
        if (style.opacity === '0') return true;
        if (parseInt(style.fontSize) === 0) return true;
        if (style.color === 'transparent' || style.color === 'rgba(0, 0, 0, 0)') return true;
        
        // Check position (off-screen)
        const rect = el.getBoundingClientRect();
        if (rect.right < 0 || rect.bottom < 0) return true;
        if (rect.left > window.innerWidth + 100) return true;
        
        // Check inline style patterns
        for (const [name, pattern] of Object.entries(CONFIG.hidingPatterns)) {
            if (pattern.test(inlineStyle)) return true;
        }
        
        // Check aria-hidden
        if (el.getAttribute('aria-hidden') === 'true') return true;
        
        return false;
    }

    function containsInjection(text) {
        const lower = text.toLowerCase();
        const matches = CONFIG.injectionKeywords.filter(kw => lower.includes(kw));
        return matches.length >= 2; // Require at least 2 keyword matches to reduce false positives
    }

    function getInjectionSeverity(text, matchCount) {
        if (matchCount >= 5) return 'CRITICAL';
        if (matchCount >= 3) return 'HIGH';
        return 'MEDIUM';
    }

    function scanElement(el) {
        const text = el.textContent || '';
        if (text.length < CONFIG.minTextLength) return null;
        
        if (!isHiddenElement(el)) return null;
        
        const lower = text.toLowerCase();
        const matches = CONFIG.injectionKeywords.filter(kw => lower.includes(kw));
        
        if (matches.length < 2) return null;
        
        return {
            element: el,
            text: text.substring(0, 200) + (text.length > 200 ? '...' : ''),
            matchedKeywords: matches,
            severity: getInjectionSeverity(text, matches.length),
            tagName: el.tagName,
            className: el.className,
            id: el.id
        };
    }

    function scanPage() {
        const allElements = document.querySelectorAll('*');
        const findings = [];
        
        for (const el of allElements) {
            // Skip script and style elements
            if (['SCRIPT', 'STYLE', 'LINK', 'META'].includes(el.tagName)) continue;
            
            const result = scanElement(el);
            if (result) findings.push(result);
        }
        
        return findings;
    }

    function neutralize(finding) {
        if (CONFIG.autoRemove) {
            finding.element.remove();
            log('warn', `NEUTRALIZED: Removed injection element <${finding.tagName}> (${finding.severity})`, {
                keywords: finding.matchedKeywords,
                preview: finding.text
            });
        }
    }

    function report(findings) {
        if (!CONFIG.reportEndpoint || findings.length === 0) return;
        
        const payload = {
            url: window.location.href,
            timestamp: new Date().toISOString(),
            findings: findings.map(f => ({
                severity: f.severity,
                tagName: f.tagName,
                className: f.className,
                matchedKeywords: f.matchedKeywords,
                textPreview: f.text
            }))
        };
        
        fetch(CONFIG.reportEndpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        }).catch(() => {}); // Silent fail for reporting
    }

    function runScan() {
        const findings = scanPage();
        
        if (findings.length > 0) {
            log('error', `⚠️ DETECTED ${findings.length} AI EXTENSION INJECTION(S):`);
            findings.forEach((f, i) => {
                log('warn', `  [${i+1}] Severity: ${f.severity} | Element: <${f.tagName}> | Keywords: ${f.matchedKeywords.join(', ')}`);
                neutralize(f);
            });
            report(findings);
        } else {
            log('info', '✅ No AI extension injections detected');
        }
        
        return findings;
    }

    // Initial scan
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', runScan);
    } else {
        runScan();
    }

    // Continuous monitoring via MutationObserver
    // Walks the full subtree of added nodes to catch injections nested inside wrapper elements
    const observer = new MutationObserver((mutations) => {
        const findings = [];
        for (const mutation of mutations) {
            for (const node of mutation.addedNodes) {
                if (node.nodeType !== Node.ELEMENT_NODE) continue;
                
                // Scan the added node itself
                const result = scanElement(node);
                if (result) findings.push(result);
                
                // Walk all descendants — injections are often nested inside wrapper divs
                const descendants = node.querySelectorAll('*');
                for (const descendant of descendants) {
                    const childResult = scanElement(descendant);
                    if (childResult) findings.push(childResult);
                }
            }
        }
        
        if (findings.length > 0) {
            log('error', `⚠️ DYNAMIC INJECTION DETECTED (${findings.length} element(s) added after page load):`);
            findings.forEach(f => {
                log('warn', `  Severity: ${f.severity} | Keywords: ${f.matchedKeywords.join(', ')}`);
                neutralize(f);
            });
            report(findings);
        }
    });

    observer.observe(document.body, { childList: true, subtree: true });

    // Expose for testing
    window.__aiSkimDetect = { runScan, CONFIG };
    
    log('info', 'AI Extension Skimming Detection active. Monitoring for injections...');
})();
