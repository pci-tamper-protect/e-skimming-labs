FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/go-base:latest AS builder

WORKDIR /app
COPY go.mod ./
RUN go mod download

COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o seo-service main.go

FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/alpine-base:latest
WORKDIR /app

COPY --from=builder /app/seo-service .
USER appuser

EXPOSE 8080
CMD ["./seo-service"]
