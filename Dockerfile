FROM docker.io/golang:1.24.5-alpine as golang
FROM docker.io/alpine:latest AS backend

RUN apk update
RUN apk upgrade
RUN apk add --update bash cmake g++ gcc git make vips-dev

# Pinned to the exact toolchain the currently-healthy validator fleet was built with
# (go1.24.5, verified against the running binaries). The previous floating `1.24-alpine`
# tag silently moved to go1.24.13, which meant two images built from the same source
# could differ in compiler version -- an unacceptable property for a consensus binary.
COPY --from=golang /usr/local/go/ /usr/local/go/
ENV PATH="/usr/local/go/bin:${PATH}"
# Never auto-download a newer toolchain than the one pinned above. go.mod asks for
# `toolchain go1.24.1`, which go1.24.5 already satisfies, so this is a guard rather
# than a behaviour change: without it a future go.mod bump would silently re-float.
ENV GOTOOLCHAIN=local

WORKDIR /deso/src

COPY backend/go.mod backend/
COPY backend/go.sum backend/
COPY core/go.mod core/
COPY core/go.sum core/

WORKDIR /deso/src/backend

RUN go mod download

# include backend src
COPY backend/apis      apis
COPY backend/config    config
COPY backend/cmd       cmd
COPY backend/miner     miner
COPY backend/routes    routes
COPY backend/countries countries
COPY backend/main.go   .

# include core src
COPY core/bls         ../core/bls
COPY core/cmd         ../core/cmd
COPY core/collections ../core/collections
COPY core/consensus   ../core/consensus
COPY core/desohash    ../core/desohash
COPY core/lib         ../core/lib
COPY core/migrate     ../core/migrate

ENV GOPATH=/root/go

# build backend
RUN CGO_CFLAGS="-std=gnu11" GOOS=linux go build -mod=mod -a -installsuffix cgo -o bin/backend main.go

# create tiny image
FROM alpine:latest

RUN apk add --update vips-dev

COPY --from=backend /deso/src/backend/bin/backend /deso/bin/backend

ENTRYPOINT ["/deso/bin/backend"]
