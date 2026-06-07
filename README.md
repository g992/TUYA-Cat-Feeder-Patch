# Tuya / SmartLife Feeder Ingenic T23: Telnet + Local RTSP


---

# Contents

* [RU](#ru)

  * [Что получилось](#что-получилось)
  * [Как был получен дамп](#как-был-получен-дамп)
  * [RTSP payload](#rtsp-payload)
  * [Структура репозитория](#структура-репозитория)
  * [Быстрый старт](#быстрый-старт)
  * [Проверка после прошивки](#проверка-после-прошивки)
  * [Важные предупреждения](#важные-предупреждения)

* [EN](#en)

  * [Features](#features)
  * [How the Firmware Dump Was Obtained](#how-the-firmware-dump-was-obtained)
  * [RTSP payload](#rtsp-payload-1)
  * [Repository Structure](#repository-structure)
  * [Quick Start](#quick-start)
  * [Verification](#verification)
  * [Warnings](#warnings)

---

# ru

## Что получилось

После патча устройство поднимает:

* Telnet на порту 23
* RTSP на порту 554
* штатный Tuya-сервис на порту 6668

Проверенные RTSP URL:

```text
rtsp://IP_КОРМУШКИ/stream0
rtsp://IP_КОРМУШКИ/stream1
```

Дополнительно в бинарниках были найдены:

```text
rtsp://IP_КОРМУШКИ/av_stream
rtsp://IP_КОРМУШКИ/stream0m
rtsp://IP_КОРМУШКИ/stream1m
```

Пример проверки:

```bash
ffplay -rtsp_transport tcp rtsp://192.168.1.100/stream0
```

---

## Как был получен дамп

Я вскрыл кормушку и добрался до основной платы.

Фото платы:

```text
assets/01-board.jpg
```

На устройстве используется SPI NOR Flash.

Чтобы процессор не мешал чтению флеш-памяти, был временно отключён преобразователь питания 1.8 В обычным куском проволоки.

Фото:

```text
assets/02-disable-1v8.jpg
```

После этого прошивка была считана обычной SOIC-прищепкой.

Полученный дамп имеет размер:

```text
8388608 bytes (8 MiB)
```

---

## RTSP payload

Подробное описание RTSP payload, его логики, исходного C-кода и процесса сборки вынесено в отдельный файл:

```text
docs/PAYLOAD.md
```

Коротко: патч не добавляет сторонний RTSP-сервер, а активирует RTSP-модуль, уже присутствующий в прошивке производителя.

---

## Структура репозитория

```text
.
├── README.md
├── ingenic_t23_fereder.Bin
├── assets/
├── docs/
│   └── PAYLOAD.md
├── payload/
│   ├── rtsp_preload.c
│   └── rtsp_preload.so
├── patches/
│   ├── rcS.telnet
│   └── rcS.telnet_rtsp
├── scripts/
│   ├── extract.sh
│   ├── build_payload.sh
│   ├── build_telnet.sh
│   ├── build_telnet_rtsp.sh
│   └── lib/
├── extracted/
└── dist/
```

---

## Быстрый старт

Распаковать прошивку:

```bash
./scripts/extract.sh
```

Собрать образ только с telnet:

```bash
./scripts/build_telnet.sh
```

Собрать образ с telnet и RTSP:

```bash
./scripts/build_telnet_rtsp.sh
```

---

## Проверка после прошивки

Проверка Telnet:

```bash
telnet IP_УСТРОЙСТВА 23
```

Проверка RTSP:

```bash
ffplay -rtsp_transport tcp rtsp://IP_УСТРОЙСТВА/stream0
```

Проверка открытых портов:

```bash
netstat -lntp
```

Ожидаемый результат:

```text
0.0.0.0:23
0.0.0.0:554
0.0.0.0:6668
```

---

## Важные предупреждения

* Всегда сохраняйте оригинальный дамп.
* Не публикуйте реальные Tuya-ключи и пароли.
* Telnet открыт без пароля.
* Все действия выполняются на ваш риск.

---

# en

## Features

After applying the patch, the device exposes:

* Telnet on port 23
* RTSP on port 554
* Original Tuya service on port 6668

Verified RTSP URLs:

```text
rtsp://DEVICE_IP/stream0
rtsp://DEVICE_IP/stream1
```

---

## How the Firmware Dump Was Obtained

The feeder was opened and the main PCB was inspected.

Board photo:

```text
assets/01-board.jpg
```

The device uses a SPI NOR Flash chip.

To prevent the CPU from interfering with flash access, the 1.8 V CPU power rail was temporarily disabled using a simple wire.

Photo:

```text
assets/02-disable-1v8.jpg
```

The firmware was then read using a standard SOIC clip.

The resulting firmware image size is:

```text
8388608 bytes (8 MiB)
```

---

## RTSP payload

The detailed description of the RTSP payload, its logic, C source code, and build process has been moved to a separate file:

```text
docs/PAYLOAD.md
```

In short: the patch does not add a third-party RTSP server. It activates the RTSP module that already exists in the vendor firmware.

---

## Repository Structure

```text
.
├── README.md
├── docs/
│   └── PAYLOAD.md
├── payload/
│   ├── rtsp_preload.c
│   └── rtsp_preload.so
├── patches/
├── scripts/
│   ├── build_payload.sh
│   ├── extract.sh
│   ├── build_telnet.sh
│   └── build_telnet_rtsp.sh
├── extracted/
└── dist/
```

---

## Quick Start

Extract firmware:

```bash
./scripts/extract.sh
```

Build Telnet-only firmware:

```bash
./scripts/build_telnet.sh
```

Build Telnet + RTSP firmware:

```bash
./scripts/build_telnet_rtsp.sh
```

---

## Verification

Check Telnet:

```bash
telnet DEVICE_IP 23
```

Check RTSP:

```bash
ffplay -rtsp_transport tcp rtsp://DEVICE_IP/stream0
```

---

## Warnings

* Always keep the original dump.
* Do not publish Tuya keys or Wi-Fi credentials.
* Telnet is enabled without authentication.
* Use at your own risk.
