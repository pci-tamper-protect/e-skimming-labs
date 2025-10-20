FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY . .

RUN go mod init seo-service
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o seo-service main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/seo-service .

EXPOSE 8080
CMD ["./seo-service"]

