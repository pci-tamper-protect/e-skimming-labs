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

# Copy go.mod and go.sum first for better caching
COPY go.mod go.sum ./
# Download dependencies (will use cached modules from base image)
# This layer is cached unless go.mod/go.sum change
RUN go mod download

# Copy source code (this layer changes most frequently)
COPY . .

# Final stage using alpine-base
FROM ${ALPINE_BASE} AS runtime

WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /app/analytics-service .

# Set ownership (alpine-base already has appuser)
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8080
CMD ["./analytics-service"]
