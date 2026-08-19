# Публикуемые порты

Наружу публикуются только вход в ДБО, OpenVPN и SSH/xRDP четырёх АРМ. Серверный
SSH и внутренние application/database/LDAP ports на host не публикуются.

| Назначение | ENV |
|---|---|
| ДБО HTTP/HTTPS | `DBO_HOST_HTTP_PORT`, `DBO_HOST_HTTPS_PORT` |
| OpenVPN UDP | `VPN_HOST_PORT` |
| SSH четырёх АРМ | `ARM_*_HOST_SSH_PORT` |
| xRDP четырёх АРМ | `ARM_*_HOST_RDP_PORT` |

`compose.local.yaml` привязывает их к `127.0.0.1`; `compose.vm.yaml` — к
`0.0.0.0`. Перед каждым `make up`/`make up-local` Makefile пытается bind-ить все
TCP/UDP ports и останавливает запуск при конфликте.
