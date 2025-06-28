# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o claude-proxy main.go

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates docker-cli
WORKDIR /root/

COPY --from=builder /app/claude-proxy .

EXPOSE 64008

CMD ["./claude-proxy"]