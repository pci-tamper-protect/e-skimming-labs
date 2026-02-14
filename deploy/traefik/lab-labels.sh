#!/bin/bash
# AUTO-GENERATED from docker-compose.yml by generate-lab-labels.sh
# Do not edit manually. Re-run: ./deploy/traefik/generate-lab-labels.sh

get_lab_labels() {
  local service="$1"
  case "$service" in
    traefik)
      echo "traefik_enable=true"
      ;;
    home-index)
      echo "traefik_enable=true,traefik_http_routers_home-index_rule_id=home-index,traefik_http_routers_home-index_priority=50,traefik_http_routers_home-index_entrypoints=web,traefik_http_services_home-index_lb_port=8080,traefik_http_routers_home-index_service=home-index,traefik_http_routers_home-index-signin_rule_id=home-index-signin,traefik_http_routers_home-index-signin_priority=100,traefik_http_routers_home-index-signin_entrypoints=web,traefik_http_routers_home-index-signin_middlewares=signin-headers-file,traefik_http_routers_home-index-signin_service=home-index"
      ;;
    home-seo)
      echo "traefik_enable=true,traefik_http_routers_home-seo_rule_id=home-seo,traefik_http_routers_home-seo_priority=500,traefik_http_routers_home-seo_entrypoints=web,traefik_http_routers_home-seo_middlewares=strip-seo-prefix-file,traefik_http_services_home-seo_lb_port=8080"
      ;;
    labs-analytics)
      echo "traefik_enable=true,traefik_http_routers_labs-analytics_rule_id=labs-analytics,traefik_http_routers_labs-analytics_priority=500,traefik_http_routers_labs-analytics_entrypoints=web,traefik_http_routers_labs-analytics_middlewares=strip-analytics-prefix-file,traefik_http_services_labs-analytics_lb_port=8080"
      ;;
    lab1-vulnerable-site)
      echo "traefik_enable=true,traefik_http_routers_lab1-static_rule_id=lab1-static,traefik_http_routers_lab1-static_priority=250,traefik_http_routers_lab1-static_entrypoints=web,traefik_http_routers_lab1-static_middlewares=strip-lab1-prefix-file,traefik_http_routers_lab1-static_service=lab1,traefik_http_routers_lab1_rule_id=lab1,traefik_http_routers_lab1_priority=200,traefik_http_routers_lab1_entrypoints=web,traefik_http_routers_lab1_middlewares=lab1-auth-check-file__strip-lab1-prefix-file,traefik_http_routers_lab1_service=lab1,traefik_http_services_lab1_lb_port=8080"
      ;;
    lab1-c2-server)
      echo "traefik_enable=true,traefik_http_routers_lab1-c2_rule_id=lab1-c2,traefik_http_routers_lab1-c2_priority=300,traefik_http_routers_lab1-c2_entrypoints=web,traefik_http_routers_lab1-c2_middlewares=lab1-auth-check-file__strip-lab1-c2-prefix-file,traefik_http_services_lab1-c2-server_lb_port=8080"
      ;;
    lab2-vulnerable-site)
      echo "traefik_enable=true,traefik_http_routers_lab2-static_rule_id=lab2-static,traefik_http_routers_lab2-static_priority=250,traefik_http_routers_lab2-static_entrypoints=web,traefik_http_routers_lab2-static_middlewares=strip-lab2-prefix-file,traefik_http_routers_lab2-static_service=lab2-vulnerable-site,traefik_http_routers_lab2-main_rule_id=lab2-main,traefik_http_routers_lab2-main_priority=200,traefik_http_routers_lab2-main_entrypoints=web,traefik_http_routers_lab2-main_middlewares=lab2-auth-check-file__strip-lab2-prefix-file,traefik_http_routers_lab2-main_service=lab2-vulnerable-site,traefik_http_services_lab2-vulnerable-site_lb_port=8080"
      ;;
    lab2-c2-server)
      echo "traefik_enable=true,traefik_http_routers_lab2-c2_rule_id=lab2-c2,traefik_http_routers_lab2-c2_priority=300,traefik_http_routers_lab2-c2_entrypoints=web,traefik_http_routers_lab2-c2_middlewares=lab2-auth-check-file__strip-lab2-c2-prefix-file,traefik_http_services_lab2-c2-server_lb_port=8080"
      ;;
    lab3-vulnerable-site)
      echo "traefik_enable=true,traefik_http_routers_lab3-static_rule_id=lab3-static,traefik_http_routers_lab3-static_priority=250,traefik_http_routers_lab3-static_entrypoints=web,traefik_http_routers_lab3-static_middlewares=strip-lab3-prefix-file,traefik_http_routers_lab3-static_service=lab3-vulnerable-site,traefik_http_routers_lab3-main_rule_id=lab3-main,traefik_http_routers_lab3-main_priority=200,traefik_http_routers_lab3-main_entrypoints=web,traefik_http_routers_lab3-main_middlewares=lab3-auth-check-file__strip-lab3-prefix-file,traefik_http_routers_lab3-main_service=lab3-vulnerable-site,traefik_http_services_lab3-vulnerable-site_lb_port=8080"
      ;;
    lab3-extension-server)
      echo "traefik_enable=true,traefik_http_routers_lab3-extension_rule_id=lab3-extension,traefik_http_routers_lab3-extension_priority=300,traefik_http_routers_lab3-extension_entrypoints=web,traefik_http_routers_lab3-extension_middlewares=lab3-auth-check-file__strip-lab3-extension-prefix-file,traefik_http_services_lab3-extension-server_lb_port=8080"
      ;;
    lab1-event-listener-variant)
      echo "traefik_enable=true,traefik_http_routers_lab1-event-listener_rule_id=lab1-event-listener,traefik_http_routers_lab1-event-listener_priority=400,traefik_http_routers_lab1-event-listener_entrypoints=web,traefik_http_routers_lab1-event-listener_middlewares=lab1-auth-check-file__strip-lab1-event-listener-prefix-file,traefik_http_services_lab1-event-listener-variant_lb_port=8080"
      ;;
    lab1-obfuscated-variant)
      echo "traefik_enable=true,traefik_http_routers_lab1-obfuscated_rule_id=lab1-obfuscated,traefik_http_routers_lab1-obfuscated_priority=400,traefik_http_routers_lab1-obfuscated_entrypoints=web,traefik_http_routers_lab1-obfuscated_middlewares=lab1-auth-check-file__strip-lab1-obfuscated-prefix-file,traefik_http_services_lab1-obfuscated-variant_lb_port=8080"
      ;;
    lab1-websocket-variant)
      echo "traefik_enable=true,traefik_http_routers_lab1-websocket_rule_id=lab1-websocket,traefik_http_routers_lab1-websocket_priority=400,traefik_http_routers_lab1-websocket_entrypoints=web,traefik_http_routers_lab1-websocket_middlewares=lab1-auth-check-file__strip-lab1-websocket-prefix-file,traefik_http_services_lab1-websocket-variant_lb_port=8080"
      ;;
    *)
      echo "traefik_enable=true"
      echo "⚠️  Unknown service: $service" >&2
      return 1
      ;;
  esac
}
