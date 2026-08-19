#!/usr/bin/env bash
set -euo pipefail
env_file="${1:-.env}"
host="${2:-<VM_IP>}"
set -a
source "$env_file"
set +a

printf '%s\n' \
  "Operator SSH: ssh -p $ARM_OPER_HOST_SSH_PORT $LAB_ADMIN_USER@$host" \
  "Cashier SSH:  ssh -p $ARM_CASH_HOST_SSH_PORT $LAB_ADMIN_USER@$host" \
  "Accountant SSH: ssh -p $ARM_ACC_HOST_SSH_PORT $LAB_ADMIN_USER@$host" \
  "IT SSH:       ssh -p $ARM_IT_HOST_SSH_PORT $LAB_ADMIN_USER@$host" \
  "Operator xRDP: $host:$ARM_OPER_HOST_RDP_PORT" \
  "Cashier xRDP:  $host:$ARM_CASH_HOST_RDP_PORT" \
  "Accountant xRDP: $host:$ARM_ACC_HOST_RDP_PORT" \
  "IT xRDP:       $host:$ARM_IT_HOST_RDP_PORT" \
  "DBO HTTP:      http://$host:$DBO_HOST_HTTP_PORT" \
  "DBO HTTPS:     https://$host:$DBO_HOST_HTTPS_PORT" \
  "OpenVPN UDP:   $host:$VPN_HOST_PORT"
