# MFA-шлюзы ДБО и АБС

`bank_mfa_dbo` и `bank_mfa_abs` уже стоят перед приложениями. В START nginx
пропускает запросы, а Authelia установлена, но остановлена. Задача студента —
включить LDAP-вход и TOTP на обоих шлюзах без изменения Python-кода приложений.

## Разделение шлюзов

| Шлюз | Адрес | Защищает | Группа LDAP | Портал |
|---|---|---|---|---|
| `bank_mfa_dbo` | `172.28.10.30`, DMZ | `dbo.bank.lab` | `dbo_read` | `auth-dbo.bank.lab` |
| `bank_mfa_abs` | `172.28.20.30`, Server | `abs.bank.lab` | `abs_read` | `auth-abs.bank.lab` |

Шлюзы используют разные SQLite-базы, TOTP-регистрации, секреты cookie и сессии.
Регистрация пользователя на одном шлюзе не включает второй. После прохождения
MFA пользователь отдельно входит в само приложение своей LDAP-учётной записью.

## Настройка каждого шлюза

Выполните на `bank_mfa_dbo`, затем отдельно на `bank_mfa_abs`:

```bash
sudo cp /etc/authelia/configuration.yml.example /etc/authelia/configuration.yml
sudo nano /etc/authelia/configuration.yml
```

Проверьте LDAP-адрес, `base_dn`, bind user, фильтры пользователей/групп и
разрешённую группу. Пароль bind user уже хранится отдельно в
`/etc/authelia/secrets/ldap-password`; в YAML его добавлять не нужно. Замените
политику приложения с `one_factor` на `two_factor`.

Затем включите подготовленный `auth_request` в location приложения:

```bash
sudo nano /etc/nginx/nginx.conf
```

Уберите `#` только у строки:

```nginx
include /etc/nginx/snippets/authelia-authrequest.conf;
```

Включение:

```bash
sudo banklab-mfa-enable
```

Команда `banklab-mfa-enable` выполняет четыре действия:

- проверяет конфигурации Authelia и nginx;
- запускает Authelia с подготовленными переменными окружения;
- перезагружает nginx;
- сохраняет включение MFA после restart, recreate и перезагрузки VM.

Команда не создаёт конфигурацию и не выбирает LDAP-группы за студента. Она
только применяет уже подготовленный результат.

Если не использовать `banklab-mfa-enable`, выполните её действия вручную:

1. Проверьте штатными средствами обе конфигурации:

   ```bash
   sudo authelia config validate --config /etc/authelia/configuration.yml
   sudo nginx -t
   ```

2. Запустите Authelia с подготовленными переменными окружения:

   ```bash
   sudo bash -c '
   set -a
   . /etc/authelia/runtime.env
   set +a
   nohup authelia --config /etc/authelia/configuration.yml \
     >>/var/log/authelia/authelia.log 2>&1 &
   '
   ```

3. Настройте автоматический запуск Authelia после перезапуска машины. Без этого
   MFA будет работать только до следующего restart или recreate.

4. Примените конфигурацию nginx:

   ```bash
   sudo nginx -s reload
   ```

5. Убедитесь, что процесс запущен и защищённый адрес открывает страницу MFA:

   ```bash
   pgrep -af authelia
   ```

Конфигурация и включённое состояние сохраняются после restart, recreate и
перезагрузки VM.

## Сетевые правила TARGET

Оставьте только необходимые направления:

- внешний клиент → `bank_proxy`: HTTPS ДБО;
- `bank_proxy` → `bank_mfa_dbo`: HTTP;
- `bank_mfa_dbo` → `bank_dbo_web`: порт приложения ДБО;
- `bank_mfa_dbo` → `bank_ldap`: LDAP 389/TCP;
- разрешённые АРМ → `bank_mfa_abs`: HTTPS;
- `bank_mfa_abs` → `bank_abs`: порт приложения АБС;
- `bank_mfa_abs` → `bank_ldap`: LDAP 389/TCP.

Прямой клиентский доступ к `bank_dbo_web` и `bank_abs` должен быть закрыт.
`bank_proxy` не должен получать маршрут к АБС.

## Проверка результата

Для каждого шлюза отдельно:

1. Откройте защищённый адрес в новом приватном окне браузера.
2. Войдите LDAP-пользователем из разрешённой группы.
3. Зарегистрируйте TOTP в приложении-аутентификаторе. Ссылка регистрации при
   необходимости появляется в `/var/lib/authelia/notification.txt`.
4. Убедитесь, что неверный одноразовый код отклоняется.
5. Убедитесь, что актуальный код принимается и открывается обычная форма входа
   самого ДБО или АБС.
6. Закройте приватное окно и повторите проверку второго шлюза: он должен
   запросить свою отдельную регистрацию и отдельный код.
7. Выполните `make verify-target`, затем `make verify-persistence` и повторите
   вход после restart.
