# Памятка внутри машины Bank Lab

Эта машина — часть намеренно небезопасного START-стенда. Docker Compose, Docker
networks и Docker CLI менять не нужно. Текущее состояние хранится в `/state`.

Основные команды:

```bash
sudo nano /state/nftables.conf
sudo nft -f /state/nftables.conf
sudo banklab-save-firewall

sudo nano /state/routes.conf
sudo banklab-save-routes

sudo apt update
sudo apt install <package>
cat /state/packages.manual
```

APT-пакеты, установленные после первого запуска, записываются в
`/state/packages.manual` и восстанавливаются при пересоздании контейнера.
Python-зависимости прикладных машин устанавливайте в уже существующий persistent
venv (`/state/venv/bin/pip`) либо создайте свой venv внутри `/state`.

Перед правкой делайте копию файла в `/state`, после правки проверяйте синтаксис.
Примеры:

```bash
sudo nft -c -f /state/nftables.conf
sudo sshd -t
sudo nginx -t                  # proxy
sudo slaptest -u               # ldap
sudo -u postgres pg_isready    # PostgreSQL machines
```

Полное задание и TARGET-потоки находятся на хосте стенда в `STUDENT.md`.
