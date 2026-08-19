# Учетные записи и START-роли

Значения логинов и стартовых паролей берутся только из `.env`. Здесь указаны
имена переменных, чтобы документация не дублировала секреты.

| Тип | ENV | START-права |
|---|---|---|
| Операционист | `OPER_USER` | ABS read/write/admin, DBO read |
| Кассир | `CASH_USER` | ABS read/write, Accounting read |
| Бухгалтер | `ACC_USER` | Accounting read/write |
| IT | `IT_USER` | ABS/DBO/Management admin, VPN, PAM |
| Общая service identity | `SVC_SHARED_USER` | ABS/DBO/Management/Accounting read/write |

Отдельные `SVC_ABS_USER`, `SVC_DBO_USER`, `SVC_BACKUP_USER`, `SVC_ACC_USER`
созданы заранее, но в START не назначены вместо общей identity. Это часть
задания PoLP.

`LAB_ADMIN_USER` — техническая локальная УЗ для входа на машины. Root SSH
запрещён. LDAP admin и локальный Dolibarr admin используются для обслуживания,
не как бизнес-пользователи.
