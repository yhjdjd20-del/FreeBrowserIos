# BrowserX 🌐

Полнофункциональный нативный браузер для iOS/iPadOS/macOS на **SwiftUI + WebKit + Swift 6**.

## ✨ Возможности

- Умная адресная строка (поиск / URL / AI-запрос)
- Менеджер вкладок (drag & drop, горизонтальная полоса, закрытие свайпом)
- Менеджер загрузок (пауза/возобновление, сохранение в `FileManager`)
- Система расширений (протокол `BrowserExtension` + Content Scripts)
- Интеграция с ИИ (Claude API) — чат-сайдбар, суммаризация страниц
- Keychain + Face ID / Touch ID — менеджер паролей
- Reader Mode (упрощённое чтение статей)
- Закладки, история, снапшоты вкладок, RSS-ридер, приватный режим, блокировщик рекламы,
  тёмная тема, синхронизация настроек, жесты, поиск на странице, экспорт/импорт закладок,
  менеджер cookies, режим "Картинка в картинке", быстрые команды (Shortcuts)

## 📂 Структура проекта

```
BrowserX/
├── BrowserX.xcodeproj/          # Xcode-проект (см. XCODEPROJ.md)
├── Package.swift                # SPM-манифест (для модульной части логики)
├── BrowserX/
│   ├── App/                     # Точка входа
│   ├── Models/                  # Модели данных
│   ├── Managers/                # Бизнес-логика (вкладки, загрузки, keychain...)
│   ├── Views/                   # SwiftUI-экраны
│   ├── Utilities/               # Вспомогательные функции
│   ├── Extensions/               # Система расширений браузера
│   └── Services/                 # Интеграции (AIService — Claude API)
└── README.md
```

## 🚀 Запуск

1. Установите **Xcode 16+** (Swift 6, iOS 18 SDK).
2. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/yourname/BrowserX.git
   cd BrowserX
   ```
3. Откройте `BrowserX.xcodeproj` (или создайте новый проект в Xcode и перетащите папку `BrowserX/` в него — все файлы уже разложены по правильным группам).
4. Убедитесь, что в **Signing & Capabilities** включены:
   - `Keychain Sharing`
   - `App Sandbox` → `Outgoing Connections (Client)`
   - `Face ID` usage description в `Info.plist` (`NSFaceIDUsageDescription`)
5. Соберите и запустите на симуляторе/устройстве (`Cmd+R`).

## 🔑 Настройка API-ключа Claude

`AIService.swift` читает ключ из Keychain, а не из кода (это безопасно и не попадёт в git).

1. При первом запуске откройте **Settings → AI Assistant → Claude API Key**.
2. Вставьте свой ключ (получить на https://console.anthropic.com/).
3. Ключ сохраняется через `KeychainManager` (`com.browserx.claude-api-key`), защищён Face ID.

Либо для отладки — можно временно задать переменную окружения в схеме запуска Xcode:

```
CLAUDE_API_KEY = sk-ant-xxxxxxxxxxxxxxxx
```

`AIService` проверяет `ProcessInfo.processInfo.environment["CLAUDE_API_KEY"]` как fallback.

⚠️ **Никогда не коммитьте реальный ключ в git.** Файл `.gitignore` уже исключает `Secrets.swift` / `.env`, если вы решите использовать такой подход.

## 🧩 Расширения

Добавить своё расширение — реализовать протокол `BrowserExtension` (см. `Extensions/BrowserExtension.swift`) и зарегистрировать в `ExtensionManager`.

## 📦 Пакетная поставка кода

Данный проект выдаётся частями (по 3–5 файлов на сообщение) из-за объёма. См. историю чата/PR для полного списка коммитов.

## 📄 Лицензия

MIT License — используйте свободно.
