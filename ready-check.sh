#!/bin/bash
if [[ -d "$DAEMON_HOME/cosmovisor/current/lib" ]]; then
  export LD_LIBRARY_PATH=$DAEMON_HOME/cosmovisor/current/lib
fi

$DAEMON_NAME status 2>&1 | jq .SyncInfo.catching_up | grep -q false
