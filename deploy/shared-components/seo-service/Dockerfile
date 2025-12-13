# Optimized Dockerfile using golden base image
# Uses pcioasis-operations/containers/go-base for better caching

# Declare build arguments at the top
ARG BASE_IMAGE=us-central1-docker.pkg.dev/pcioasis-operations/containers/go-base:latest
ARG ALPINE_BASE=us-central1-docker.pkg.dev/pcioasis-operations/containers/alpine-base:latest

FROM ${BASE_IMAGE} AS builder

WORKDIR /app

# Copy go.mod first for better caching
COPY go.mod go.sum* ./

# Download dependencies (will use cached modules from base image)
RUN go mod download

# Copy source code (this layer changes most frequently)
COPY . .

# Update go.mod if needed
RUN go mod tidy

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o seo-service main.go

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

