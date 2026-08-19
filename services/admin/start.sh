#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh
banklab_init_state bank_adm_srv
banklab_start_support
banklab_finish_initialization
exec sleep infinity
