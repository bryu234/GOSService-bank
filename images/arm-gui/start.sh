#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require BUSINESS_USER BUSINESS_PASSWORD ARM_ROLE
banklab_init_state "bank_arm_${ARM_ROLE}"
banklab_start_support

business_hash="$BANKLAB_STATE_DIR/business.password-hash"
if [[ ! -s "$business_hash" ]]; then
  openssl passwd -6 "$BUSINESS_PASSWORD" >"$business_hash"
  chmod 0600 "$business_hash"
fi
if ! id "$BUSINESS_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -p "$(cat "$business_hash")" "$BUSINESS_USER"
fi

for user in "$LAB_ADMIN_USER" "$BUSINESS_USER"; do
  install -d -m 0755 -o "$user" -g "$user" "/home/$user/Desktop"
  printf '%s\n' 'xfce4-session' >"/home/$user/.xsession"
  chown "$user:$user" "/home/$user/.xsession"
done

create_shortcut() {
  local user="$1" file="$2" title="$3" url="$4"
  local path="/home/$user/Desktop/$file.desktop"
  if [[ ! -e "$path" ]]; then
    printf '%s\n' \
      '[Desktop Entry]' 'Type=Application' "Name=$title" "Exec=falkon $url" \
      'Terminal=false' 'Icon=web-browser' >"$path"
    chmod 0755 "$path"
    chown "$user:$user" "$path"
  fi
}

case "$ARM_ROLE" in
  operator)
    create_shortcut "$BUSINESS_USER" abs "АБС" "http://abs.bank.lab:${ABS_APP_PORT}"
    create_shortcut "$BUSINESS_USER" dbo "ДБО" "https://dbo.bank.lab"
    ;;
  cashier)
    create_shortcut "$BUSINESS_USER" abs "АБС" "http://abs.bank.lab:${ABS_APP_PORT}"
    create_shortcut "$BUSINESS_USER" accounting "Бухгалтерская система" "http://accounting.bank.lab:${ACC_APP_PORT}"
    ;;
  accountant)
    create_shortcut "$BUSINESS_USER" accounting "Бухгалтерская система" "http://accounting.bank.lab:${ACC_APP_PORT}"
    ;;
  it)
    create_shortcut "$BUSINESS_USER" abs "АБС" "http://abs.bank.lab:${ABS_APP_PORT}"
    create_shortcut "$BUSINESS_USER" dbo "ДБО" "https://dbo.bank.lab"
    ;;
esac

banklab_finish_initialization
mkdir -p /run/dbus /run/xrdp
dbus-daemon --system --fork || true
rm -f /run/xrdp/xrdp.pid /run/xrdp/xrdp-sesman.pid
/usr/sbin/xrdp-sesman
exec /usr/sbin/xrdp --nodaemon
