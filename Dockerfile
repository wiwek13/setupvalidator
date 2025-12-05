# syntax=docker/dockerfile:1.4
# Minimal demo multi-stage Go build; no repo source required.
ARG GO_VERSION=1.21
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine AS builder

ARG VALIDATOR_BUILD_TAG=demo
ARG TARGETOS=linux
ARG TARGETARCH=amd64

WORKDIR /src
RUN apk add --no-cache ca-certificates build-base

# create a tiny Go program at build time (no repo source required)
RUN mkdir -p /src/cmd/validator && cat > /src/cmd/validator/main.go <<'EOF'
package main
import (
  "fmt"
  "net/http"
  "os"
)
func main() {
  http.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request){ fmt.Fprintln(w, "Hello from validator demo") })
  port := os.Getenv("PORT"); if port=="" { port="8080" }
  fmt.Println("validator starting on", port)
  http.ListenAndServe(":" + port, nil)
}
EOF

# Build with cache mounts; optional secret mount for private deps (not required for demo)
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=secret,id=PRIVATE_GIT,required=false \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-X 'main.BuildTag=${VALIDATOR_BUILD_TAG}'" -o /out/validator ./cmd/validator

FROM gcr.io/distroless/static:nonroot AS runtime
COPY --from=builder /out/validator /usr/local/bin/validator
USER nonroot:nonroot
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/validator"]
