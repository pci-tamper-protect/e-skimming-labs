#!/bin/bash

# E-Skimming Labs Docker Compose Management Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start [service]     Start all services or specific service"
    echo "  stop [service]      Stop all services or specific service"
    echo "  restart [service]   Restart all services or specific service"
    echo "  build [service]     Build all services or specific service"
    echo "  logs [service]      Show logs for all services or specific service"
    echo "  status              Show status of all services"
    echo "  clean               Clean up containers, volumes, and images"
    echo "  health              Check health of all services"
    echo "  urls                Show all service URLs"
    echo ""
    echo "Service Groups:"
    echo "  home                Labs-home services (home-index, home-seo, labs-analytics)"
    echo "  lab1                Lab 1: Basic Magecart Attack"
    echo "  lab2                Lab 2: DOM-Based Skimming"
    echo "  lab3                Lab 3: Browser Extension Hijacking"
    echo "  variants            Lab variants (advanced scenarios)"
    echo ""
    echo "Examples:"
    echo "  $0 start            # Start all services"
    echo "  $0 start home       # Start only labs-home services"
    echo "  $0 logs lab1        # Show logs for Lab 1 services"
    echo "  $0 build home-index # Build only home-index service"
}

# Function to start services
start_services() {
    local service=$1
    
    if [ -z "$service" ]; then
        print_header "Starting All E-Skimming Labs Services"
        docker-compose up -d
        print_status "All services started successfully!"
    else
        case $service in
            home)
                print_header "Starting Labs-Home Services"
                docker-compose up -d home-index home-seo labs-analytics
                ;;
            lab1)
                print_header "Starting Lab 1: Basic Magecart Attack"
                docker-compose up -d lab1-vulnerable-site lab1-c2-server
                ;;
            lab2)
                print_header "Starting Lab 2: DOM-Based Skimming"
                docker-compose up -d lab2-vulnerable-site lab2-c2-server
                ;;
            lab3)
                print_header "Starting Lab 3: Browser Extension Hijacking"
                docker-compose up -d lab3-vulnerable-site lab3-extension-server
                ;;
            variants)
                print_header "Starting Lab Variants"
                docker-compose up -d lab1-event-listener-variant lab1-obfuscated-variant lab1-websocket-variant
                ;;
            *)
                print_header "Starting $service"
                docker-compose up -d "$service"
                ;;
        esac
        print_status "$service services started successfully!"
    fi
}

# Function to stop services
stop_services() {
    local service=$1
    
    if [ -z "$service" ]; then
        print_header "Stopping All Services"
        docker-compose down
        print_status "All services stopped successfully!"
    else
        case $service in
            home)
                docker-compose stop home-index home-seo labs-analytics
                ;;
            lab1)
                docker-compose stop lab1-vulnerable-site lab1-c2-server
                ;;
            lab2)
                docker-compose stop lab2-vulnerable-site lab2-c2-server
                ;;
            lab3)
                docker-compose stop lab3-vulnerable-site lab3-extension-server
                ;;
            variants)
                docker-compose stop lab1-event-listener-variant lab1-obfuscated-variant lab1-websocket-variant
                ;;
            *)
                docker-compose stop "$service"
                ;;
        esac
        print_status "$service services stopped successfully!"
    fi
}

# Function to restart services
restart_services() {
    local service=$1
    
    if [ -z "$service" ]; then
        print_header "Restarting All Services"
        docker-compose restart
        print_status "All services restarted successfully!"
    else
        case $service in
            home)
                docker-compose restart home-index home-seo labs-analytics
                ;;
            lab1)
                docker-compose restart lab1-vulnerable-site lab1-c2-server
                ;;
            lab2)
                docker-compose restart lab2-vulnerable-site lab2-c2-server
                ;;
            lab3)
                docker-compose restart lab3-vulnerable-site lab3-extension-server
                ;;
            variants)
                docker-compose restart lab1-event-listener-variant lab1-obfuscated-variant lab1-websocket-variant
                ;;
            *)
                docker-compose restart "$service"
                ;;
        esac
        print_status "$service services restarted successfully!"
    fi
}

# Function to build services
build_services() {
    local service=$1
    
    if [ -z "$service" ]; then
        print_header "Building All Services"
        docker-compose build
        print_status "All services built successfully!"
    else
        print_header "Building $service"
        docker-compose build "$service"
        print_status "$service built successfully!"
    fi
}

# Function to show logs
show_logs() {
    local service=$1
    
    if [ -z "$service" ]; then
        print_header "Showing Logs for All Services"
        docker-compose logs -f
    else
        print_header "Showing Logs for $service"
        docker-compose logs -f "$service"
    fi
}

# Function to show status
show_status() {
    print_header "Service Status"
    docker-compose ps
}

# Function to clean up
clean_up() {
    print_header "Cleaning Up Docker Resources"
    print_warning "This will remove all containers, volumes, and images!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose down -v --rmi all --remove-orphans
        docker system prune -f
        print_status "Cleanup completed successfully!"
    else
        print_status "Cleanup cancelled."
    fi
}

# Function to check health
check_health() {
    print_header "Service Health Check"
    docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
}

# Function to show URLs
show_urls() {
    print_header "Service URLs"
    echo ""
    echo "🏠 Labs-Home Services:"
    echo "  Home Index:     http://localhost:8080"
    echo "  SEO Service:    http://localhost:8081"
    echo "  Analytics:      http://localhost:8082"
    echo ""
    echo "🧪 Individual Labs:"
    echo "  Lab 1 Site:     http://localhost:9001"
    echo "  Lab 1 C2:       http://localhost:9002"
    echo "  Lab 2 Site:     http://localhost:9003"
    echo "  Lab 2 C2:       http://localhost:9004"
    echo "  Lab 3 Site:     http://localhost:9005"
    echo "  Lab 3 Server:   http://localhost:9006"
    echo ""
    echo "🔬 Lab Variants:"
    echo "  Event Listener: http://localhost:9011"
    echo "  Obfuscated:     http://localhost:9012"
    echo "  WebSocket:      http://localhost:9013"
    echo ""
    echo "📚 Resources:"
    echo "  MITRE ATT&CK:  http://localhost:8080/mitre-attack"
    echo "  Threat Model:   http://localhost:8080/threat-model"
    echo "  Labs API:      http://localhost:8080/api/labs"
}

# Main script logic
case $1 in
    start)
        start_services $2
        ;;
    stop)
        stop_services $2
        ;;
    restart)
        restart_services $2
        ;;
    build)
        build_services $2
        ;;
    logs)
        show_logs $2
        ;;
    status)
        show_status
        ;;
    clean)
        clean_up
        ;;
    health)
        check_health
        ;;
    urls)
        show_urls
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac


