# Domain Mapping for Home Index Service
# REMOVED: Domain mappings are now managed in terraform-labs for Traefik
# Traefik is the single entry point:
#   - labs.stg.pcioasis.com → traefik-stg (managed in terraform-labs)
#   - labs.pcioasis.com → traefik-prd (managed in terraform-labs)
# All traffic goes through Traefik, which routes to home-index and other services
# See: docs/traefik-architecture.md and deploy/TRAEFIK_ROUTER_SETUP.md
