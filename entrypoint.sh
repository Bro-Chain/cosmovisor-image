#!/bin/bash
if [[ -n "$DEBUG" ]]; then
    set -x
fi

# export MONIKER=MyMoniker
# export DAEMON_HOME=$HOME/.simd
# export DAEMON_NAME=simd
# DAEMON_GENESIS="v0"
# DAEMON_UPGRADES="v1 v2 v3"

: ${PRUNING_STRATEGY:=custom}
: ${PRUNING_KEEP_RECENT:=100}
: ${PRUNING_INTERVAL:=10}
: ${PRUNING_KEEP_EVERY:=0}
: ${SNAPSHOT_INTERVAL:=0}
: ${KEEP_SNAPSHOTS:=2}
: ${TRUST_LOOKBACK:=2000}
: ${DB_BACKEND:=goleveldb}
: ${ENABLE_API:=true}
: ${USE_P2P:=true}

# SEI specific
: ${MAX_BLOCKS_BEHIND:=50}

export UNSAFE_SKIP_BACKUP=true
CONFIG_DIR=$DAEMON_HOME/config
DATA_DIR=$DAEMON_HOME/data
GENESIS_FILE=$CONFIG_DIR/genesis.json
ADDR_BOOK_FILE=$CONFIG_DIR/addrbook.json

# ------------------------------------------------------------------------------------
# Set up cosmovisor and binary versions
# ------------------------------------------------------------------------------------

if [[ -n "${NODE_DEBUG_STARTUP_SLEEP}" ]]; then
    echo "Sleeping for $NODE_DEBUG_STARTUP_SLEEP seconds..."
    sleep $NODE_DEBUG_STARTUP_SLEEP
fi

mkdir -p $DAEMON_HOME/cosmovisor/genesis/bin
cp /usr/bin/$DAEMON_GENESIS $DAEMON_HOME/cosmovisor/genesis/bin/$DAEMON_NAME
CURRENT_GUESS=genesis

cd $DAEMON_HOME/cosmovisor

if [[ -d "/root/lib/genesis" ]]; then
    mkdir -p genesis/lib
    cp /root/lib/genesis/* genesis/lib/
    export LD_LIBRARY_PATH=$DAEMON_HOME/cosmovisor/current/lib
fi

mkdir -p upgrades
cd upgrades

for UPGRADE in $DAEMON_UPGRADES; do
    mkdir -p $UPGRADE/bin
    cp /usr/bin/$DAEMON_NAME-$UPGRADE $UPGRADE/bin/$DAEMON_NAME
    if [[ -d "/root/lib/$UPGRADE" ]]; then
        mkdir -p $UPGRADE/lib
        cp /root/lib/$UPGRADE/* $UPGRADE/lib/
        export LD_LIBRARY_PATH=$DAEMON_HOME/cosmovisor/current/lib
    fi
    CURRENT_GUESS=upgrades/$UPGRADE
done

if [[ ! -f $DAEMON_HOME/cosmovisor/current/bin/$DAEMON_NAME ]]; then
    if [[ -z "${START_AT_VERSION}" ]]; then
        ln -s $DAEMON_HOME/cosmovisor/$CURRENT_GUESS $DAEMON_HOME/cosmovisor/current
    else
        ln -s $DAEMON_HOME/cosmovisor/upgrades/$START_AT_VERSION $DAEMON_HOME/cosmovisor/current
    fi
fi

if [[ -f $DAEMON_HOME/cosmovisor/current/bin/$DAEMON_NAME ]]; then
    rm /usr/bin/$DAEMON_NAME
    ln -s $DAEMON_HOME/cosmovisor/current/bin/$DAEMON_NAME /usr/bin/$DAEMON_NAME
fi

# ------------------------------------------------------------------------------------
# If the chain has not been initialized before, init and download genesis
# ------------------------------------------------------------------------------------
if [ ! -d "$CONFIG_DIR" ] || [ ! -f "$GENESIS_FILE" ]; then
    echo "Initializing node from scratch..."
    $DAEMON_NAME config chain-id $CHAIN_ID
    $DAEMON_NAME init $MONIKER --chain-id $CHAIN_ID -o

    # Happens for chain that don't have a config command,
    # causing the following genesis download to fail if we don't create it
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir "$CONFIG_DIR"
    fi

    if [[ -n "${GENESIS_URL}" ]]; then
        echo "Downloading genesis file..."
        if [[ "$GENESIS_URL" == *.tar.gz ]]; then
            curl -L $GENESIS_URL | tar -xz >$GENESIS_FILE
        elif [[ "$GENESIS_URL" == *.gz ]]; then
            curl -L $GENESIS_URL | zcat >$GENESIS_FILE
        else
            curl -L $GENESIS_URL >$GENESIS_FILE
        fi
    fi
    if [[ -n "${ADDR_BOOK_URL}" ]]; then
        echo "Downloading address book file..."
        curl -L $ADDR_BOOK_URL >$ADDR_BOOK_FILE
    fi
    if [[ ! -f "${DATA_DIR}/priv_validator_state.json" ]]; then
        echo "Initalizing data folder..."
        mkdir -p "${DATA_DIR}"
        cp /root/priv_validator_state.json "${DATA_DIR}/priv_validator_state.json"
    fi
fi

$DAEMON_NAME validate-genesis

# ------------------------------------------------------------------------------------
# For a validator node, the private validator node key should be supplied by the environment
# ------------------------------------------------------------------------------------
PRIVATE_VALIDATOR_KEY_FILE=$CONFIG_DIR/priv_validator_key.json
if [[ -z "${PRIVATE_VALIDATOR_KEY}" ]]; then
    echo "Using unique private key..."
else
    echo "Using existing private key..."
    echo $PRIVATE_VALIDATOR_KEY
    { # try
        echo $PRIVATE_VALIDATOR_KEY | base64 -d >$PRIVATE_VALIDATOR_KEY_FILE
    } || { # catch
        echo "FAILURE! FALLBACK!"
    }
fi

NODE_KEY_FILE=$CONFIG_DIR/node_key.json
if [[ -n "${NODE_KEY}" ]]; then
    echo "Using existing node key..."
    echo $NODE_KEY
    { # try
        echo $NODE_KEY | base64 -d >$NODE_KEY_FILE
    } || { # catch
        echo "FAILURE! FALLBACK!"
    }
fi

# ------------------------------------------------------------------------------------
# Update config
# ------------------------------------------------------------------------------------

sed -i.bak -e "s|^chain-id *=.*|chain-id = \"$CHAIN_ID\"|" $CONFIG_DIR/client.toml

if [[ "$IS_SEED_NODE" == "true" ]]; then
    sed -i.bak -e "s|^seed_mode *=.*|seed_mode = true|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^seed-mode *=.*|seed-mode = true|" $CONFIG_DIR/config.toml
fi
if [[ -n "$NODE_MODE" ]]; then
    sed -i.bak -e "s|^mode *=.*|mode = \"$NODE_MODE\"|" $CONFIG_DIR/config.toml
fi
sed -i.bak -e "s|^laddr *=\s*\"tcp:\/\/127.0.0.1|laddr = \"tcp:\/\/0.0.0.0|" $CONFIG_DIR/config.toml
sed -i.bak -e "s|^prometheus *=.*|prometheus = true|" $CONFIG_DIR/config.toml

sed -i.bak -e "s|^seeds *=.*|seeds = \"$SEEDS\"|" $CONFIG_DIR/config.toml
sed -i.bak -e "s|^persistent_peers *=.*|persistent_peers = \"$PERSISTENT_PEERS\"|" $CONFIG_DIR/config.toml
sed -i.bak -e "s|^persistent-peers *=.*|persistent-peers = \"$PERSISTENT_PEERS\"|" $CONFIG_DIR/config.toml
sed -i.bak -e "s|^unconditional_peer_ids *=.*|unconditional_peer_ids = \"$UNCONDITIONAL_PEER_IDS\"|" $CONFIG_DIR/config.toml
sed -i.bak -e "s|^unconditional-peer-ids *=.*|unconditional-peer-ids = \"$UNCONDITIONAL_PEER_IDS\"|" $CONFIG_DIR/config.toml
sed -i.bak -e "s|^bootstrap-peers *=.*|bootstrap-peers = \"$BOOTSTRAP_PEERS\"|" $CONFIG_DIR/config.toml
sed -i.bak -e "s|^allow_duplicate_ip *=.*|allow_duplicate_ip = true|" $CONFIG_DIR/config.toml
sed -i.bak -e "s|^allow-duplicate-ip *=.*|allow-duplicate-ip = true|" $CONFIG_DIR/config.toml
sed -i.bak -e "s|^addr_book_strict *=.*|addr_book_strict = false|" $CONFIG_DIR/config.toml
sed -i.bak -e "s|^addr-book-strict *=.*|addr-book-strict = false|" $CONFIG_DIR/config.toml

if [[ "$USE_P2P" == "true" ]]; then
    sed -i.bak -e "s|^use-p2p *=.*|use-p2p = true|" $CONFIG_DIR/config.toml
fi

if [[ -n "$MAX_PAYLOAD" ]]; then
    sed -i.bak -e "s|^max_packet_msg_payload_size *=.*|max_packet_msg_payload_size = $MAX_PAYLOAD|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^max-packet-msg-payload-size *=.*|max-packet-msg-payload-size = $MAX_PAYLOAD|" $CONFIG_DIR/config.toml
fi

if [[ -n "$MAX_TXS_BYTES" ]]; then
    sed -i.bak -e "s|^max_txs_bytes *=.*|max_txs_bytes = $MAX_TXS_BYTES|" $CONFIG_DIR/config.toml
fi

if [[ -n "$MAX_TX_BYTES" ]]; then
    sed -i.bak -e "s|^max_tx_bytes *=.*|max_tx_bytes = $MAX_TX_BYTES|" $CONFIG_DIR/config.toml
fi

if [[ -n "$MAX_IN_PEERS" ]]; then
    sed -i.bak -e "s|^max_num_inbound_peers *=.*|max_num_inbound_peers = $MAX_IN_PEERS|" $CONFIG_DIR/config.toml
fi

if [[ -n "$MAX_OUT_PEERS" ]]; then
    sed -i.bak -e "s|^max_num_outbound_peers *=.*|max_num_outbound_peers = $MAX_OUT_PEERS|" $CONFIG_DIR/config.toml
fi

if [[ -n "$FLUSH_THROTTLE_TIMEOUT" ]]; then
    sed -i.bak -e "s|^flush_throttle_timeout *=.*|flush_throttle_timeout = \"$FLUSH_THROTTLE_TIMEOUT\"|" $CONFIG_DIR/config.toml
fi

if [[ -n "$DIAL_TIMEOUT" ]]; then
    sed -i.bak -e "s|^dial_timeout *=.*|dial_timeout = \"$DIAL_TIMEOUT\"|" $CONFIG_DIR/config.toml
fi

if [[ -n "$HANDSHAKE_TIMEOUT" ]]; then
    sed -i.bak -e "s|^handshake_timeout *=.*|handshake_timeout = \"$HANDSHAKE_TIMEOUT\"|" $CONFIG_DIR/config.toml
fi

sed -i.bak -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"$MINIMUM_GAS_PRICE\"|" $CONFIG_DIR/app.toml
sed -i.bak -e "s|^pruning *=.*|pruning = \"$PRUNING_STRATEGY\"|" $CONFIG_DIR/app.toml
sed -i.bak -e "s|^pruning-keep-recent *=.*|pruning-keep-recent = \"$PRUNING_KEEP_RECENT\"|" $CONFIG_DIR/app.toml
sed -i.bak -e "s|^pruning-interval *=.*|pruning-interval = \"$PRUNING_INTERVAL\"|" $CONFIG_DIR/app.toml
sed -i.bak -e "s|^pruning-keep-every *=.*|pruning-keep-every = \"$PRUNING_KEEP_EVERY\"|" $CONFIG_DIR/app.toml
sed -i.bak -e "s|^snapshot-interval *=.*|snapshot-interval = \"$SNAPSHOT_INTERVAL\"|" $CONFIG_DIR/app.toml
sed -i.bak -e "s|^snapshot-keep-recent *=.*|snapshot-keep-recent = \"$KEEP_SNAPSHOTS\"|" $CONFIG_DIR/app.toml

if [[ "$ENABLE_API" == "true" ]]; then
    sed -i.bak "/\[api\]/,+3 s|enable = false|enable = true|" $CONFIG_DIR/app.toml
fi

if [[ "$USE_HORCRUX" == "true" ]]; then
    sed -i.bak -e "s|^priv_validator_laddr *=.*|priv_validator_laddr = \"tcp://[::]:23756\"|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^laddr *= \"\"|laddr = \"tcp://[::]:23756\"|" $CONFIG_DIR/config.toml
fi

if [[ -n "$DB_BACKEND" ]]; then
    sed -i.bak -e "s|^db_backend *=.*|db_backend = \"$DB_BACKEND\"|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^db-backend *=.*|db-backend = \"$DB_BACKEND\"|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^app-db-backend *=.*|app-db-backend = \"$DB_BACKEND\"|" $CONFIG_DIR/app.toml
fi

if [[ "$SENTRIED_VALIDATOR" == "true" ]]; then
    sed -i.bak -e "s|^pex *=.*|pex = false|" $CONFIG_DIR/config.toml
fi

if [[ "$IS_SENTRY" == "true" || -n "$PRIVATE_PEER_IDS" ]]; then
    sed -i.bak -e "s|^private_peer_ids *=.*|private_peer_ids = \"$PRIVATE_PEER_IDS\"|" $CONFIG_DIR/config.toml
fi

if [[ -n "$PUBLIC_ADDRESS" ]]; then
    echo "Setting public address to $PUBLIC_ADDRESS"
    sed -i.bak -e "s|^external_address *=.*|external_address = \"$PUBLIC_ADDRESS\"|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^external-address *=.*|external-address = \"$PUBLIC_ADDRESS\"|" $CONFIG_DIR/config.toml
fi

# Specific settings for SEI
if [[ "$DAEMON_NAME" == "seid" ]]; then
    sed -i.bak -e "s|^p2p-no-peers-available-window-seconds *=.*|p2p-no-peers-available-window-seconds = 30|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^statesync-no-peers-available-window-seconds *=.*|statesync-no-peers-available-window-seconds = 30|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^blocks-behind-threshold *=.*|blocks-behind-threshold = $MAX_BLOCKS_BEHIND|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^blocks-behind-check-interval *=.*|blocks-behind-check-interval = 30|" $CONFIG_DIR/config.toml

    if [[ -n "$USE_SEIDB" ]]; then
        sed -i.bak -e "s|^sc-enable *=.*|sc-enable = true|" $CONFIG_DIR/app.toml

        if [[ "$SNAPSHOT_INTERVAL" == "0" ]]; then
            sed -i.bak -e "s|^ss-enable *=.*|ss-enable = false|" $CONFIG_DIR/app.toml
        else
            sed -i.bak -e "s|^ss-enable *=.*|ss-enable = true|" $CONFIG_DIR/app.toml
            sed -i.bak -e "s|^ss-keep-recent *=.*|ss-keep-recent = \"$PRUNING_KEEP_RECENT\"|" $CONFIG_DIR/app.toml
        fi
    else
        sed -i.bak -e "s|^sc-enable *=.*|sc-enable = false|" $CONFIG_DIR/app.toml
        sed -i.bak -e "s|^ss-enable *=.*|ss-enable = false|" $CONFIG_DIR/app.toml
    fi
    if [[ ! $(grep concurrency-workers $CONFIG_DIR/app.toml) ]]; then
        sed -i.bak "/###                           Base Configuration                            ###/,+2 s|^$|\nconcurrency-workers = 500\nocc-enabled = true\n|" $CONFIG_DIR/app.toml
    else
        sed -i.bak -e "s|^# concurrency-workers *=.*|concurrency-workers = 500|" $CONFIG_DIR/app.toml
        sed -i.bak -e "s|^concurrency-workers *=.*|concurrency-workers = 500|" $CONFIG_DIR/app.toml
        sed -i.bak -e "s|^occ-enabled *=.*|occ-enabled = true|" $CONFIG_DIR/app.toml
    fi
fi

if [[ -n "$MEMPOOL_SIZE" ]]; then
    sed -i.bak -e "s|^size *= 1000|size = $MEMPOOL_SIZE|" $CONFIG_DIR/config.toml
fi

# ------------------------------------------------------------------------------------
# Attempt setting up state sync to save on startup time
# ------------------------------------------------------------------------------------

if [[ $STATE_SYNC_ENABLED == "true" ]]; then
    echo "State sync is enabled, attempting to fetch snapshot info..."
    if [[ -z "$FORCE_SNAPSHOT_HEIGHT" ]]; then
        LATEST_HEIGHT=$(curl -s $STATE_SYNC_RPC/block | jq -r .result.block.header.height)
        if [[ "$LATEST_HEIGHT" == "null" ]]; then
            # Maybe Tendermint 0.35+?
            LATEST_HEIGHT=$(curl -s $STATE_SYNC_RPC/block | jq -r .block.header.height)
        fi

        SYNC_BLOCK_HEIGHT=$(($LATEST_HEIGHT - $TRUST_LOOKBACK))
    else
        SYNC_BLOCK_HEIGHT=$FORCE_SNAPSHOT_HEIGHT
    fi
    SYNC_BLOCK_HASH=$(curl -s "$STATE_SYNC_RPC/block?height=$SYNC_BLOCK_HEIGHT" | jq -r .result.block_id.hash)
    if [[ "$SYNC_BLOCK_HASH" == "null" ]]; then
        # Maybe Tendermint 0.35+?
        SYNC_BLOCK_HASH=$(curl -s "$STATE_SYNC_RPC/block?height=$SYNC_BLOCK_HEIGHT" | jq -r .block_id.hash)
    fi
else
    echo "State sync is disabled, doing full sync..."
    sed -i.bak -e "s|^enable *=.*|enable = false|" $CONFIG_DIR/config.toml
fi

if [[ -n "$SYNC_BLOCK_HASH" ]]; then
    if [[ -z "$STATE_SYNC_WITNESSES" ]]; then
        STATE_SYNC_WITNESSES=$STATE_SYNC_RPC
    fi

    echo ""
    echo "Using state sync from with the following settings:"
    sed -i.bak -e "s|^enable *=.*|enable = true|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^rpc_servers *=.*|rpc_servers = \"$STATE_SYNC_RPC,$STATE_SYNC_WITNESSES\"|" $CONFIG_DIR/config.toml

    if [[ "$USE_P2P" == "true" ]]; then
        sed -i.bak -e "s|^rpc-servers *=.*|rpc-servers = \"\"|" $CONFIG_DIR/config.toml
    else
        sed -i.bak -e "s|^rpc-servers *=.*|rpc-servers = \"$STATE_SYNC_RPC,$STATE_SYNC_WITNESSES\"|" $CONFIG_DIR/config.toml
    fi

    sed -i.bak -e "s|^trust_height *=.*|trust_height = $SYNC_BLOCK_HEIGHT|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^trust-height *=.*|trust-height = $SYNC_BLOCK_HEIGHT|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^trust_hash *=.*|trust_hash = \"$SYNC_BLOCK_HASH\"|" $CONFIG_DIR/config.toml
    sed -i.bak -e "s|^trust-hash *=.*|trust-hash = \"$SYNC_BLOCK_HASH\"|" $CONFIG_DIR/config.toml
    # sed -i.bak -e "s/^trust_period *=.*/trust_period = \"168h\"/" $CONFIG_DIR/config.toml

    cat $CONFIG_DIR/config.toml | grep "enable ="
    cat $CONFIG_DIR/config.toml | grep -A 2 -B 2 trust_hash

elif [[ $STATE_SYNC_ENABLED == 'true' ]]; then
    echo "Failed to look up sync snapshot, falling back to full sync..."
fi

if [[ -n "$RESET_ON_START" ]]; then
    cp "${DATA_DIR}/priv_validator_state.json" /root/priv_validator_state.json.backup
    rm -rf "${DATA_DIR}"
    mkdir -p "${DATA_DIR}"
    mv /root/priv_validator_state.json.backup "${DATA_DIR}/priv_validator_state.json"
# elif [[ -n "$PRUNE_ON_START" ]]; then
#     if [[ -n "$COSMPRUND_APP" ]]; then
#         cosmprund-$DB_BACKEND prune $DATA_DIR --app=$COSMPRUND_APP --blocks=$PRUNING_KEEP_RECENT --versions=$PRUNING_KEEP_RECENT
#     else
#         cosmprund-$DB_BACKEND prune $DATA_DIR --blocks=$PRUNING_KEEP_RECENT --versions=$PRUNING_KEEP_RECENT
#     fi
fi

# ------------------------------------------------------------------------------------
# Start additional process
# ------------------------------------------------------------------------------------
if [[ -n "$ADDITIONAL_PROCESS" ]]; then
    $ADDITIONAL_PROCESS &
fi

# ------------------------------------------------------------------------------------
# Start the chain
# ------------------------------------------------------------------------------------

if [[ -n "$HALT_HEIGHT" ]]; then
    exec cosmovisor run start --halt-height $HALT_HEIGHT "$@"
else
    exec cosmovisor run start "$@"
fi
