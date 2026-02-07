# Google Summer of Code 2025 - Project Ideas

Welcome to the E-Skimming Labs GSoC project ideas! We're excited to mentor students working on payment security research and education.

## About E-Skimming Labs

E-Skimming Labs is an educational platform for learning about payment card skimming attacks (Magecart-style attacks). The project provides:
- Interactive attack labs with real code examples
- Detection techniques and defensive strategies
- Training data for ML-based detection research

**Organization:** [PCI Oasis](https://pcioasis.com)  
**Repository:** [github.com/pci-tamper-protect/e-skimming-labs](https://github.com/pci-tamper-protect/e-skimming-labs)  
**Live Platform:** [labs.pcioasis.com](https://labs.pcioasis.com)

---

## Project Ideas

### 1. New Attack Labs Development

**Description:** Contribute new e-skimming attack labs based on real-world techniques. Each lab demonstrates attack methods from the [MITRE ATT&CK Matrix](https://labs.pcioasis.com/mitre-attack) with detection guidance.

**Goals:**
- Research and document new attack techniques from [awesome-e-skimming-attacks](https://github.com/pci-tamper-protect/awesome-e-skimming-attacks)
- Implement 2-3 new numbered labs with complete attack/detection cycles
- Create variants that explore different obfuscation or evasion methods

| Attribute | Value |
|-----------|-------|
| **Size** | 350 hours (Large) |
| **Difficulty** | Intermediate |
| **Skills Required** | JavaScript, HTML/CSS, Node.js, Web Security fundamentals |
| **Mentors** | TBD |

---

### 2. Variant Generation Framework

**Description:** Build automated workflows for generating attack variants using GenAI and template techniques. Variants provide diverse training data for ML detection models.

**Goals:**
- Create a variant generation pipeline using LLMs or template engines
- Make the detection/obfuscation section interactive
- Enable rapid collection of new Techniques, Tactics and Procedures (TTPs)

| Attribute | Value |
|-----------|-------|
| **Size** | 175 hours (Medium) |
| **Difficulty** | Advanced |
| **Skills Required** | Python, JavaScript, GenAI/LLM APIs, AST manipulation |
| **Mentors** | TBD |

---

### 3. Interactive Gamified Lab Writeups

**Description:** Transform static HTML writeups into interactive challenges where attackers study detections and attempt bypasses, while defenders work to close gaps.

**Goals:**
- Gamify lab writeups with interactive challenges and scoring
- Enable attacker vs defender scenarios
- Support heuristic, LLM prompt, and custom model detections

| Attribute | Value |
|-----------|-------|
| **Size** | 175 hours (Medium) |
| **Difficulty** | Intermediate |
| **Skills Required** | JavaScript, React/Vue, Game design concepts, Web development |
| **Mentors** | TBD |

---

### 4. Custom LLM Detection Engine

**Description:** Build a novel ML/LLM-based detection engine for e-skimming attacks, inspired by [Cloudflare's PageShield approach](https://blog.cloudflare.com/detecting-magecart-style-attacks-for-pageshield/).

**Goals:**
- Design and implement a custom detection architecture
- Create a benchmark suite for evaluating detection techniques
- Generate training datasets from lab variants

| Attribute | Value |
|-----------|-------|
| **Size** | 350 hours (Large) |
| **Difficulty** | Advanced |
| **Skills Required** | Python, ML/Deep Learning, NLP, JavaScript analysis |
| **Mentors** | TBD |

---

### 5. Deployment & Infrastructure Improvements

**Description:** Enhance the platform's deployment infrastructure using GCP Cloud Run and Traefik. Contribute to [traefik-cloudrun-provider](https://github.com/pci-tamper-protect/traefik-cloudrun-provider).

**Goals:**
- Improve authentication/authorization experience
- Add Web Application Firewall (WAF) rules
- Add GCP EventArc support to the provider
- Improve performance and reliability

| Attribute | Value |
|-----------|-------|
| **Size** | 90 hours (Small) or 175 hours (Medium) |
| **Difficulty** | Intermediate to Advanced |
| **Skills Required** | Go, Docker, Kubernetes concepts, GCP, Traefik |
| **Mentors** | TBD |

---

## How to Apply

1. **Join our community** - Star the repo and join discussions
2. **Explore the labs** - Try all three labs at [labs.pcioasis.com](https://labs.pcioasis.com)
3. **Read the codebase** - Understand the architecture and deployment
4. **Start contributing** - Look for "good first issue" labels
5. **Reach out** - Contact mentors with your proposal draft

## Contact

- **GitHub Issues:** [Open an issue](https://github.com/pci-tamper-protect/e-skimming-labs/issues)

---

*Last updated: February 2026*
