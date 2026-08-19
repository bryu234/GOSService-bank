# Топология

`bank_router` подключён ко всем девяти bridge networks и является единственным
межзонным L3 gateway. Все остальные машины подключены ровно к одной зоне.

| Зона | Машины |
|---|---|
| Untrusted | `bank_vpn` |
| DMZ | `bank_proxy`, `bank_dbo_web` |
| Server | `bank_abs`, `bank_acc_sys` |
| Database | `bank_abs_db` |
| Management | `bank_pam`, `bank_adm_srv`, `bank_backup`, `bank_ldap` |
| VLAN10 | `bank_arm_oper` |
| VLAN20 | `bank_arm_cash` |
| VLAN30 | `bank_arm_acc` |
| VLAN40 | `bank_arm_it` |

В START chain `forward` на router имеет `policy accept`. В TARGET все переходы
между зонами оформляются explicit allow; одно-зонные ограничения (proxy → DBO,
PAM → admin) дополнительно задаются host firewall целевой машины.

OpenVPN pool не является Docker network. Router хранит маршрут к pool через
`bank_vpn`; VPN направляет банковские сети через router.
