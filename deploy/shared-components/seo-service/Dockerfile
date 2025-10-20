FROM golang:1.24.3-alpine AS builder

WORKDIR /app
COPY . .

RUN go mod init seo-service
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o seo-service main.go

FROM alpine:3.20
RUN apk --no-cache add ca-certificates
WORKDIR /app

COPY --from=builder /app/seo-service .
RUN adduser -D -s /bin/sh appuser
USER appuser

EXPOSE 8080
CMD ["./seo-service"]

