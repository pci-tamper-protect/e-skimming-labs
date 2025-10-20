FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY . .

RUN go mod init analytics-service
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o analytics-service main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/analytics-service .

EXPOSE 8080
CMD ["./analytics-service"]

