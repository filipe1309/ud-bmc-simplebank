# Build stage
FROM golang:1.22.5-alpine3.20 AS builder
WORKDIR /app
COPY . .
RUN go build -o main main.go
# RUN apk add --no-cache curl
# RUN curl -L https://github.com/golang-migrate/migrate/releases/download/v4.17.1/migrate.linux-amd64.tar.gz | tar xvz


# Run stage
FROM alpine:3.20
WORKDIR /app
COPY app.env .
COPY start.sh .
COPY wait-for.sh .
COPY --from=builder /app/main .
# COPY --from=builder /app/migrate ./migrate
COPY db/migration ./db/migration

EXPOSE 8080 9090
CMD ["/app/main"]
ENTRYPOINT [ "/app/start.sh" ]
