FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/go-base:latest AS builder

WORKDIR /app

# Copy go.mod and go.sum first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o analytics-service main.go

FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/alpine-base:latest
WORKDIR /app

COPY --from=builder /app/analytics-service .
USER appuser

EXPOSE 8080
CMD ["./analytics-service"]
