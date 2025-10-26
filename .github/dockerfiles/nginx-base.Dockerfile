# Golden base image for Go services
# This image contains common Go dependencies and build tools
# Used by: home-index-service, seo-service, analytics-service

FROM golang:1.24.3-alpine AS base

# Install common build dependencies
RUN apk add --no-cache \
    git \
    ca-certificates \
    tzdata \
    make \
    gcc \
    musl-dev

# Set up Go environment
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    GOPROXY=https://proxy.golang.org,direct \
    GOSUMDB=sum.golang.org

# Create cache directory for Go modules
RUN mkdir -p /go/pkg/mod/cache

# Pre-install common dependencies used across services
RUN go install github.com/gorilla/mux@latest && \
    go install cloud.google.com/go/firestore@latest && \
    go install gopkg.in/yaml.v3@latest

# Create a common go.mod template
RUN cat > /tmp/common-go.mod << 'EOF'
module common-base

go 1.24

require (
    github.com/gorilla/mux v1.8.1
    cloud.google.com/go/firestore v1.20.0
    gopkg.in/yaml.v3 v3.0.1
)
EOF

# Download common dependencies to cache
WORKDIR /tmp
RUN go mod download

# Create final stage with common tools
FROM alpine:3.20

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    curl \
    wget

# Copy Go binary cache (if needed for debugging)
COPY --from=base /go/bin/* /usr/local/bin/

# Create app user
RUN adduser -D -s /bin/sh appuser

# Set working directory
WORKDIR /app

# This base image provides common Go dependencies
# Individual services should copy their source and build

