# RTSP payload / RTSP payload

- [Русская версия](#русская-версия)
  - [Что делает payload](#что-делает-payload)
  - [Почему нужен LD_PRELOAD](#почему-нужен-ld_preload)
  - [Исходный код](#исходный-код)
  - [Сборка](#сборка)
  - [Установка в образ](#установка-в-образ)
  - [Проверка](#проверка)
  - [Замечания](#замечания)
- [English version](#english-version)
  - [What the payload does](#what-the-payload-does)
  - [Why LD_PRELOAD is used](#why-ld_preload-is-used)
  - [Source code](#source-code)
  - [Build](#build)
  - [Install into the firmware image](#install-into-the-firmware-image)
  - [Verification](#verification)
  - [Notes](#notes)

---

# Русская версия

## Что делает payload

`rtsp_preload.so` не добавляет в прошивку новый RTSP-сервер.

В прошивке производителя уже есть нужные библиотеки:

```text
/system/lib/libmedia.so
/system/lib/librtspserver_v2.so
/system/lib/libframework.so
```

Также в бинарниках были найдены строки и символы:

```text
FRAMEWORK_MEDIA_RtspInit
RtspServerThread
MEDIA_MSG_RTSP_SERVER_INIT_DONE
MEDIA_MSG_RTSP_SERVER_START_DONE
```

Payload только вызывает встроенную функцию:

```c
FRAMEWORK_MEDIA_RtspInit();
```

изнутри процесса `tuya_test`.

После успешного вызова штатный RTSP-модуль производителя поднимает порт `554`.

## Почему нужен LD_PRELOAD

Сначала была попытка вызвать `FRAMEWORK_MEDIA_RtspInit()` из отдельного helper-процесса, но такой вариант падал с `Segmentation fault`.

Причина: функция ожидает уже инициализированный framework-контекст камеры. Этот контекст есть внутри процесса `tuya_test`, но его нет в отдельном процессе.

Поэтому используется `LD_PRELOAD`: небольшая `.so` загружается внутрь `tuya_test`, ждёт инициализации видеопайплайна и затем вызывает RTSP init.

Важно: нельзя глобально экспортировать `LD_PRELOAD` перед запуском `/system/app.sh`, потому что `app.sh` — shell-скрипт. В этом случае payload может попасть в `busybox/sh`. Без защит это приводит к падению shell.

В текущем исходнике есть дополнительная защита: payload проверяет `/proc/self/exe` и работает только если он загружен в процесс `tuya_test`.

## Исходный код

Исходник лежит здесь:

[rtsp_preload.c](payload/rtsp_preload.c)

Ключевая идея:

```c
__attribute__((constructor))
static void rtsp_preload_init(void)
{
    if (!is_tuya_test_process()) {
        return;
    }

    pthread_create(&tid, NULL, rtsp_init_thread, NULL);
}
```

В отдельном потоке выполняется задержка, затем поиск функции через `dlsym()`:

```c
sleep(RTSP_INIT_DELAY_SECONDS);

rtsp_init = dlsym(RTLD_DEFAULT, "FRAMEWORK_MEDIA_RtspInit");
rtsp_init();
```

Задержка нужна потому, что при слишком раннем вызове RTSP может стартовать до готовности видеопотока и получить нулевые параметры:

```text
height 0 width 0 videoType=0
```

По умолчанию используется:

```c
#define RTSP_INIT_DELAY_SECONDS 15
```

Если на другой прошивке RTSP стартует слишком рано, можно собрать payload с большей задержкой.

## Сборка

Нужен MIPS little-endian Linux toolchain, совместимый с прошивкой устройства. В идеале — `mipsel-linux-uclibc-gcc`, потому что прошивка собрана под uClibc.

Собрать можно готовым скриптом:

```bash
./scripts/build_payload.sh
```

Можно указать компилятор и задержку:

```bash
CC=/path/to/mipsel-linux-uclibc-gcc DELAY=60 ./scripts/build_payload.sh
```

Или вручную:

```bash
mipsel-linux-uclibc-gcc \
  -Os \
  -fPIC \
  -shared \
  -o payload/rtsp_preload.so \
  payload/rtsp_preload.c \
  -ldl \
  -lpthread
```

Если нужно увеличить задержку до 60 секунд:

```bash
mipsel-linux-uclibc-gcc \
  -Os \
  -fPIC \
  -shared \
  -DRTSP_INIT_DELAY_SECONDS=60 \
  -o payload/rtsp_preload.so \
  payload/rtsp_preload.c \
  -ldl \
  -lpthread
```

Проверить тип файла на компьютере:

```bash
file payload/rtsp_preload.so
```

Ожидается примерно такой результат:

```text
ELF 32-bit LSB shared object, MIPS, MIPS32
```

Размер payload обычно получается всего несколько килобайт.

## Установка в образ

После распаковки прошивки:

```bash
./scripts/extract.sh
```

payload кладётся в `system`-раздел:

```bash
cp payload/rtsp_preload.so extracted/system/lib/rtsp_preload.so
chmod 644 extracted/system/lib/rtsp_preload.so
```

Далее `build_telnet_rtsp.sh` сам добавляет нужный `rcS` и пересобирает образ:

```bash
./scripts/build_telnet_rtsp.sh
```

Готовый образ будет в:

```text
dist/
```

## Проверка

После прошивки устройство должно открыть RTSP-порт:

```bash
netstat -lntp
```

Ожидаемо:

```text
0.0.0.0:554
```

В логах должны появиться строки:

```text
rtsp_preload: waiting before RTSP init...
rtsp_preload: calling FRAMEWORK_MEDIA_RtspInit...
rtsp_preload: RTSP init call done
MEDIA_MSG_RTSP_SERVER_INIT_DONE
MEDIA_MSG_RTSP_SERVER_START_DONE
```

Проверка видео:

```bash
ffplay -rtsp_transport tcp rtsp://DEVICE_IP/stream0
```

## Замечания

- Payload не содержит стороннего RTSP-сервера.
- Payload использует RTSP-код, уже присутствующий в прошивке производителя.
- Если `LD_PRELOAD` применить к shell-скрипту, можно получить падение `sh`.
- Поэтому безопаснее запускать payload только вместе с ELF-бинарником `tuya_test`.
- Текущий исходник дополнительно проверяет имя процесса перед выполнением.

---

# English version

## What the payload does

`rtsp_preload.so` does not add a new RTSP server to the firmware.

The vendor firmware already contains the required libraries:

```text
/system/lib/libmedia.so
/system/lib/librtspserver_v2.so
/system/lib/libframework.so
```

The firmware also contains the following symbols and log strings:

```text
FRAMEWORK_MEDIA_RtspInit
RtspServerThread
MEDIA_MSG_RTSP_SERVER_INIT_DONE
MEDIA_MSG_RTSP_SERVER_START_DONE
```

The payload only calls the built-in function:

```c
FRAMEWORK_MEDIA_RtspInit();
```

from inside the `tuya_test` process.

After a successful call, the vendor RTSP module opens port `554`.

## Why LD_PRELOAD is used

The first attempt was to call `FRAMEWORK_MEDIA_RtspInit()` from a standalone helper process, but it immediately crashed with `Segmentation fault`.

The reason is that the function expects an already initialized camera framework context. That context exists inside `tuya_test`, but not inside an external helper process.

That is why `LD_PRELOAD` is used: a small shared library is loaded into `tuya_test`, waits for the video pipeline to initialize, and then calls the RTSP init function.

Important: do not export `LD_PRELOAD` globally before running `/system/app.sh`, because `app.sh` is a shell script. In that case the payload may be loaded into `busybox/sh`. Without guards this can crash the shell.

The current source code includes an additional safety guard: it checks `/proc/self/exe` and only runs inside the `tuya_test` process.

## Source code

The source file is located here:

[rtsp_preload.c](payload/rtsp_preload.c)


The core idea:

```c
__attribute__((constructor))
static void rtsp_preload_init(void)
{
    if (!is_tuya_test_process()) {
        return;
    }

    pthread_create(&tid, NULL, rtsp_init_thread, NULL);
}
```

A detached thread waits for a short delay, then resolves the RTSP init function with `dlsym()`:

```c
sleep(RTSP_INIT_DELAY_SECONDS);

rtsp_init = dlsym(RTLD_DEFAULT, "FRAMEWORK_MEDIA_RtspInit");
rtsp_init();
```

The delay is required because calling RTSP init too early can start the RTSP server before the video stream is ready, resulting in zero stream parameters:

```text
height 0 width 0 videoType=0
```

By default, the payload uses:

```c
#define RTSP_INIT_DELAY_SECONDS 15
```

If RTSP starts too early on another firmware version, rebuild the payload with a longer delay.

## Build

You need a MIPS little-endian Linux toolchain compatible with the device firmware. Ideally, use `mipsel-linux-uclibc-gcc`, because the firmware is based on uClibc.

You can build it using the helper script:

```bash
./scripts/build_payload.sh
```

You can also override the compiler and delay:

```bash
CC=/path/to/mipsel-linux-uclibc-gcc DELAY=60 ./scripts/build_payload.sh
```

Or build it manually:

```bash
mipsel-linux-uclibc-gcc \
  -Os \
  -fPIC \
  -shared \
  -o payload/rtsp_preload.so \
  payload/rtsp_preload.c \
  -ldl \
  -lpthread
```

To build with a 60-second delay:

```bash
mipsel-linux-uclibc-gcc \
  -Os \
  -fPIC \
  -shared \
  -DRTSP_INIT_DELAY_SECONDS=60 \
  -o payload/rtsp_preload.so \
  payload/rtsp_preload.c \
  -ldl \
  -lpthread
```

Check the resulting file on your computer:

```bash
file payload/rtsp_preload.so
```

Expected output should look similar to:

```text
ELF 32-bit LSB shared object, MIPS, MIPS32
```

The resulting payload is usually only a few kilobytes.

## Install into the firmware image

After extracting the firmware:

```bash
./scripts/extract.sh
```

copy the payload into the `system` partition:

```bash
cp payload/rtsp_preload.so extracted/system/lib/rtsp_preload.so
chmod 644 extracted/system/lib/rtsp_preload.so
```

Then `build_telnet_rtsp.sh` applies the required `rcS` patch and rebuilds the firmware image:

```bash
./scripts/build_telnet_rtsp.sh
```

The final image will be placed in:

```text
dist/
```

## Verification

After flashing, the device should open the RTSP port:

```bash
netstat -lntp
```

Expected:

```text
0.0.0.0:554
```

The logs should contain:

```text
rtsp_preload: waiting before RTSP init...
rtsp_preload: calling FRAMEWORK_MEDIA_RtspInit...
rtsp_preload: RTSP init call done
MEDIA_MSG_RTSP_SERVER_INIT_DONE
MEDIA_MSG_RTSP_SERVER_START_DONE
```

Test the video stream:

```bash
ffplay -rtsp_transport tcp rtsp://DEVICE_IP/stream0
```

## Notes

- The payload does not contain a third-party RTSP server.
- It uses RTSP code already present in the vendor firmware.
- Applying `LD_PRELOAD` to a shell script may crash `sh`.
- Therefore the payload should only be injected into the real `tuya_test` ELF binary.
- The current source code additionally checks the process name before doing anything.
