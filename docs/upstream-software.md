# Зафиксированное upstream ПО

| Компонент | Версия/ref | Commit |
|---|---|---|
| Ubuntu | `24.04` | image tag из `.env` |
| OWASP-101 Python | branch `A01` | `efc557da400b3ca92f116b77ac44fac336a6ab26` |
| Dolibarr | `23.0.3` | `57d0be7dc97140d7d47e826875ba9256ec3b6357` |
| Authelia | `4.39.20` | официальный release archive с SHA-256 для amd64/arm64 |
| Django | `5.2.17` | lock file |
| django-auth-ldap | `5.3.0` | lock file |
| Psycopg | `3.3.4` | lock file |

`make vendor` получает только указанные commits и проверяет их хеши. Сборка не
делает clone latest. Каталоги `vendor/` не коммитятся; для офлайн-выдачи курса
их нужно заранее включить в артефакт VM/дистрибутива.

## Машины, образы и основное ПО

| Машины | Image | Основное ПО |
|---|---|---|
| `bank_router` | `banklab/router:1.0` | nftables, conntrack, маршрутизация/NAT, OpenSSH |
| `bank_vpn` | `banklab/vpn:1.0` | OpenVPN, PAM/LDAP-инструменты, nftables, OpenSSH |
| `bank_proxy` | `banklab/proxy:1.0` | nginx TLS reverse proxy, OpenSSH |
| `bank_mfa_dbo`, `bank_mfa_abs` | `banklab/mfa-gateway:1.0` | Authelia 4.39.20, nginx auth_request, OpenSSH |
| `bank_dbo_web` | `banklab/dbo:1.0` | Flask, Gunicorn, python-ldap, OpenSSH |
| `bank_abs` | `banklab/abs:1.0` | Django, django-auth-ldap, Gunicorn, Psycopg, OpenSSH |
| `bank_abs_db` | `banklab/abs-db:1.0` | PostgreSQL 16 server/client, OpenSSH |
| `bank_acc_sys` | `banklab/accounting:1.0` | Dolibarr 23.0.3, Apache, PHP, PostgreSQL 16, LDAP-модули |
| `bank_ldap` | `banklab/ldap:1.0` | OpenLDAP `slapd`, ldap-utils, OpenSSH |
| `bank_pam` | `banklab/pam:1.0` | PAM/NSS LDAP, nslcd, tlog, OpenSSH |
| `bank_adm_srv` | `banklab/admin:1.0` | PostgreSQL client, rsync, OpenSSH |
| `bank_backup` | `banklab/backup:1.0` | PostgreSQL client, rsync, OpenSSH |
| четыре `bank_arm_*` | `banklab/arm-gui:1.0` | XFCE, xRDP, Firefox, OpenSSH |

Все специализированные образы наследуют `banklab/ubuntu-base:1.0` на Ubuntu
24.04. В базовом образе есть nftables, SSH, rsyslog, сетевые и диагностические
утилиты. Установленные студентами APT-пакеты сохраняются после пересоздания
машин.
