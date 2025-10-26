FROM golang:1.24.3-alpine AS builder
RUN apk add --no-cache git ca-certificates

WORKDIR /app
COPY go.mod ./
RUN go mod download

COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o seo-service main.go

FROM alpine:3.20
RUN apk --no-cache add ca-certificates
RUN adduser -D -s /bin/sh appuser
WORKDIR /app

COPY --from=builder /app/seo-service .
USER appuser

EXPOSE 8080
CMD ["./seo-service"]
