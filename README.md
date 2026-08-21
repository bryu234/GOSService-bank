# Virtual Bank student lab

Рабочая реализация небезопасного START-стенда по ТЗ: 17 Ubuntu-машин в
контейнерах, 9 изолированных зон, единый router/firewall, OpenVPN, nginx/ДБО,
адаптированный OWASP-101, PostgreSQL, Dolibarr, OpenLDAP, PAM jump host, два
независимых MFA-шлюза и четыре XFCE/xRDP АРМ.

## Требования к хосту

- целевая Ubuntu VM: 8 vCPU, 16 GB RAM (32 GB предпочтительно), 80+ GB disk;
- Docker Engine с Compose v2;
- `/dev/net/tun` для OpenVPN;
- выбранные CIDR не пересекаются с сетью VM, платформой или Docker pools.

macOS-профиль предназначен для сборки и ограниченного smoke-теста. Полную
интеграционную проверку выполняйте на Ubuntu VM.

## Быстрый запуск

```bash
git clone https://github.com/bryu234/GOSService-bank.git
cd GOSService-bank
make env
nano .env
make preflight
make up                 # Ubuntu VM, bind 0.0.0.0
```

Локально на Mac публиковать порты только на loopback:

```bash
make up-local           # bind 127.0.0.1
```

`make preflight` всегда проверяет схему `.env`, занятость host-портов и
пересечения сетей до запуска. Все базовые команды и предупреждения доступны в
`make help`.

## Проверка и остановка

```bash
make ps
make access-info
make verify-start
make verify-persistence
make down               # volumes сохраняются
```

Сброс является отдельной разрушительной операцией:

```bash
CONFIRM=RESET make reset        # Ubuntu VM: удалить volumes и сразу восстановить START
CONFIRM=RESET make reset-local  # локальный профиль
```

## Где студент меняет состояние

Каждая машина содержит `/state/STUDENT_TASK.md`. Изменяемые firewall, routes,
SSH/PAM/MFA-конфиги и журналы находятся в `/state` и named volumes. После
изменения runtime firewall выполните `sudo banklab-save-firewall`; после
изменения маршрутов — `sudo banklab-save-routes`. APT-пакеты автоматически
фиксируются в `/state/packages.manual` и переустанавливаются при recreate.

Полное практическое задание: [STUDENT.md](STUDENT.md). Топология и справочники:
[docs/topology.md](docs/topology.md), [docs/accounts.md](docs/accounts.md),
[docs/ports.md](docs/ports.md), [docs/mfa-gateways.md](docs/mfa-gateways.md),
[docs/upstream-software.md](docs/upstream-software.md).

Фактический `.env` содержит учебные пароли и не коммитится. Defaults из
`.env.example` не являются production-практикой и должны быть заменены до
публикации VM.
