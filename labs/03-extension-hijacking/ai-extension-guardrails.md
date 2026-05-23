# Official AI Browser Assistants and Skimming Guardrails

Reviewed: 2026-05-17

Issue context: Lab 3 currently models a malicious or compromised extension.
Issue 242 asks whether the same skimming risk can be demonstrated with official
AI browser assistants, where the attack comes from prompt injection in page
content rather than from convincing the victim to install a malicious extension.

## Safe Lab Boundary

This note is for defensive education and lab design only.

- Do not test against real shopping, banking, healthcare, work, wallet, or
  payment accounts.
- Do not install or drive real AI browser extensions as part of the automated
  lab.
- Do not collect real card numbers, passwords, cookies, API keys, identity
  documents, or session data.
- Use only local demo pages, fake test data, and a simulated assistant harness.
- Treat public provider guardrails as current public documentation, not as a
  guarantee of security behavior.

## Threat Model

The official-assistant variant removes the malicious-extension installation
step:

1. A user opens a page that contains visible or hidden prompt-injection text.
2. The user asks an AI browser assistant to summarize, compare prices, fill a
   form, or complete a checkout-like task.
3. The assistant receives page content through screenshots, DOM access, browser
   automation, JavaScript execution, or a related browser-control channel.
4. The injected instruction tries to redirect the assistant into reading payment
   fields, account fields, cookies, storage, screenshots, or page metadata, then
   sending the data to an attacker-controlled destination.

This does not require a malicious extension, but it still depends on the user
granting the assistant enough page access or action authority.

## Public Guardrail Matrix

### Claude in Chrome

Publicly documented relevant guardrails:

- Per-domain JavaScript permission.
- Site blocklists for some high-risk categories.
- Action confirmations.
- Content classifiers and output filters.
- Team and Enterprise allowlists and blocklists.
- Explicit prohibitions on handling sensitive credit card or ID data.

Skimming relevance:

Claude in Chrome is the closest current public match for issue 242 because it is
an official Chrome assistant that can read page content, take browser actions,
and run JavaScript when permitted. Its documented controls should reduce risk,
but the lab should teach that broad site permission on checkout or account pages
remains dangerous.

Lab recommendation:

Model this as the primary case. Use a simulated Claude-like assistant permission
gate with per-site approval, action confirmation, and a hard block for
payment-card and ID fields.

### ChatGPT Agent

Publicly documented relevant guardrails:

- User confirmations for consequential actions.
- Restrictions on sensitive actions.
- Monitoring for prompt injection.
- Handoff or takeover behavior for sensitive input flows.

Skimming relevance:

ChatGPT agent is not a Chrome extension, but it is an official browser-using
assistant class where hidden page instructions can conflict with the user's
task.

Lab recommendation:

Include it as a comparison class, not as the direct Chrome-extension case.
Emphasize human confirmation and takeover points around payment or login data.

### Generic AI Browser Extensions

Public guardrails vary by vendor. Minimum controls to look for are per-site
approval, narrow page context, no automatic sensitive-field handling, no
cross-site data sending, clear action plans, high-impact action confirmation,
organization allowlists and blocklists, and audit logs.

Skimming relevance:

Any assistant with page reading plus autonomous actions can become a skimming
path if a page prompt can override the user's intent.

Lab recommendation:

Use a checklist instead of naming unverified products. Require source-backed
claims before adding a tool-specific row.

## Guardrail Checklist for Lab 3

Use this checklist when evaluating any official or third-party AI browser
assistant:

1. Page access: Does the assistant receive screenshots, DOM text, form values,
   cookies, local storage, session storage, or network data?
2. Action access: Can it click, type, submit forms, run JavaScript, download
   files, create accounts, or make purchases?
3. Permission scope: Are approvals per action, per plan, per site, or global?
4. Sensitive data handling: Does the tool refuse card numbers, CVV, IDs,
   passwords, API keys, banking data, health data, or work-confidential data?
5. Prompt-injection handling: Does it classify untrusted page content and ignore
   instructions from the page that conflict with the user?
6. Consequential actions: Does it require explicit confirmation for purchases,
   transactions, account creation, deletion, permission changes, and file
   downloads?
7. Site restrictions: Are financial, trading, crypto, healthcare, government,
   work, or adult sites blocked or approval-gated?
8. Exfiltration controls: Does it block copying page secrets into chat, outbound
   messages, files, forms, URLs, or third-party sites?
9. Admin controls: Can organizations force allowlists, blocklists, disable the
   assistant, or audit usage?
10. Failure mode: If a guardrail is uncertain, does the assistant stop and ask
    the user, or continue with broad access?

## Suggested Simulated Lab Flow

Build the official-assistant scenario without using a real provider:

1. Add a local checkout page containing fake payment fields and hidden untrusted
   instructions.
2. Add a simulated assistant panel with two modes:
   - ask-before-acting: plan approval plus per-action confirmation
   - act-without-asking: intentionally risky mode for comparison
3. Feed the assistant harness only sanitized page text and fake form values.
4. Record whether the harness would attempt one of these prohibited actions:
   - read payment fields
   - summarize or transmit sensitive fields
   - submit data to another site
   - run page-supplied JavaScript
   - follow page instructions over the user's instruction
5. Make the expected safe outcome a refusal or confirmation prompt, not data
   collection.

The exercise should teach reviewers to ask, "What did the assistant see, what
was it allowed to do, and where could sensitive data leave the page?"

## Current Answer to Issue 242

Official AI browser assistants do expand the attack surface because they can
give trusted automation powers to untrusted page content. The publicly
documented guardrails with the strongest direct relevance are:

- Per-site and per-action permissioning.
- Sensitive-site blocklists or enterprise allowlists/blocklists.
- Explicit confirmations for purchases and other irreversible actions.
- Refusal or takeover behavior for sensitive input such as payment or identity
  data.
- Prompt-injection classifiers and model training that treat page content as
  untrusted.

Those controls are meaningful, but they are not enough to make checkout-page
automation safe by default. The defensive recommendation for Lab 3 is to add a
simulated official-assistant scenario that demonstrates the risk of granting
page/action access and the value of per-action confirmation, sensitive-field
blocking, and site allowlisting.

## Sources

- [Anthropic, "Using Claude in Chrome safely"][claude-safe]
- [Anthropic, "Claude in Chrome Permissions Guide"][claude-permissions]
- [OpenAI, "ChatGPT agent system card"][openai-agent-card]

[claude-safe]:
  https://support.claude.com/en/articles/12902428-using-claude-in-chrome-safely
[claude-permissions]:
  https://support.claude.com/en/articles/12902446-claude-for-chrome-permissions-guide
[openai-agent-card]: https://openai.com/index/chatgpt-agent-system-card/
