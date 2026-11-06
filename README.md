# 📡 MikroTik RouterOS Auto-Update

<div align="center">

**Автоматическое обновление RouterOS v7 + прошивки RouterBOARD**
без смены канала обновлений и без циклов перезагрузок

![RouterOS](https://img.shields.io/badge/RouterOS-v7-29b6f6?logo=mikrotik&logoColor=white)
![Shell](https://img.shields.io/badge/RouterOS%20Script-CLI-8bc34a)
![License](https://img.shields.io/badge/License-MIT-orange)
![Language](https://img.shields.io/badge/Язык-Русский-blue)

[Установка](#-установка-5-минут) • [Теория](#-теория) • [Как это работает](#-как-это-работает) • [Практические сценарии](#-практические-сценарии) • [Диагностика](#-диагностика) • [Удаление](#-удаление) • [Глоссарий](#-глоссарий)

</div>

---

## Легенда

| Метка | Значение |
|:---:|---|
| 🟢 | База |
| 🟡 | Продвинутый |
| 🔴 | Опасно |
| 💡 | Совет |

---

## 📖 Теория

🟢 На любом физическом MikroTik **обновление состоит из двух независимых шагов**:

1. **RouterOS** (пакеты `.npk`) — ставится через `/system package update install`, применяется **первой перезагрузкой**.
2. **RouterBOARD firmware** (загрузчик платы) — после обновления RouterOS поле `upgrade-firmware` становится равно новой версии, а `current-firmware` остаётся старой. Нужны `/system routerboard upgrade` + **вторая перезагрузка**.

🟢 Ключевое свойство, на котором построен репозиторий: сравнение `current-firmware != upgrade-firmware` — **идемпотентно**. После успешного upgrade + reboot значения равны, и стартовый скрипт просто выходит, ничего не записывая. Бесконечный цикл перезагрузок невозможен по конструкции.

🔴 Типичные ошибки самодельных автообновлений, которых здесь нет:

- **Переключение `disabled=yes/no` у планировщика** — это запись в config при каждой загрузке (износ flash) и single point of failure: если `scheduler set` не выполнится, получится бесконечный цикл перезагрузок.
- **Динамическое создание скрипта с экранированием `\$var`** — любая ошибка в escape-строке, и post-update скрипт не скомпилируется, вторая перезагрузка не произойдёт.
- **`/system package update cancel` перед `install`** — `install` и так скачивает пакеты после проверки, а cancel может сорвать готовую сессию.

---

## ⚙️ Как это работает

```
┌────────────────────────────────────────────────────┐
│ Планировщик ros-auto-update (раз в неделю, 03:30) │
│  check-for-updates → есть новая версия?           │
│  → install → RouterOS скачивает и ПЕРЕЗАГРУЗКА №1 │
└──────────────────────┬─────────────────────────────┘
                       ▼
        ┌──────────────────────────────────┐
        │ Планировщик ros-fw-upgrade-at-  │
        │ boot (startup, ПОСТОЯННО enabled)│
        │  delay 120s                      │
        │  cf != uf ? → upgrade + ПЕРЕЗАГРУЗКА №2
        │  cf == uf ? → log, выход (0 записей)
        └──────────────────────────────────┘
```

Состав репозитория:

| Файл | Назначение |
|---|---|
| `scripts/ros-auto-update.rsc` | Основной скрипт: проверка и установка обновлений RouterOS |
| `scripts/ros-fw-auto-upgrade.rsc` | Стартовый скрипт: прошивка RouterBOARD после загрузки |
| `scripts/install.rsc` | Скрипты + планировщики одним paste'ом |

▸ **RouterOS 7.x (current):** всё проверено на v7, `status` всегда английский (`Checking for updates...`, `New version is available: 7.x`).
▸ **RouterOS 6.x (long-term):** скрипт будет работать, но статусы и поля `/system package update` отличаются — проверяйте вручную.

---

## 🚀 Установка (5 минут)

🟢 Откройте **Terminal** в WinBox/WebFig и вставьте содержимое `scripts/install.rsc` целиком. Он создаст:

- скрипт `ros-auto-update`;
- скрипт `ros-fw-auto-upgrade`;
- планировщик `ros-fw-upgrade-at-boot` (startup, постоянный);
- планировщик `ros-auto-update` (раз в неделю).

Затем запустите первую проверку вручную:

```routeros
/system script run ros-auto-update
```

💡 Если хотите, чтобы firmware стейджилась автоматически вместе с RouterOS (без явного `/system routerboard upgrade`):

```routeros
/system routerboard settings set auto-upgrade=yes
```

Стартовый скрипт всё равно нужен — для второй перезагрузки.

---

## 🧪 Практические сценарии

### Проверить статус обновлений вручную 🟢

```routeros
/system package update check-for-updates
:put [/system package update get status]
:put [/system package update get latest-version]
```

### Посмотреть прошивку 🟢

```routeros
/system routerboard print
```

### Перенести окно обслуживания 🟡

```routeros
/system scheduler set [find name="ros-auto-update"] start-time=04:00:00 interval=7d
```

### Проверить логи автообновления 🟢

```routeros
/log print where message~"RouterOS"
```

### Запустить проверку прошивки без ожидания 🟡

```routeros
/system script run ros-fw-auto-upgrade
```

🔴 **Перед включением на проде**: у вас должен быть локальный доступ к устройству (консоль/WinBox по LAN). Автообновление с двумя перезагрузками рвёт сеть на 3–5 минут.

---

## 🔍 Диагностика

| Симптом | Причина | Решение |
|---|---|---|
| `latest-version` пустой после проверки | Нет доступа к download.mikrotik.com / DNS | `/system package update check-for-updates`, затем `get status`; проверить `/ping download.mikrotik.com` |
| Вторая перезагрузка не происходит | Скрипт `ros-fw-auto-upgrade` не в планировщике startup | `/system scheduler print`; проверить политику `reboot` |
| `get current-firmware` даёт ошибку | Это CHR/x86 — нет физической прошивки | Норма, скрипт сам пропустит (проверка `routerboard = true`) |
| Скрипт не устанавливает обновление | `policy` планировщика без `reboot` | `/system scheduler set [find name="ros-auto-update"] policy=read,write,reboot,policy,test` |

---

## 🗑 Удаление

```routeros
/system scheduler remove [find name="ros-auto-update"]
/system scheduler remove [find name="ros-fw-upgrade-at-boot"]
/system script remove [find name="ros-auto-update"]
/system script remove [find name="ros-fw-auto-upgrade"]
```

---

## 📚 Глоссарий

- **RouterOS** — операционная система MikroTik (пакеты `.npk`).
- **RouterBOARD firmware** — прошивка/загрузчик физической платы.
- **current-firmware** — активная прошивка платы.
- **upgrade-firmware** — прошивка, идущая в комплекте с установленным RouterOS.
- **Идемпотентность** — свойство операции: повторный запуск не меняет результат. Здесь: после успешного upgrade повторный запуск скрипта — no-op.
- **Канал обновлений** — long-term / stable / testing. Скрипты канала **не меняют**.

---

## 📄 Лицензия

MIT — см. [LICENSE](LICENSE).

## 🏷 Теги

См. [TAGS.md](TAGS.md).
