#!/bin/bash
# AUTO-GENERATED from docker-compose.yml by generate-lab-labels.sh
# Do not edit manually. Re-run: ./deploy/traefik/generate-lab-labels.sh

# validate_cr_labels SERVICE LABELS_STRING
# Validates Cloud Run label constraints. Exits non-zero on any violation.
# Called automatically by get_lab_labels — sourcing scripts will abort on bad labels.
validate_cr_labels() {
  local service="$1"
  local labels_str="$2"
  local base_label_count="${3:-3}"
  local errors=0

  IFS=',' read -ra pairs <<< "$labels_str"
  local count=${#pairs[@]}
  local total=$((count + base_label_count))
  if [ "$total" -gt 64 ]; then
    echo "❌ VALIDATION [$service]: $total labels total ($count Traefik + $base_label_count base) exceeds Cloud Run max of 64" >&2
    errors=$((errors + 1))
  fi

  for pair in "${pairs[@]}"; do
    local key="${pair%%=*}"
    local value="${pair#*=}"
    if [[ ! "$key" =~ ^[a-z][a-z0-9_-]*$ ]]; then
      echo "❌ VALIDATION [$service]: Invalid key format: '$key'" >&2
      errors=$((errors + 1))
    elif [ "${#key}" -gt 63 ]; then
      echo "❌ VALIDATION [$service]: Key too long (${#key}/63): '$key'" >&2
      errors=$((errors + 1))
    fi
    if [[ -n "$value" && ! "$value" =~ ^[a-z0-9_-]*$ ]]; then
      echo "❌ VALIDATION [$service]: Invalid value for '$key': '$value'" >&2
      errors=$((errors + 1))
    elif [ "${#value}" -gt 63 ]; then
      echo "❌ VALIDATION [$service]: Value too long (${#value}/63) for '$key': '$value'" >&2
      errors=$((errors + 1))
    fi
  done

  if [ "$errors" -gt 0 ]; then
    echo "   Regenerate with: ./deploy/traefik/generate-lab-labels.sh" >&2
    return 1
  fi
}

get_lab_labels() {
  local service="$1"
  local labels
  case "$service" in
    traefik)
      labels="traefik_enable=true"
      ;;
    home-index)
      labels="traefik_enable=true,traefik_http_routers_home-index_rule_id=home-index,traefik_http_routers_home-index_priority=50,traefik_http_routers_home-index_entrypoints=web,traefik_http_services_home-index_lb_port=8080,traefik_http_routers_home-index_service=home-index,traefik_http_routers_home-index-signin_rule_id=home-index-signin,traefik_http_routers_home-index-signin_priority=100,traefik_http_routers_home-index-signin_entrypoints=web,traefik_http_routers_home-index-signin_middlewares=signin-headers-file,traefik_http_routers_home-index-signin_service=home-index"
      ;;
    home-seo)
      labels="traefik_enable=true,traefik_http_routers_home-seo_rule_id=home-seo,traefik_http_routers_home-seo_priority=500,traefik_http_routers_home-seo_entrypoints=web,traefik_http_routers_home-seo_middlewares=strip-seo-prefix-file,traefik_http_services_home-seo_lb_port=8080"
      ;;
    labs-analytics)
      labels="traefik_enable=true,traefik_http_routers_labs-analytics_rule_id=labs-analytics,traefik_http_routers_labs-analytics_priority=500,traefik_http_routers_labs-analytics_entrypoints=web,traefik_http_routers_labs-analytics_middlewares=strip-analytics-prefix-file,traefik_http_services_labs-analytics_lb_port=8080"
      ;;
    lab1-vulnerable-site)
      labels="traefik_enable=true,traefik_http_routers_lab1-health_rule_id=lab1-health,traefik_http_routers_lab1-health_priority=400,traefik_http_routers_lab1-health_entrypoints=web,traefik_http_routers_lab1-health_middlewares=strip-lab1-prefix-file,traefik_http_routers_lab1-health_service=lab1-vulnerable-site,traefik_http_routers_lab1-static_rule_id=lab1-static,traefik_http_routers_lab1-static_priority=250,traefik_http_routers_lab1-static_entrypoints=web,traefik_http_routers_lab1-static_middlewares=strip-lab1-prefix-file,traefik_http_routers_lab1-static_service=lab1-vulnerable-site,traefik_http_routers_lab1_rule_id=lab1,traefik_http_routers_lab1_priority=200,traefik_http_routers_lab1_entrypoints=web,traefik_http_routers_lab1_middlewares=lab1-auth-check-file__strip-lab1-prefix-file,traefik_http_routers_lab1_service=lab1-vulnerable-site,traefik_http_services_lab1-vulnerable-site_lb_port=8080"
      ;;
    lab1-c2-server)
      labels="traefik_enable=true,traefik_http_routers_lab1-c2-collect_rule_id=lab1-c2-collect,traefik_http_routers_lab1-c2-collect_priority=350,traefik_http_routers_lab1-c2-collect_entrypoints=web,traefik_http_routers_lab1-c2-collect_middlewares=strip-lab1-c2-prefix-file,traefik_http_routers_lab1-c2-collect_service=lab1-c2-server,traefik_http_routers_lab1-c2_rule_id=lab1-c2,traefik_http_routers_lab1-c2_priority=300,traefik_http_routers_lab1-c2_entrypoints=web,traefik_http_routers_lab1-c2_middlewares=lab1-auth-check-file__strip-lab1-c2-prefix-file,traefik_http_routers_lab1-c2_service=lab1-c2-server,traefik_http_services_lab1-c2-server_lb_port=8080"
      ;;
    lab2-vulnerable-site)
      labels="traefik_enable=true,traefik_http_routers_lab2-health_rule_id=lab2-health,traefik_http_routers_lab2-health_priority=400,traefik_http_routers_lab2-health_entrypoints=web,traefik_http_routers_lab2-health_middlewares=strip-lab2-prefix-file,traefik_http_routers_lab2-health_service=lab2-vulnerable-site,traefik_http_routers_lab2-static_rule_id=lab2-static,traefik_http_routers_lab2-static_priority=250,traefik_http_routers_lab2-static_entrypoints=web,traefik_http_routers_lab2-static_middlewares=strip-lab2-prefix-file,traefik_http_routers_lab2-static_service=lab2-vulnerable-site,traefik_http_routers_lab2-malicious_rule_id=lab2-malicious,traefik_http_routers_lab2-malicious_priority=260,traefik_http_routers_lab2-malicious_entrypoints=web,traefik_http_routers_lab2-malicious_middlewares=strip-lab2-prefix-file,traefik_http_routers_lab2-malicious_service=lab2-vulnerable-site,traefik_http_routers_lab2-main_rule_id=lab2-main,traefik_http_routers_lab2-main_priority=200,traefik_http_routers_lab2-main_entrypoints=web,traefik_http_routers_lab2-main_middlewares=lab2-auth-check-file__strip-lab2-prefix-file,traefik_http_routers_lab2-main_service=lab2-vulnerable-site,traefik_http_services_lab2-vulnerable-site_lb_port=8080"
      ;;
    lab2-c2-server)
      labels="traefik_enable=true,traefik_http_routers_lab2-c2-collect_rule_id=lab2-c2-collect,traefik_http_routers_lab2-c2-collect_priority=350,traefik_http_routers_lab2-c2-collect_entrypoints=web,traefik_http_routers_lab2-c2-collect_middlewares=strip-lab2-c2-prefix-file,traefik_http_routers_lab2-c2-collect_service=lab2-c2-server,traefik_http_routers_lab2-c2_rule_id=lab2-c2,traefik_http_routers_lab2-c2_priority=300,traefik_http_routers_lab2-c2_entrypoints=web,traefik_http_routers_lab2-c2_middlewares=lab2-auth-check-file__strip-lab2-c2-prefix-file,traefik_http_routers_lab2-c2_service=lab2-c2-server,traefik_http_services_lab2-c2-server_lb_port=8080"
      ;;
    lab3-vulnerable-site)
      labels="traefik_enable=true,traefik_http_routers_lab3-health_rule_id=lab3-health,traefik_http_routers_lab3-health_priority=400,traefik_http_routers_lab3-health_entrypoints=web,traefik_http_routers_lab3-health_middlewares=strip-lab3-prefix-file,traefik_http_routers_lab3-health_service=lab3-vulnerable-site,traefik_http_routers_lab3-static_rule_id=lab3-static,traefik_http_routers_lab3-static_priority=250,traefik_http_routers_lab3-static_entrypoints=web,traefik_http_routers_lab3-static_middlewares=strip-lab3-prefix-file,traefik_http_routers_lab3-static_service=lab3-vulnerable-site,traefik_http_routers_lab3-main_rule_id=lab3-main,traefik_http_routers_lab3-main_priority=200,traefik_http_routers_lab3-main_entrypoints=web,traefik_http_routers_lab3-main_middlewares=lab3-auth-check-file__strip-lab3-prefix-file,traefik_http_routers_lab3-main_service=lab3-vulnerable-site,traefik_http_services_lab3-vulnerable-site_lb_port=8080"
      ;;
    lab3-extension-server)
      labels="traefik_enable=true,traefik_http_routers_lab3-extension_rule_id=lab3-extension,traefik_http_routers_lab3-extension_priority=300,traefik_http_routers_lab3-extension_entrypoints=web,traefik_http_routers_lab3-extension_middlewares=lab3-auth-check-file__strip-lab3-extension-prefix-file,traefik_http_services_lab3-extension-server_lb_port=8080"
      ;;
    lab1-event-listener-variant)
      labels="traefik_enable=true,traefik_http_routers_lab1-event-listener_rule_id=lab1-event-listener,traefik_http_routers_lab1-event-listener_priority=400,traefik_http_routers_lab1-event-listener_entrypoints=web,traefik_http_routers_lab1-event-listener_middlewares=lab1-auth-check-file__strip-lab1-event-listener-prefix-file,traefik_http_services_lab1-event-listener-variant_lb_port=8080"
      ;;
    lab1-obfuscated-variant)
      labels="traefik_enable=true,traefik_http_routers_lab1-obfuscated_rule_id=lab1-obfuscated,traefik_http_routers_lab1-obfuscated_priority=400,traefik_http_routers_lab1-obfuscated_entrypoints=web,traefik_http_routers_lab1-obfuscated_middlewares=lab1-auth-check-file__strip-lab1-obfuscated-prefix-file,traefik_http_services_lab1-obfuscated-variant_lb_port=8080"
      ;;
    lab1-websocket-variant)
      labels="traefik_enable=true,traefik_http_routers_lab1-websocket_rule_id=lab1-websocket,traefik_http_routers_lab1-websocket_priority=400,traefik_http_routers_lab1-websocket_entrypoints=web,traefik_http_routers_lab1-websocket_middlewares=lab1-auth-check-file__strip-lab1-websocket-prefix-file,traefik_http_services_lab1-websocket-variant_lb_port=8080"
      ;;
    lab4-vulnerable-site)
      labels="traefik_enable=true,traefik_http_routers_lab4-health_rule_id=lab4-health,traefik_http_routers_lab4-health_priority=400,traefik_http_routers_lab4-health_entrypoints=web,traefik_http_routers_lab4-health_middlewares=strip-lab4-prefix-file,traefik_http_routers_lab4-health_service=lab4-vulnerable-site,traefik_http_routers_lab4-static_rule_id=lab4-static,traefik_http_routers_lab4-static_priority=250,traefik_http_routers_lab4-static_entrypoints=web,traefik_http_routers_lab4-static_middlewares=strip-lab4-prefix-file,traefik_http_routers_lab4-static_service=lab4-vulnerable-site,traefik_http_routers_lab4-main_rule_id=lab4-main,traefik_http_routers_lab4-main_priority=200,traefik_http_routers_lab4-main_entrypoints=web,traefik_http_routers_lab4-main_middlewares=lab4-auth-check-file__strip-lab4-prefix-file,traefik_http_routers_lab4-main_service=lab4-vulnerable-site,traefik_http_services_lab4-vulnerable-site_lb_port=8080"
      ;;
    lab4-c2-server)
      labels="traefik_enable=true,traefik_http_routers_lab4-c2_rule_id=lab4-c2,traefik_http_routers_lab4-c2_priority=300,traefik_http_routers_lab4-c2_entrypoints=web,traefik_http_routers_lab4-c2_middlewares=lab4-auth-check-file__strip-lab4-c2-prefix-file,traefik_http_routers_lab4-c2_service=lab4-c2-server,traefik_http_services_lab4-c2-server_lb_port=8080,traefik_http_routers_lab4-c2-collect_rule_id=lab4-c2-collect,traefik_http_routers_lab4-c2-collect_priority=350,traefik_http_routers_lab4-c2-collect_entrypoints=web,traefik_http_routers_lab4-c2-collect_middlewares=strip-lab4-c2-prefix-file,traefik_http_routers_lab4-c2-collect_service=lab4-c2-server"
      ;;
    *)
      echo "⚠️  Unknown service: $service" >&2
      return 1
      ;;
  esac
  validate_cr_labels "$service" "$labels" || return 1
  echo "$labels"
}
