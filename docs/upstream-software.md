# Зафиксированное upstream ПО

| Компонент | Версия/ref | Commit |
|---|---|---|
| Ubuntu | `24.04` | image tag из `.env` |
| OWASP-101 Python | branch `A01` | `efc557da400b3ca92f116b77ac44fac336a6ab26` |
| Dolibarr | `23.0.3` | `57d0be7dc97140d7d47e826875ba9256ec3b6357` |
| Django | `5.2.17` | lock file |
| django-auth-ldap | `5.3.0` | lock file |
| Psycopg | `3.3.4` | lock file |

`make vendor` получает только указанные commits и проверяет их хеши. Сборка не
делает clone latest. Каталоги `vendor/` не коммитятся; для офлайн-выдачи курса
их нужно заранее включить в артефакт VM/дистрибутива.
