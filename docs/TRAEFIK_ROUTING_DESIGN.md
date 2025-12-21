Which routing solutions best balance technical consistency, security requirements, and strict budget 

To achieve a balance between technical consistency, security, and a strict budget of under $20/month, the best solutions involve using an open-source reverse proxy like Traefik or a single Nginx server.
The following breakdown explains how these options address your specific requirements:
1. Most Balanced Solutions: Traefik or Nginx
The sources identify Traefik Open Source and a single Nginx server as the most viable paths for unifying your architecture.
• Technical Consistency: Both solutions support path-based routing (e.g., labs.pcioasis.com/lab1), which is the preferred structure. Because both can be containerized, you can use the exact same routing configuration in your docker-compose.yml for local development and in your production Cloud Run deployment. This allows you to run the same Playwright tests against both environments without modification.
• Security & Privacy: A major concern is preventing providers like Google or Cloudflare from accessing lab content for model training or detection testing. By using your own proxy (Traefik/Nginx) as the entry point, you can better control access and potentially avoid labs being flagged as "Dangerous," a problem that has affected previous labs. These tools also provide a foundation for adding authentication, which is a planned requirement.
• Budget Alignment: Traefik and Nginx are open-source and do not carry the per-path or per-feature fees associated with managed solutions. Running a small instance of these tools typically fits well within the $20/month limit.
2. Discarded Managed Solutions
While other options exist, they fail to meet the budget or security constraints:
• Cloudflare Path-Based Routing: While Cloudflare currently manages your DNS, their path-based routing (e.g., labs.pcioasis.com/lab1) costs extra, as does every additional component needed to complete the setup. Additionally, this would grant Cloudflare access to lab content you wish to keep private.
• GCP Application Load Balancer: This is described as one of the most complicated deployment models. While powerful for traffic management, the base costs for an Application Load Balancer often exceed strict $20/month budgets.
3. Alternative: Cloudflare Subdomains
If path-based routing is not strictly required, you could use DNS records in Cloudflare to create subdomains like lab1.pcioasis.com for free. However, this does not provide the same unified "path-based" structure desired for technical consistency across local and production environments.
Comparison Table
Feature
Nginx / Traefik (Recommended)
Cloudflare Managed
GCP App Load Balancer
Consistency
High (same container in local/prod)
Medium (config differences)
Low (complex/different)
Budget
Under $20/month
High (extra fees per path)
High (base service costs)
Privacy
High (avoids provider scanning)
Low (provider access)
Low (provider access)
Routing
Path-based
Path-based (Paid)
Path-based

--------------------------------------------------------------------------------
Analogy: Using a managed load balancer is like hiring a high-end valet service; it’s convenient but expensive and they get to see inside your car. Implementing Traefik or Nginx is like installing your own high-tech garage door; it takes a bit more setup, but it’s cheaper in the long run and ensures only you know what's parked inside.
Make a detailed design plan for landing page and all labs based on github.com/ptp-tamper-protect/e-skimming-labs.  There is a landing page that lists two static sites for Mitre ATT&ACK and Threat Model. And there are 3 labs with some variants. Use diagram.   mermaid markdown is my favorite, but others are acceptable.  Explain the traefic toutin and deployment for docker-compose and cloud run in great detail.

This design plan focuses on transitioning from a port-based local setup and inconsistent production URLs to a unified, path-based routing architecture using Traefik Open Source. This approach ensures technical consistency between your local development and Cloud Run production environments, maintains privacy against provider scanning, and fits within the $20/month budget.
1. Architectural Overview
The core of this design is using Traefik as a reverse proxy to handle all incoming traffic at labs.pcioasis.com (Production) or localhost (Development). It will route traffic to specific services based on the URL path.
System Architecture Diagram (Mermaid)
graph TD
    User((User/Tester)) --> |Request to labs.pcioasis.com/path| Traefik[Traefik Proxy]
    
    subgraph "Routing Layer (Path-Based)"
        Traefik -->|/| Landing[Landing Page]
        Traefik -->|/mitre-attack| Mitre[Mitre ATT&ACK Static Site]
        Traefik -->|/threat-model| Threat[Threat Model Static Site]
        Traefik -->|/lab1/*| Lab1[Lab 1: E-Skimming Basics]
        Traefik -->|/lab2/*| Lab2[Lab 2: Variant A/B]
        Traefik -->|/lab3/*| Lab3[Lab 3: Extension Hijacking]
        Traefik -->|/stolen-data| Data[Stolen Data Service]
    end

    subgraph "Backend Services"
        Landing
        Mitre
        Threat
        Lab1
        Lab2
        Lab3
        Data
    end

--------------------------------------------------------------------------------
2. Traefik Routing Configuration Detail
Traefik will be configured to use PathPrefix rules. This allows the same logic to apply regardless of whether the base URL is localhost or labs.pcioasis.com.
• Static Sites (Mitre & Threat Model): These remain static HTML pages but are now routed via Traefik instead of direct port access.
• Lab Variants: Labs with variants (like Lab 2 or 3) can be handled via sub-paths (e.g., /lab2/v1, /lab2/v2) or headers, though path-based is preferred for consistency with Playwright testing.
• Data Handling: The "View stolen data" feature, previously on a separate port (9006), will now be routed via /stolen-data.

--------------------------------------------------------------------------------
3. Deployment: Docker-Compose (Local)
For local development, Traefik uses Docker labels to discover services dynamically. This eliminates the need to remember port numbers like 9005 or 9006.
Example docker-compose.yml Logic:
services:
  traefik:
    image: traefik:v2.10
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  lab3-extension:
    image: e-skimming-lab3:latest
    labels:
      - "traefik.http.routers.lab3.rule=PathPrefix(`/lab3`)"
      - "traefik.http.services.lab3.loadbalancer.server.port=8080"

  mitre-attack:
    image: nginx:alpine # Serving static HTML
    labels:
      - "traefik.http.routers.mitre.rule=PathPrefix(`/mitre-attack`)"

--------------------------------------------------------------------------------
4. Deployment: Cloud Run (Production)
In production, Traefik will run as a primary Cloud Run service. To keep costs under $20/month and maintain privacy, we will follow these steps:
1. Traefik as Entry Point: Deploy Traefik to Cloud Run. It will receive traffic from Cloudflare via your existing DNS setup.
2. Internal Routing: Traefik will be configured using a File Provider or HTTP Provider to route requests to the internal URLs of other Cloud Run services.
3. Privacy & Security: By routing through Traefik, you can keep the individual lab services "Internal" (not publicly accessible). This prevents Google or Cloudflare from scanning the lab content directly, which helps avoid "Dangerous" site flagging and keeps lab content private for future authenticated users.
4. Testing Consistency: Since the paths are identical (/lab3), your Playwright tests can run against http://localhost/lab3 or https://labs.pcioasis.com/lab3 without changing the internal logic of the tests.

--------------------------------------------------------------------------------
5. Design Summary Table
Component
Path
Current State (Local)
New State (Local & Prod)
Landing Page
/
localhost:3000
labs.pcioasis.com/
Mitre Site
/mitre-attack
localhost:3000/mitre-attack
labs.pcioasis.com/mitre-attack
Lab 3
/lab3
localhost:9005
labs.pcioasis.com/lab3
Stolen Data
/stolen-data
localhost:9006
labs.pcioasis.com/stolen-data

--------------------------------------------------------------------------------
Analogy: Think of Traefik as a concierge in a hotel lobby. Currently, visitors (users/tests) have to find specific hidden side doors (different ports and long URLs) to get to different rooms. With this plan, everyone enters through the front door (labs.pcioasis.com), and the concierge (Traefik) directs them to the correct room based on the name they ask for, while keeping the rest of the hotel private from outside observers.
