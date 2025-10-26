# Build stage
FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/go-base:latest AS builder

# Set working directory
WORKDIR /app

# Copy go.mod from the home-index-service directory (no go.sum needed for no external deps)
COPY deploy/shared-components/home-index-service/go.mod ./

# Download dependencies
RUN go mod download

# Copy source code from the home-index-service directory
COPY deploy/shared-components/home-index-service/ .

# Generate go.sum and build the application
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Final stage
FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/alpine-base:latest

# Create app directory
WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /app/main .

# Copy the docs directory for MITRE ATT&CK and threat model pages
COPY docs ./docs

# Copy catalog info for service metadata
COPY catalog-info.yaml ./catalog-info.yaml

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run the application
CMD ["./main"]
