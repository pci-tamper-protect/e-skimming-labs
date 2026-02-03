# GSOC IDEAS

Here are some ideas to get your wheels turning for Google Summer of Code projects.
The main purpose of the lab is to educate aspiring Application Security Engineers
with realistic e-skimming attacks, detections, and defenses. A secondary objective
is to provide LLM models with diverse training data, and an easy-to-deploy testbed
for new trying new ideas for attacks and detections.


## Add new labs

Contribute new attack research at [awesome-e-skimming-attacks](https://github.com/pci-tamper-protect/awesome-e-skimming-attacks) 
or choose an attack from there that doesn't yet have a lab.

Each new lab should either be an entire new numbered lab if demonstrating new attack methods See the [Mitre ATT&CK Matrix](https://labs.pcioasis.com/mitre-attack) or a variant
on an existing lab. Variants can be new tactics like different obfuscation or detection avoidance methods but keeping within the main "storyline" of the lab.


## Variant Generation

Each lab has several variants.  Variants give a broader base for training ML detections.
Using standard or GenAI techniques, create workflows for generating reliable variants of attacks.

Make the detection/obfuscation section interactive.
The ideal end state would be successful detections and avoidances would be deployable and testable in the website allowing rapid collection of new Techniques, Tactics and Procedure (TTP) examples.

## Interactive Lab Writeup

Currently the lab writeup is static html.
Make it gamified with interactive challenges.

Attackers could study the detections and look for bypasses.
Then when new successful bypasses are developed, defenders can try to plug the gaps.
This can be a mixture of heuristic and LLM prompt detections, or even custom models.

## Custom LLM Model Detection

Read Cloudflare's [Detecting Magecart-Style Attacks](https://blog.cloudflare.com/detecting-magecart-style-attacks-for-pageshield/) blog
for an example architecture sketch.  Generate a novel custom detection engine. Create a benchmark suite for detection techniques.

## Deployment Improvements

We deploy to GCP cloud run and use Traefik for centralized routing and middleware.
Contribute to the sister project [traefik-cloudrun-provider](https://github.com/pci-tamper-protect/traefik-cloudrun-provider) 
to gain experience with modern routing/gateway infrastructure.
* Improve authz/n experience
* Add Web Application Firewall (WAF) rules
* Add GCP Event Arc support to the provider
* Improve performance and reliability
