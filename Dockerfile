# FROM golang:1.17 as build-env

# WORKDIR /build

# RUN apt update
# RUN apt install -y git build-essential

# RUN mkdir /build/bin

# RUN git clone https://github.com/binaryholdings/cosmprund.git

# WORKDIR /build/cosmprund

# RUN make build && \
#   mv build/cosmprund /build/bin/cosmprund-goleveldb

# WORKDIR /build
# RUN git clone https://github.com/notional-labs/cosmprund.git cosmprund-pebbledb

# WORKDIR /build/cosmprund-pebbledb

# RUN make build && \
#   mv build/cosmos-pruner /build/bin/cosmprund-pebbledb

#---
FROM ubuntu

RUN apt update
RUN apt install -y curl jq liblz4-tool wget
RUN apt clean

WORKDIR /root

# COPY --from=build-env /build/bin/cosmprund* /usr/bin/

RUN curl -L https://github.com/cosmos/cosmos-sdk/releases/download/cosmovisor%2Fv1.5.0/cosmovisor-v1.5.0-linux-amd64.tar.gz | tar xz && mv cosmovisor /usr/bin/cosmovisor
COPY priv_validator_state.json priv_validator_state.json
COPY entrypoint.sh /usr/bin/entrypoint.sh
COPY ready-check.sh /usr/bin/ready-check.sh
COPY health-check.sh /usr/bin/health-check.sh

# RUN chmod +x /usr/bin/cosmovisor /usr/bin/cosmprund* /usr/bin/entrypoint.sh /usr/bin/ready-check.sh /usr/bin/health-check.sh
RUN chmod +x /usr/bin/cosmovisor /usr/bin/entrypoint.sh /usr/bin/ready-check.sh /usr/bin/health-check.sh

ENTRYPOINT [ "entrypoint.sh" ]
