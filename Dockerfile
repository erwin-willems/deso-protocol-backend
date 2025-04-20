FROM docker.io/golang:1.23-alpine as golang
FROM docker.io/alpine:latest AS backend

RUN apk update
RUN apk upgrade
RUN apk add --update bash cmake g++ gcc git make vips-dev

COPY --from=golang /usr/local/go/ /usr/local/go/
ENV PATH="/usr/local/go/bin:${PATH}"

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

# Install Delve debugger, specifying the installation path explicitly
ENV GOPATH=/root/go
RUN go install github.com/go-delve/delve/cmd/dlv@v1.23.0

# build backend
RUN GOOS=linux go build -mod=mod -a -installsuffix cgo -o bin/backend main.go

# create tiny image
FROM alpine:latest

RUN apk add --update vips-dev

COPY --from=backend /deso/src/backend/bin/backend /deso/bin/backend

ENTRYPOINT ["/deso/bin/backend"]
