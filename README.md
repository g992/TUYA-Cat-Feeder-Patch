# Tuya / SmartLife feeder Ingenic T23: telnet + локальный RTSP

Небольшой набор скриптов для патча прошивки кормушки на Ingenic T23.  
Цель: получить telnet-доступ и поднять локальный RTSP-поток без облака Tuya.

Проверялось на дампе 8 MiB с разметкой:

- `boot`: `0x000000..0x040000`
- `kernel`: `0x040000..0x1c0000`
- `root`: `0x1c0000..0x2c0000`, SquashFS
- `ro`: `0x2c0000..0x300000`, JFFS2
- `config`: `0x300000..0x340000`, JFFS2
- `appfs/system`: `0x340000..0x800000`, SquashFS

> Важно: это не универсальный патч для всех кормушек. Перед прошивкой сверяйте размер дампа и layout.

## Что получилось

После патча устройство поднимает:

- telnet на `23`;
- стандартный Tuya-сервис на `6668`;
- RTSP на `554`.

Рабочие RTSP URL, которые стоит проверить:

```text
rtsp://IP_КОРМУШКИ/stream0
rtsp://IP_КОРМУШКИ/stream1
rtsp://IP_КОРМУШКИ/av_stream
rtsp://IP_КОРМУШКИ/stream0m
rtsp://IP_КОРМУШКИ/stream1m
```

Например:

```sh
ffplay -rtsp_transport tcp rtsp://192.168.3.136/stream0
```

## Как был получен дамп

После вскрытия кормушки, обнаружил плату, на ней сразу видна флеш память и дебаг юарт пины
<img width="960" height="1280" alt="image" src="https://github.com/user-attachments/assets/8b4eeed7-ab90-437e-aedb-2d6172e6fa7f" />
<img width="960" height="1280" alt="image" src="https://github.com/user-attachments/assets/1daddda9-ed02-4dfa-aa76-e38c1d5df57f" />

Чтобы процессор не мешал чтению флеша, я временно отключил его питание 1.8 В: обычным куском проволоки выключил преобразователь 1.8 В для процессора.

<img width="778" height="692" alt="image" src="https://github.com/user-attachments/assets/800c32ed-1df2-40e9-9819-6dd815f53c0d" />


После этого обычной SOIC-прищепкой считал полный бинарник прошивки.

Дальше прошивка была разобрана на разделы, в `rootfs` был изменён `/etc/init.d/rcS`, а в `system/appfs` добавлен `rtsp_preload.so`.

В прошивке уже есть RTSP-библиотеки:

```text
/system/lib/libmedia.so
/system/lib/librtspserver_v2.so
```

Но штатный процесс `tuya_test` не вызывает инициализацию RTSP-сервера.  
Патч делает это через `LD_PRELOAD`: после старта системы `tuya_test` перезапускается с библиотекой `rtsp_preload.so`, которая вызывает RTSP init внутри процесса `tuya_test`.

Важный момент: нельзя экспортировать `LD_PRELOAD` перед запуском `/system/app.sh`, потому что `app.sh` — shell-скрипт. В этом случае preload попадает в `busybox/sh`, и система падает. Поэтому в `rcS` используется отложенный перезапуск только ELF-бинарника `/system/bin/tuya_test`.

## Структура репозитория

```text
.
├── README.md
├── firmware.bin / ingenic_t23_fereder.Bin   # сюда кладётся исходный дамп, не коммитить
├── payload/
│   └── rtsp_preload.so                      # preload-библиотека для RTSP
├── patches/
│   ├── rcS.telnet                           # только telnet
│   └── rcS.telnet_rtsp                      # telnet + RTSP
├── scripts/
│   ├── extract.sh                           # распаковка прошивки
│   ├── build_telnet.sh                      # сборка образа только с telnet
│   ├── build_telnet_rtsp.sh                 # сборка образа с telnet + RTSP
│   └── lib/
│       ├── common.sh
│       ├── layout.sh
│       └── rebuild_image.sh
├── extracted/                               # результат распаковки, не коммитить
└── dist/                                    # готовые образы, не коммитить
```

## Зависимости

Нужны:

- `binwalk`
- `unsquashfs`
- `mksquashfs`

macOS:

```sh
brew install binwalk squashfs
```

Ubuntu/Debian:

```sh
sudo apt update
sudo apt install binwalk squashfs-tools
```

## Быстрый старт

Склонировать репозиторий:

```sh
git clone https://github.com/YOUR_NAME/YOUR_REPO.git
cd YOUR_REPO
```

Положить полный дамп флеша в корень репозитория. По умолчанию скрипты ждут имя:

```text
ingenic_t23_fereder.Bin
```

Распаковать:

```sh
./scripts/extract.sh
```

Собрать образ только с telnet:

```sh
./scripts/build_telnet.sh
```

Результат будет здесь:

```text
dist/ingenic_t23_fereder.telnet.Bin
```

Собрать образ с telnet + RTSP:

```sh
./scripts/build_telnet_rtsp.sh
```

Результат будет здесь:

```text
dist/ingenic_t23_fereder.telnet_rtsp.Bin
```

Можно явно указать входной и выходной файл:

```sh
./scripts/extract.sh ./my_dump.Bin ./extracted

./scripts/build_telnet_rtsp.sh \
  ./my_dump.Bin \
  ./dist/my_dump.telnet_rtsp.Bin
```

## Проверка после прошивки

Найти IP устройства, затем:

```sh
telnet IP_КОРМУШКИ 23
```

На устройстве:

```sh
netstat -lntp
```

Ожидаемо:

```text
0.0.0.0:23     LISTEN  telnetd
0.0.0.0:554    LISTEN  tuya_test
0.0.0.0:6668   LISTEN  tuya_test
```

Проверить RTSP:

```sh
ffplay -rtsp_transport tcp rtsp://IP_КОРМУШКИ/stream0
```

## Важные предупреждения

- Перед экспериментами обязательно сохраните оригинальный полный дамп флеша.
- Не прошивайте образ, если размер исходного дампа не `8388608` байт.
- Не публикуйте свои реальные ключи Tuya, Wi-Fi пароли и серийники из логов.
- Telnet без пароля небезопасен. Используйте только в своей локальной сети или для исследования.
- Всё делаете на свой риск: можно получить кирпич, если ошибиться с образом или флешером.

## Что делают скрипты

`extract.sh`:

1. проверяет размер дампа;
2. запускает `binwalk`;
3. извлекает `rootfs` с offset `0x1c0000`;
4. извлекает `system/appfs` с offset `0x340000`.

`build_telnet.sh`:

1. кладёт `patches/rcS.telnet` в `extracted/rootfs/etc/init.d/rcS`;
2. пересобирает SquashFS-разделы;
3. вставляет их обратно в копию исходного дампа;
4. сохраняет результат в `dist/`.

`build_telnet_rtsp.sh`:

1. кладёт `patches/rcS.telnet_rtsp` в `extracted/rootfs/etc/init.d/rcS`;
2. кладёт `payload/rtsp_preload.so` в `extracted/system/lib/rtsp_preload.so`;
3. пересобирает SquashFS-разделы;
4. вставляет их обратно в копию исходного дампа;
5. сохраняет результат в `dist/`.
