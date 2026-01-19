#!/bin/bash
# Terraform wrapper script that uses .env to determine environment
# Usage: ./terraform-wrapper.sh <terraform-dir> <terraform-command> [args...]
# Example: ./terraform-wrapper.sh terraform plan
# Example: ./terraform-wrapper.sh terraform-labs apply

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get repo root (one level up from deploy/)
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source environment configuration from repo root
if [ -f "$REPO_ROOT/.env" ]; then
    if [ -L "$REPO_ROOT/.env" ]; then
        TARGET=$(readlink "$REPO_ROOT/.env")
        echo "📋 Using .env -> $TARGET"
    else
        echo "📋 Using .env"
    fi
    source "$REPO_ROOT/.env"
elif [ -f "$REPO_ROOT/.env.prd" ]; then
    echo "📋 Using .env.prd from repo root (create symlink: ln -s .env.prd .env)"
    source "$REPO_ROOT/.env.prd"
elif [ -f "$REPO_ROOT/.env.stg" ]; then
    echo "📋 Using .env.stg from repo root (create symlink: ln -s .env.stg .env)"
    source "$REPO_ROOT/.env.stg"
else
    echo "❌ .env file not found in repo root: $REPO_ROOT"
    echo ""
    echo "Please create a .env file in repo root:"
    echo "  ln -s .env.stg .env  # for staging"
    echo "  ln -s .env.prd .env  # for production"
    exit 1
fi

# Parse arguments
TERRAFORM_DIR="$1"
TERRAFORM_CMD="$2"
shift 2 || {
    echo "Usage: $0 <terraform-dir> <terraform-command> [args...]"
    echo ""
    echo "Examples:"
    echo "  $0 terraform plan"
    echo "  $0 terraform-labs apply"
    echo "  $0 terraform-home init"
    exit 1
}

# Determine environment from project ID
if [[ "$LABS_PROJECT_ID" == *"-stg" ]] || [[ "$HOME_PROJECT_ID" == *"-stg" ]]; then
    ENVIRONMENT="stg"
elif [[ "$LABS_PROJECT_ID" == *"-prd" ]] || [[ "$HOME_PROJECT_ID" == *"-prd" ]]; then
    ENVIRONMENT="prd"
else
    echo "❌ Cannot determine environment from project IDs:"
    echo "   LABS_PROJECT_ID: ${LABS_PROJECT_ID:-not set}"
    echo "   HOME_PROJECT_ID: ${HOME_PROJECT_ID:-not set}"
    echo "   Project IDs must end with -stg or -prd"
    echo "   Or set ENVIRONMENT environment variable explicitly (stg or prd)"
    exit 1
fi

# Verify environment is explicitly set
if [ -z "$ENVIRONMENT" ]; then
    echo "❌ ENVIRONMENT must be explicitly set (stg or prd)"
    echo "   Set it in .env file or as environment variable"
    exit 1
fi

# Determine project ID based on terraform directory
case "$TERRAFORM_DIR" in
    terraform)
        PROJECT_ID="${LABS_PROJECT_ID:-labs-prd}"
        ;;
    terraform-labs)
        PROJECT_ID="${LABS_PROJECT_ID:-labs-prd}"
        ;;
    terraform-home)
        PROJECT_ID="${HOME_PROJECT_ID:-labs-home-prd}"
        ;;
    *)
        echo "❌ Unknown terraform directory: $TERRAFORM_DIR"
        echo "   Valid options: terraform, terraform-labs, terraform-home"
        exit 1
        ;;
esac

REGION="${LABS_REGION:-${HOME_REGION:-us-central1}}"

echo "🔧 Terraform Wrapper"
echo "==================="
echo "Directory: $TERRAFORM_DIR"
echo "Command: $TERRAFORM_CMD"
echo "Environment: $ENVIRONMENT"
echo "Project ID: $PROJECT_ID"
echo ""

cd "$SCRIPT_DIR/$TERRAFORM_DIR"

# Handle init command specially - needs backend config
if [ "$TERRAFORM_CMD" = "init" ]; then
    BACKEND_CONFIG="backend-${ENVIRONMENT}.conf"
    if [ -f "$BACKEND_CONFIG" ]; then
        echo "📋 Using backend config: $BACKEND_CONFIG"
        terraform init -backend-config="$BACKEND_CONFIG" "$@"
    else
        echo "❌ Backend config not found: $BACKEND_CONFIG"
        exit 1
    fi
# Handle plan/apply commands - add common variables
elif [ "$TERRAFORM_CMD" = "plan" ] || [ "$TERRAFORM_CMD" = "apply" ]; then
    # Check if already initialized
    if [ ! -d ".terraform" ]; then
        echo "⚠️  Terraform not initialized. Running init first..."
        BACKEND_CONFIG="backend-${ENVIRONMENT}.conf"
        terraform init -backend-config="$BACKEND_CONFIG"
    fi

    # Add common variables if not already provided
    # Note: project_id and labs_project_id are calculated from environment in all terraform configs
    # Note: region defaults to us-central1, so we don't need to pass it
    VAR_ARGS=(
        "-var=environment=$ENVIRONMENT"
    )

    # Add deploy_services for terraform-labs and terraform-home
    if [ "$TERRAFORM_DIR" = "terraform-labs" ] || [ "$TERRAFORM_DIR" = "terraform-home" ]; then
        VAR_ARGS+=("-var=deploy_services=true")
    fi

    terraform "$TERRAFORM_CMD" "${VAR_ARGS[@]}" "$@"
else
    # For other commands, just pass through
    terraform "$TERRAFORM_CMD" "$@"
fi
