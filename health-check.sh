#!/bin/bash

# Neede ENV:
# DAEMON_NAME: The name of the chain binary
# DAEMON_HOME: The home directory of the node

: ${LATE_LIMIT:=60}
CODE_OK=0
CODE_LATE=21
CODE_DOWN=22

if [[ -d "$DAEMON_HOME/cosmovisor/current/lib" ]]; then
  export LD_LIBRARY_PATH=$DAEMON_HOME/cosmovisor/current/lib
fi

# Get latest block time for node
LATEST_BLOCK=$($DAEMON_NAME q block 2>&1 | jq .block.header.time -r | date +%s -f -)
NOW=$(date +%s)
DIFF=$(( $NOW - $LATEST_BLOCK ))
if (( $DIFF > $LATE_LIMIT )); then
  # Check if the node is still catching up. If so, leave it be
  # if [[ $($DAEMON_NAME status 2>&1 | jq .SyncInfo.catching_up) == "false" ]]; then
    echo "FAIL: Node is lagging more than 60 seconds"
    exit $CODE_LATE
  # fi
fi

$DAEMON_NAME status 2>&1 > /dev/null
IS_DOWN=$?
if (( $IS_DOWN > 0 ));then
  echo "FAIL: Node is not responding"
  exit $CODE_DOWN
fi

echo "SUCCESS: Node seems healthy"
exit $CODE_OK
