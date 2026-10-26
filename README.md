# JakStore

JakStore is an internal phone-inventory app with a Laravel API and a Flutter
Android application.

## Project structure

- `backend/` — Laravel 12 API and MySQL/MariaDB migrations.
- `flutter_app/` — Flutter Android application.

## Backend setup

Requirements: PHP 8.2+, Composer 2, and MySQL 8+ or MariaDB 10.6+.

From the `backend/` directory:

```powershell
composer install
Copy-Item .env.example .env
```

Create a dedicated, empty MySQL database and application user, then configure
`DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, and `DB_PASSWORD` in
`backend/.env`. Keep `.env` private; it is excluded from Git.

```powershell
php artisan key:generate
php artisan migrate
php artisan app:make-admin
php artisan serve --host=0.0.0.0 --port=8000
```

The migrations create the schema; they do not copy data from another computer.
For demo inventory, run:

```powershell
php artisan db:seed --class="Database\Seeders\DemoInventorySeeder"
```

This creates at least ten units each for three demo models and does not remove
existing inventory.

## Android app

Install Flutter 3.6+ and dependencies from `flutter_app/`:

```powershell
flutter pub get
flutter build apk --debug --dart-define=JAKSTORE_API_BASE_URL=http://10.0.2.2:8000/api
```

`10.0.2.2` is for an Android emulator connecting to a Laravel server on the
same computer. For a physical phone on the same Wi-Fi, use the computer's LAN
address. For access from other networks, host the API at a public HTTPS address
and build the APK with that API URL. A laptop's local MySQL database is not
automatically shared with other devices.

An APK built without `JAKSTORE_API_BASE_URL` runs in local mock mode and does
not persist inventory to the Laravel database.

## Tests

Run backend tests from `backend/`:

```powershell
php artisan test
```

Run Flutter checks from `flutter_app/`:

```powershell
flutter analyze
flutter test --concurrency=1
```
