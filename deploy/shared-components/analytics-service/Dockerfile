FROM golang:1.24.3-alpine AS builder

WORKDIR /app

# Copy go.mod and go.sum first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o analytics-service main.go

FROM alpine:3.20
RUN apk --no-cache add ca-certificates
WORKDIR /app

COPY --from=builder /app/analytics-service .
RUN adduser -D -s /bin/sh appuser
USER appuser

EXPOSE 8080
CMD ["./analytics-service"]

