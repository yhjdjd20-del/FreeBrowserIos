# Создание BrowserX.xcodeproj

Файл `.xcodeproj` — это бинарный/plist-пакет, генерируемый Xcode, поэтому его нельзя надёжно
поставить как текстовый код-блок. Вместо этого — 2 варианта:

## Вариант A — быстрый (рекомендуется)
1. Xcode → File → New → Project → **App** → назвать `BrowserX`, интерфейс **SwiftUI**, язык **Swift**.
2. Удалить сгенерированные `BrowserXApp.swift` / `ContentView.swift`.
3. Перетащить папку `BrowserX/App`, `Models`, `Managers`, `Views`, `Utilities`, `Extensions`, `Services`
   в навигатор проекта (галочка "Copy items if needed" + "Create groups").
4. Добавить капабилити: Keychain Sharing, Face ID (`NSFaceIDUsageDescription` в Info.plist).
5. Минимальная версия iOS: 17.0. Swift Language Version: 6.

## Вариант B — через Package.swift (для CI / кросс-платформенной логики)
`Package.swift` в корне репозитория собирает бизнес-логику (`BrowserXCore`) как SPM-библиотеку —
удобно для unit-тестов без полного iOS app target.

```bash
swift build
swift test
```

## Структура target'ов
| Target | Назначение |
|---|---|
| `BrowserX` (App) | Основное iOS/macOS приложение |
| `BrowserXCore` (SPM lib) | Models/Managers/Services/Utilities — переиспользуемая логика |
| `BrowserXCoreTests` | Unit-тесты |
