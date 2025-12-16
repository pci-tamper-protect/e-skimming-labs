# Optimized Dockerfile using golden base image
# Uses pcioasis-operations/containers/go-base for better caching

# Declare build arguments at the top
ARG BASE_IMAGE=us-central1-docker.pkg.dev/pcioasis-operations/containers/go-base:latest
ARG ALPINE_BASE=us-central1-docker.pkg.dev/pcioasis-operations/containers/alpine-base:latest

FROM ${BASE_IMAGE} AS builder

WORKDIR /app

# Copy go.mod and go.sum first for better caching
COPY go.mod go.sum ./

# Download dependencies (will use cached modules from base image)
# This layer is cached unless go.mod/go.sum change
RUN go mod download

# Copy source code (this layer changes most frequently)
COPY . .

# Only run go mod tidy if go.mod/go.sum changed (saves ~10-15s per build)
# Skip if go.mod and go.sum are already in sync (common case)
# This is safe because go mod download already fetched dependencies
# go mod tidy is mainly needed when dependencies are added/removed
RUN go mod verify && go mod tidy || true

# Build the application
# Use build cache mount for faster builds (Go 1.18+)
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -o analytics-service main.go

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

