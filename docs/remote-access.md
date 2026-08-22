# Удалённое подключение: NetBird и OpenVPN

NetBird даёт компьютеру доступ к серверу стенда `10.128.0.9`. Учебный OpenVPN
запускается поверх этого доступа и выдаёт адрес из пула `172.28.60.0/24` для
проверки входа во внутренние банковские сети.

Порядок подключения всегда такой:

1. установить и подключить NetBird;
2. проверить, что сервер `10.128.0.9` доступен;
3. запустить OpenVPN с учебным профилем.

## Установка NetBird

Официальные страницы:

- [установка NetBird для всех систем](https://docs.netbird.io/get-started/install);
- [Windows EXE](https://pkgs.netbird.io/windows/x64);
- [macOS Intel](https://pkgs.netbird.io/macos/amd64);
- [macOS Apple Silicon](https://pkgs.netbird.io/macos/arm64).

Linux:

```bash
curl -fsSL https://pkgs.netbird.io/install.sh | sh
```

macOS:

```bash
curl -fsSL https://pkgs.netbird.io/install.sh | sh
```

Либо через Homebrew:

```bash
brew install --cask netbirdio/tap/netbird-ui
```

Windows PowerShell от имени администратора:

```powershell
$installer = "$env:TEMP\netbird-installer.exe"
Invoke-WebRequest https://pkgs.netbird.io/windows/x64 -OutFile $installer
Start-Process $installer -ArgumentList "/S" -Verb RunAs -Wait
```

После установки Windows откройте новую консоль PowerShell.

## Подключение к NetBird

Менеджер выдаёт `SETUP KEY`. Вместо `<SETUP_KEY>` подставьте полученный ключ.

Linux и macOS:

```bash
sudo netbird up --setup-key "<SETUP_KEY>" \
  --management-url "https://gosservice-gateway.education-services.ru"
netbird status
```

Windows PowerShell от имени администратора:

```powershell
& "C:\Program Files\NetBird\netbird.exe" up `
  --setup-key "<SETUP_KEY>" `
  --management-url "https://gosservice-gateway.education-services.ru"
& "C:\Program Files\NetBird\netbird.exe" status
```

В статусе NetBird должно быть активное подключение. После этого проверьте
доступность SSH на сервере стенда.

Linux и macOS:

```bash
nc -vz 10.128.0.9 22
```

Windows PowerShell:

```powershell
Test-NetConnection 10.128.0.9 -Port 22
```

## Проверка учебного OpenVPN

OpenVPN запускайте только после подключения NetBird: клиент OpenVPN должен
сначала достучаться до сервера `10.128.0.9:1194/UDP` через NetBird.

1. Получите файл `banklab-client.ovpn` по инструкции менеджера или
   преподавателя.
2. Проверьте, что в профиле указана строка:

   ```text
   remote 10.128.0.9 1194
   ```

3. Запустите OpenVPN.

Linux и macOS:

```bash
sudo openvpn --config ./banklab-client.ovpn
```

Windows PowerShell от имени администратора:

```powershell
openvpn --config .\banklab-client.ovpn
```

Также профиль можно импортировать в OpenVPN Connect и нажать **Connect** после
того, как NetBird уже подключён. Для входа в учебный OpenVPN используются
выданные преподавателем LDAP-данные пользователя IT.

При завершении работы сначала отключите OpenVPN, затем NetBird.
