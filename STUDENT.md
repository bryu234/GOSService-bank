# Практика: защита инфраструктуры «Виртуальный банк»

Вы получаете уже работающий, намеренно небезопасный START. Не меняйте
`compose.yaml`, Dockerfile, Docker networks и количество машин. Работайте по SSH
или xRDP внутри выданных машин; текущее состояние сохраняйте в `/state`.

## Результат

Нужно перевести инфраструктуру в TARGET:

1. На `bank_router` включить default deny и оставить только обоснованные
   межзонные потоки. Изолировать VLAN10/20/30/40, DMZ, Server, Database,
   Management и VPN.
2. На `bank_abs_db` ограничить PostgreSQL одновременно firewall и
   `pg_hba.conf`: подключение только от `bank_abs` к 5432/TCP.
3. На `bank_dbo_web` принимать backend-трафик только от `bank_proxy`; на
   `bank_adm_srv` принимать SSH только от `bank_pam`.
4. Исправить LDAP PoLP: убрать лишний `abs_admin` у операциониста, сократить
   постоянные IT-права, вывести `svc_shared`, назначить отдельные `svc_abs`,
   `svc_dbo`, `svc_backup`, `svc_acc`.
5. Настроить TOTP MFA на `bank_vpn` и `bank_pam`, а для веб-систем использовать
   готовые отдельные шлюзы: `bank_mfa_dbo` перед ДБО и `bank_mfa_abs` перед АБС.
   Включить в каждом шлюзе LDAP, TOTP и nginx `auth_request`. Код ДБО и АБС не
   менять.
6. Сделать `bank_pam` обязательным jump host для privileged SSH, включить LDAP,
   MFA и запись административных сессий. Запретить прямой IT → server/admin SSH.
7. Подтвердить, что обычные бизнес-сценарии сохранились и изменения переживают
   restart/reboot/down-up без удаления volumes.

Финальную бизнес-матрицу сверх явно перечисленных исправлений не придумывайте:
если право не определено заданием, зафиксируйте вопрос преподавателю.

## Рабочий цикл

На каждой машине:

```bash
cat /state/STUDENT_TASK.md
sudo cp /state/nftables.conf /state/nftables.conf.bak
sudo nano /state/nftables.conf
sudo nft -c -f /state/nftables.conf
sudo nft -f /state/nftables.conf
sudo banklab-save-firewall
```

Для SSH/PAM сначала редактируйте persistent-файл в `/state`, затем проверяйте
`sshd -t`/конфигурацию PAM и только потом перезагружайте сервис. OpenVPN
конфигурация — `/state/openvpn/server.conf`; PAM — `/state/pam`.

На каждом веб-MFA-шлюзе начните с задания и готового примера:

```bash
cat /state/STUDENT_TASK.md
sudo cp /state/authelia/configuration.yml.example /state/authelia/configuration.yml
sudo nano /state/authelia/configuration.yml
sudo nano /state/nginx/nginx.conf
sudo banklab-mfa-validate
sudo banklab-mfa-enable
sudo banklab-mfa-status
```

Подробный порядок и контрольные сценарии: [docs/mfa-gateways.md](docs/mfa-gateways.md).

## Что приложить к сдаче

- итоговые persistent-конфиги без приватных ключей и паролей;
- таблицу разрешенных TARGET-потоков source → destination → port → reason;
- вывод синтаксических проверок nftables, sshd, OpenVPN и приложений;
- доказательства MFA для VPN, PAM и обоих веб-шлюзов;
- доказательство, что IT не обходит PAM;
- проверку ролевых бизнес-сценариев;
- проверку persistence после restart и VM reboot.
