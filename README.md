## In Dockerfile

| Variable        | Example value       |
| --------------- | ------------------- |
| DAEMON_HOME     | /root/.simd         |
| DAEMON_NAME     | simd                |
| DAEMON_GENESIS  | 1.0.0               |
| DAEMON_UPGRADES | "1.1.1 1.1.2 1.2.0" |

## In deployment environment

| Variable | Example value |
| -------- | ------------- |
| MONIKER  | Brochain      |

### Pruning

| Variable            | Default value |
| ------------------- | ------------- |
| DB_BACKEND          | goleveldb     |
| PRUNING_STRATEGY    | custom        |
| PRUNING_KEEP_RECENT | 5             |
| PRUNING_INTERVAL    | 100           |
| PRUNING_KEEP_EVERY  | 0             |
| SNAPSHOT_INTERVAL   | 0             |
| KEEP_SNAPSHOTS      | 2             |

### Chain information

| Variable          | Default value |
| ----------------- | ------------- |
| CHAIN_ID          |               |
| GENESIS_URL       |               |
| ADDR_BOOK_URL     |               |
| MINIMUM_GAS_PRICE |               |

### Node information

| Variable              | Default value |
| --------------------- | ------------- |
| PRIVATE_VALIDATOR_KEY |               |
| NODE_KEY              |               |
| PUBLIC_ADDRESS        |               |

### Peers

| Variable               | Default value |
| ---------------------- | ------------- |
| UNCONDITIONAL_PEER_IDS |               |
| SEEDS                  |               |
| PERSISTENT_PEERS       |               |

### State sync

| Variable              | Default value |
| --------------------- | ------------- |
| STATE_SYNC_ENABLED    |               |
| STATE_SYNC_RPC        |               |
| FORCE_SNAPSHOT_HEIGHT |               |

### Advanced usage

| Variable           | Default value |
| ------------------ | ------------- |
| USE_HORCRUX        |               |
| SENTRIED_VALIDATOR |               |
| IS_SENTRY          |               |
| RESET_ON_START     |               |
| PRUNE_ON_START     |               |
| COSMPRUND_APP      |               |
| MEMPOOL_SIZE       |               |
| HALT_HEIGHT        |               |
| ENABLE_API         | true          |
