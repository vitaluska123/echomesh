# EchoMesh

**Сообщения доходят. Даже когда интернет выключили.**

EchoMesh — полностью децентрализованный, peer-to-peer мессенджер без серверов, устойчивый к блокировкам и отключениям интернета. Обмен ключами один раз (QR / NFC), end-to-end шифрование уровня Signal, сообщения прыгают по цепочке устройств через Bluetooth / Wi-Fi Direct / интернет.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.29+-blue?logo=flutter&logoColor=white)](https://flutter.dev)
[![Rust](https://img.shields.io/badge/Rust-libp2p-orange?logo=rust&logoColor=white)](https://libp2p.io)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-success)](#installation)

## О проекте

В 2026 году интернет могут отключить в любой момент. EchoMesh даёт возможность общаться без центральных серверов, без доверия провайдерам и без риска блокировки.

### Ключевые возможности

- **Полностью P2P**: нет серверов, только прямые соединения + relay через контакты
- **Оффлайн-мэш**: сообщения прыгают по цепочке устройств через Bluetooth / Wi-Fi Direct (multi-hop)
- **Автоматическое переключение**: интернет → relay → локальный Bluetooth / Wi-Fi
- **End-to-end шифрование**: Noise Protocol + Double Ratchet (perfect forward secrecy)
- **Обмен ключами один раз**: QR-код или NFC при встрече
- **Надёжная доставка**: ACK + retry + store-and-forward (даже если отправитель оффлайн)
- **Медиа**: chunked transfer фото/видео с возобновлением
- **Настройки "Сеть пиров"**: решай, сколько батареи / места отдаёшь для помощи друзьям
- **Экономия батареи**: 3 уровня авто-ограничений по % заряда
- **Режим изоляции**: только локальный обмен без DHT / интернета

### Почему EchoMesh актуален именно сейчас

- Устойчив к DPI и блокировкам (QUIC + обфускация в планах)
- Работает при полном отключении мобильного интернета
- В плотной студенческой / городской среде сообщения могут преодолевать километры по цепочке

## Дорожная карта (Roadmap)

**Phase 1 — MVP (текст + базовый P2P)** — в работе  
- Генерация ключей + QR/NFC обмен  
- Добавление контакта  
- 1-на-1 чат через libp2p request-response  
- ACK + retry + локальная очередь  
- Фоновый сервис (Android)  
- Material 3 UI  

**Phase 2 — Оффлайн-мэш**  
- Bluetooth Low Energy + Wi-Fi Direct (Android-first)  
- Multi-hop routing (TTL + seen set)  
- Автопереключение транспортов  
- Режим «Изоляция»  

**Phase 3 — Полная надёжность**  
- Store-and-forward через контакты  
- Настройки «Сеть пиров» + экономия батареи  
- Chunked медиа + resume  
- Double Ratchet  

**Phase 4 — Полировка**  
- iOS background + desktop  
- Статистика помощи сети  
- Локализация (русский + английский)  
- F-Droid / GitHub Releases  

## Технологии

- **UI**: Flutter 3.29+ (Material 3)  
- **P2P-ядро**: Rust + libp2p (QUIC, Noise, Kademlia DHT, circuit relay v2, request-response)  
- **Мост**: flutter_rust_bridge  
- **Крипто**: Double Ratchet (на базе libsignal-protocol или аналог)  
- **Bluetooth**: flutter_blue_plus  
- **Фон**: flutter_background_service  
- **Хранение**: drift (SQLite)  
- **Батарея**: battery_plus  
- **QR/NFC**: mobile_scanner, qr_flutter, nfc_manager  

## Установка и запуск (для разработчиков)

### Предварительные требования

- Flutter 3.29+  
- Rust (stable) + cargo  
- flutter_rust_bridge_codegen  

### Быстрый старт

```bash
# 1. Клонируем репозиторий
git clone https://github.com/ВАШ_НИК/echomesh.git
cd echomesh

# 2. Генерируем мост Flutter ↔ Rust
flutter_rust_bridge_codegen generate --watch

# 3. Устанавливаем зависимости
flutter pub get
cd rust && cargo build && cd ..

# 4. Запуск (Android / desktop)
flutter run

# linux 
LD_LIBRARY_PATH=$(pwd)/rust/target/debug \
  flutter run -d linux --verbose
  
# Для iOS: откройте ios/Runner.xcworkspace в Xcode
```

Подробная инструкция по сборке для каждой платформы → BUILD.md (создадим позже)

### Как внести вклад
- Форкни репозиторий
- Создай ветку (`git checkout -b feature/крутая-фича`)
- Закоммить изменения (`git commit -m 'Add крутая фича'`)
- Запушь (`git push origin feature/крутая-фича`)
- Открой Pull Request

#### Мы приветствуем любые PR: от фиксов багов до переводов, иконок, улучшения UI, обфускации трафика и т.д.
### Лицензия
MIT License — делай что хочешь, но сохраняй копирайт и указывай авторов.

### Контакты / обсуждение
- Issues здесь на GitHub
- Telegram-канал / чат (создадим после MVP)

Сообщения доходят. Даже когда всё выключили.

Спасибо, что читаешь! Если проект зацепил — поставь ⭐ — это мотивирует.
