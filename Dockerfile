# ---- Build stage ----
FROM golang:1.24-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o eventapp ./cmd/app

# ---- Runtime stage ----
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

COPY --from=builder /app/eventapp .
COPY --from=builder /app/migrations ./migrations

EXPOSE 8080

CMD ["./eventapp"]
