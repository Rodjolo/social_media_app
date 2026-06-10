# Социальная сеть на Flutter

Мобильное приложение социальной сети, разработанное на Flutter. В проекте есть:

- авторизация пользователей;
- профили;
- посты с изображениями;
- поиск пользователей;
- модуль рекомендаций фильмов;
- локальный backend на PocketBase.

Чат в текущей версии отключен из активного интерфейса, но его код сохранен в репозитории.

## Что реализовано

- регистрация и вход пользователей;
- лента постов;
- создание постов с изображениями;
- профиль пользователя и подписки;
- поиск пользователей;
- экран фильмов с оценками и лайками;
- экран рекомендаций;
- админ-панель пересчета рекомендаций;
- pipeline рекомендаций на Python.

## Архитектура

Проект организован по feature-first подходу. Основные модули:

- `auth` — авторизация;
- `profile` — профиль пользователя;
- `post` — посты;
- `search` — поиск;
- `movies` — фильмы, оценки и рекомендации;
- `storage` — работа с файлами;
- `home` — основная навигация.

Для управления состоянием используется `Cubit` из `flutter_bloc`.

## Backend

Основной backend проекта сейчас — PocketBase.

Через него работают:

- пользователи;
- посты;
- медиафайлы;
- фильмы;
- оценки фильмов;
- рекомендации.

Подробная настройка описана в:

- [настройке PocketBase](docs/pocketbase_setup.md)
- [схеме архитектуры и БД](docs/architecture_schema.md)
- [схеме сбора данных](docs/data_collection_schema.md)

## Система рекомендаций

Рекомендации считаются не внутри Flutter, а отдельным Python pipeline:

1. Пользователь оценивает фильмы в приложении.
2. Оценки сохраняются в PocketBase.
3. Python-скрипты экспортируют оценки пользователя.
4. Они объединяются с датасетом MovieLens.
5. Алгоритм item-based collaborative filtering строит рекомендации.
6. Результат записывается обратно в PocketBase.
7. Flutter показывает пользователю готовую подборку.

Подробности и команды:

- [команды пайплайна рекомендаций](tools/recommendation_pipeline/README.md)
- [описание системы рекомендаций для диплома](docs/diploma_recommendation_system.md)

## Запуск приложения

```powershell
flutter pub get
flutter run
```

Если используется Android Emulator, PocketBase по умолчанию ожидается по адресу:

- `http://10.0.2.2:8090`

При необходимости адрес можно переопределить:

```powershell
flutter run --dart-define=POCKETBASE_URL=http://10.0.2.2:8090
```

Если используется локальный сервис пересчета рекомендаций, токен приложения и сервиса должен совпадать:

```powershell
flutter run `
  --dart-define=POCKETBASE_URL=http://10.0.2.2:8090 `
  --dart-define=RECOMMENDATION_SERVICE_URL=http://10.0.2.2:8091 `
  --dart-define=RECOMMENDATION_SERVICE_TOKEN=local-recommendation-service
```

### Запуск на реальном Android-устройстве

Если приложение запускается на реальном телефоне, адрес `10.0.2.2` использовать нельзя: он работает только в Android Emulator. Телефон должен обращаться к IP-адресу компьютера в локальной сети.

1. Узнать IPv4-адрес компьютера:

```powershell
ipconfig
```

Например:

```text
192.168.31.235
```

2. Запустить PocketBase так, чтобы он был доступен телефону:

```powershell
cd "C:\PocketBase"
.\pocketbase.exe serve --http=0.0.0.0:8090
```

3. Запустить локальный сервис рекомендаций:

```powershell
cd "C:\Flutter Projects\SocialMediaApp\social_media_app"

python .\tools\recommendation_pipeline\recommendation_service.py `
  --host 0.0.0.0 `
  --base-url "http://127.0.0.1:8090" `
  --superuser-email "YOUR_POCKETBASE_EMAIL" `
  --superuser-password "YOUR_POCKETBASE_PASSWORD" `
  --api-token "local-recommendation-service"
```

4. Проверить с телефона в браузере:

```text
http://192.168.31.235:8090/_/
http://192.168.31.235:8091/health
```

5. Запустить приложение на телефоне:

```powershell
flutter run `
  --dart-define=POCKETBASE_URL=http://192.168.31.235:8090 `
  --dart-define=RECOMMENDATION_SERVICE_URL=http://192.168.31.235:8091 `
  --dart-define=RECOMMENDATION_SERVICE_TOKEN=local-recommendation-service
```

Если IP компьютера изменился, приложение нужно запускать или собирать заново с новым `POCKETBASE_URL` и `RECOMMENDATION_SERVICE_URL`.

### Сборка APK для демонстрации

Для демонстрации на реальном устройстве можно собрать release APK:

```powershell
flutter build apk --release `
  --dart-define=POCKETBASE_URL=http://192.168.31.235:8090 `
  --dart-define=RECOMMENDATION_SERVICE_URL=http://192.168.31.235:8091 `
  --dart-define=RECOMMENDATION_SERVICE_TOKEN=local-recommendation-service
```

Готовый файл:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Передать APK на телефон можно любым удобным способом:

- отправить себе в Telegram, WhatsApp или VK;
- загрузить в Google Drive, Яндекс Диск или OneDrive;
- поднять локальную раздачу файла:

```powershell
cd "C:\Flutter Projects\SocialMediaApp\social_media_app\build\app\outputs\flutter-apk"
python -m http.server 8080
```

После этого открыть на телефоне:

```text
http://192.168.31.235:8080/app-release.apk
```

Android может попросить разрешить установку из неизвестных источников для браузера, Telegram или файлового менеджера.

### Публикация APK в GitHub Releases

Через сайт GitHub:

1. Открыть репозиторий на GitHub.
2. Перейти в `Releases`.
3. Нажать `Draft a new release`.
4. Создать tag, например `v1.0.0-demo`.
5. Указать название, например `Demo APK`.
6. Прикрепить файл `build\app\outputs\flutter-apk\app-release.apk`.
7. Нажать `Publish release`.

Через GitHub CLI:

```powershell
gh release create v1.0.0-demo `
  "build\app\outputs\flutter-apk\app-release.apk" `
  --title "Demo APK" `
  --notes "Демонстрационная APK-версия приложения с PocketBase и системой рекомендаций."
```

Важно: APK, собранный с локальным IP вроде `192.168.31.235`, будет работать только в той сети, где телефон видит компьютер с запущенным PocketBase и сервисом рекомендаций.

## Запуск PocketBase

```powershell
.\pocketbase.exe serve
```

## Для диплома

В проекте уже есть:

- модуль фильмов и рекомендаций;
- админ-панель пересчета;
- метрики качества профиля;
- автоматизация пересчета одной командой;
- локальный HTTP-сервис для запуска пересчета из приложения;
- краткая пояснительная документация по алгоритму.
