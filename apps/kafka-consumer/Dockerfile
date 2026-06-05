FROM golang:1.22-alpine AS builder
RUN apk add --no-cache ca-certificates git
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /app/consumer ./cmd/consumer

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /app/consumer /consumer
EXPOSE 8080
ENTRYPOINT ["/consumer"]
