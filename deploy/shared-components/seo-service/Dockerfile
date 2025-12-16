# Optimized Dockerfile using golden base image
# Uses pcioasis-operations/containers/go-base for better caching

# Declare build arguments at the top
ARG BASE_IMAGE=us-central1-docker.pkg.dev/pcioasis-operations/containers/go-base:latest
ARG ALPINE_BASE=us-central1-docker.pkg.dev/pcioasis-operations/containers/alpine-base:latest

FROM ${BASE_IMAGE} AS builder

WORKDIR /app

# Configure Go environment with retry-friendly settings
# Use multiple proxies with fallback, and set longer timeouts
ENV GOPROXY=https://proxy.golang.org,direct \
    GOSUMDB=sum.golang.org \
    GOPRIVATE= \
    GONOPROXY= \
    GONOSUMDB= \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

# Copy go.mod first for better caching
COPY go.mod go.sum* ./

# Download dependencies with retry logic to handle transient network errors
# Retry up to 5 times with exponential backoff (2s, 4s, 6s, 8s, 10s delays)
RUN for i in 1 2 3 4 5; do \
        echo "Attempt $i/5: Downloading Go modules..."; \
        if go mod download 2>&1; then \
            echo "✓ Successfully downloaded modules on attempt $i"; \
            exit 0; \
        else \
            exit_code=$?; \
            if [ $i -eq 5 ]; then \
                echo "✗ All 5 attempts failed (exit code: $exit_code). Check network connectivity and Go proxy settings."; \
                exit 1; \
            else \
                wait_time=$((i * 2)); \
                echo "✗ Attempt $i failed (exit code: $exit_code). Waiting ${wait_time}s before retry..."; \
                sleep $wait_time; \
            fi; \
        fi; \
    done

# Copy source code (this layer changes most frequently)
COPY . .

# Verify go.mod is valid and update if needed (non-fatal if tidy makes changes)
RUN go mod verify && go mod tidy || true

# Build the application
# Use '.' to build the current package (not 'main.go' which Go interprets as a package path)
RUN go build -o seo-service .

# Final stage using alpine-base
FROM ${ALPINE_BASE} AS runtime

WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /app/seo-service .

# Set ownership (alpine-base already has appuser)
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8080
CMD ["./seo-service"]

