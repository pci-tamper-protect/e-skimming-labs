#!/bin/bash
# Injected mock get_identity_token for testing
get_identity_token() {
  local service_url=$1
  local token_var=""

  case "$service_url" in
    *home-index*) token_var="HOME_INDEX_TOKEN" ;;
    *home-seo*) token_var="SEO_TOKEN" ;;
    *analytics*) token_var="ANALYTICS_TOKEN" ;;
    *lab-01-basic-magecart*|*lab1*)
      if [[ "$service_url" == *c2* ]]; then
        token_var="LAB1_C2_TOKEN"
      else
        token_var="LAB1_TOKEN"
      fi
      ;;
    *lab-02-dom-skimming*|*lab2*)
      if [[ "$service_url" == *c2* ]]; then
        token_var="LAB2_C2_TOKEN"
      else
        token_var="LAB2_TOKEN"
      fi
      ;;
    *lab-03-extension*|*lab3*)
      if [[ "$service_url" == *extension* ]]; then
        token_var="LAB3_EXTENSION_TOKEN"
      else
        token_var="LAB3_TOKEN"
      fi
      ;;
  esac

  if [ -n "$token_var" ]; then
    eval "echo \$$token_var"
  else
    echo ""
  fi
}
