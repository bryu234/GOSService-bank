#!/usr/bin/env bash
set -euo pipefail

BANKLAB_STATE_DIR="${BANKLAB_STATE_DIR:-/state}"

banklab_require() {
  local name
  for name in "$@"; do
    [[ -n "${!name:-}" ]] || { echo "$name is required" >&2; return 1; }
  done
}

banklab_init_state() {
  local service="$1"
  install -d -m 0755 "$BANKLAB_STATE_DIR" "$BANKLAB_STATE_DIR/ssh"
  if [[ ! -e "$BANKLAB_STATE_DIR/.initialized" ]]; then
    printf '%s\n' "$service" >"$BANKLAB_STATE_DIR/service"
    cp /usr/share/banklab/STUDENT_TASK.md "$BANKLAB_STATE_DIR/STUDENT_TASK.md"
    touch "$BANKLAB_STATE_DIR/.first-boot"
  fi
}

banklab_route_via_router() {
  [[ -n "${BANK_ROUTER_IP:-}" ]] || return 0
  if [[ ! -s "$BANKLAB_STATE_DIR/routes.conf" ]]; then
    printf 'default via %s\n' "$BANK_ROUTER_IP" >"$BANKLAB_STATE_DIR/routes.conf"
  fi
  while IFS= read -r route; do
    [[ -n "$route" && "${route:0:1}" != "#" ]] || continue
    # routes.conf is intentionally student-editable inside the isolated lab.
    read -r -a route_args <<<"$route"
    ip route replace "${route_args[@]}"
  done <"$BANKLAB_STATE_DIR/routes.conf"
}

banklab_replay_packages() {
  local manifest="$BANKLAB_STATE_DIR/packages.manual"
  [[ -s "$manifest" ]] || return 0
  local missing=() package
  while IFS= read -r package; do
    [[ -n "$package" ]] || continue
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed' || missing+=("$package")
  done <"$manifest"
  if (( ${#missing[@]} )); then
    echo "Restoring student-installed packages: ${missing[*]}"
    BANKLAB_PACKAGE_REPLAY=1 apt-get update
    BANKLAB_PACKAGE_REPLAY=1 apt-get install -y --no-install-recommends "${missing[@]}"
    rm -rf /var/lib/apt/lists/*
  fi
}

banklab_configure_admin() {
  banklab_require LAB_ADMIN_USER LAB_ADMIN_PASSWORD
  local user="$LAB_ADMIN_USER" hash_file="$BANKLAB_STATE_DIR/lab-admin.password-hash"
  if [[ ! -s "$hash_file" ]]; then
    openssl passwd -6 "$LAB_ADMIN_PASSWORD" >"$hash_file"
    chmod 0600 "$hash_file"
  fi
  if ! id "$user" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -p "$(cat "$hash_file")" "$user"
  else
    usermod -p "$(cat "$hash_file")" "$user"
  fi
  usermod -aG sudo "$user"
  printf '%s ALL=(ALL:ALL) ALL\n' "$user" >"/etc/sudoers.d/banklab-$user"
  chmod 0440 "/etc/sudoers.d/banklab-$user"

  local ssh_config="$BANKLAB_STATE_DIR/ssh/sshd_config"
  if [[ ! -s "$ssh_config" ]]; then
    cp /etc/ssh/sshd_config "$ssh_config"
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$ssh_config"
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$ssh_config"
    sed -i '/^AllowUsers /d' "$ssh_config"
    printf '\nAllowUsers %s\n' "$user" >>"$ssh_config"
  fi
  ln -sfn "$ssh_config" /etc/ssh/sshd_config

  install -d -m 0700 -o "$user" -g "$user" "/home/$user/.ssh"
  if [[ -n "${LAB_ADMIN_AUTHORIZED_KEY:-}" ]]; then
    if [[ ! -s "$BANKLAB_STATE_DIR/ssh/authorized_keys" ]]; then
      printf '%s\n' "$LAB_ADMIN_AUTHORIZED_KEY" >"$BANKLAB_STATE_DIR/ssh/authorized_keys"
    fi
    ln -sfn "$BANKLAB_STATE_DIR/ssh/authorized_keys" "/home/$user/.ssh/authorized_keys"
    chown -h "$user:$user" "/home/$user/.ssh/authorized_keys"
    chmod 0600 "$BANKLAB_STATE_DIR/ssh/authorized_keys"
  fi

  mkdir -p /run/sshd
  ssh-keygen -A >/dev/null 2>&1 || true
}

banklab_init_firewall() {
  local supplied="${1:-/usr/share/banklab/default-nftables.conf}"
  local state_file="$BANKLAB_STATE_DIR/nftables.conf"
  if [[ ! -s "$state_file" ]]; then
    cp "$supplied" "$state_file"
  fi
  ln -sfn "$state_file" /etc/nftables.conf
  nft -f /etc/nftables.conf
}

banklab_start_support() {
  banklab_route_via_router
  banklab_replay_packages
  banklab_configure_admin
  banklab_init_firewall "${1:-/usr/share/banklab/default-nftables.conf}"
  /usr/sbin/rsyslogd || true
  /usr/sbin/sshd
  banklab-record-packages || true
  (
    while sleep 5; do
      local current_hash
      current_hash="$(getent shadow "$LAB_ADMIN_USER" | cut -d: -f2 || true)"
      if [[ -n "$current_hash" ]]; then
        printf '%s\n' "$current_hash" >"$BANKLAB_STATE_DIR/lab-admin.password-hash"
        chmod 0600 "$BANKLAB_STATE_DIR/lab-admin.password-hash"
      fi
    done
  ) &
}

banklab_finish_initialization() {
  rm -f "$BANKLAB_STATE_DIR/.first-boot"
  touch "$BANKLAB_STATE_DIR/.initialized"
}
