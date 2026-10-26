# JakStore API

Laravel 12 REST API for the JakStore Android inventory app. The backend uses
PHP 8.2+, MySQL 8.0+ or a compatible MariaDB release, and Laravel Sanctum
personal access tokens. No real catalog or stock records are seeded.

## Requirements

- PHP 8.2+ with `ctype`, `curl`, `fileinfo`, `mbstring`, `openssl`, `pdo_mysql`,
  `tokenizer`, `xml`, and `zip`
- Composer 2.x
- MySQL 8.0+ or MariaDB 10.6+
- Flutter 3.6+ for the companion Android app

The development workspace has PHP 8.2.12 and Composer 2.9.5 available through
the existing XAMPP installation. Laravel project files are in `backend/`;
Composer cache and temporary files for this workspace are directed to
`D:\JakStoreTools`.

## Install and configure

From `backend/`, install dependencies and copy the safe environment template:

```powershell
composer install
Copy-Item .env.example .env
php artisan key:generate
```

Create a dedicated MySQL database and user in your local database manager or
hosting control panel. Do not use the MySQL root account for the application.
Then set `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, and `DB_PASSWORD`
in the ignored `.env` file. Never commit `.env`.

Run schema migrations only after confirming `.env` points to the intended,
empty JakStore database:

```powershell
php artisan migrate
php artisan app:make-admin
```

`app:make-admin` prompts for a name, email, and password (minimum 12
characters). It hashes the password, creates an admin-only account, and does
not print or seed credentials. There is no public signup endpoint.

Run the development server:

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

Run backend tests without touching MySQL:

```powershell
php artisan test
```

The PHPUnit configuration uses an in-memory SQLite database. Tests do not call
the paid provider.

## API authentication and contracts

All routes are under `/api`. `GET /api/health` is public and returns only
`{"data":{"status":"ok"}}`. `POST /api/login` accepts `email`, `password`, and
optional `device_name`; it returns a Sanctum bearer token and the admin profile.
Tokens expire after 10,080 minutes (seven days) by default. Configure the
duration with `SANCTUM_EXPIRATION`. Send authenticated requests with:

```http
Authorization: Bearer <token>
Accept: application/json
```

| Method | Path | Description |
| --- | --- | --- |
| `POST` | `/api/login` | Admin sign-in; limited to five attempts per minute per IP |
| `POST` | `/api/logout` | Revoke the current token |
| `GET` | `/api/me` | Current admin profile |
| `GET` | `/api/dashboard` | Physical-unit counts, daily movements, low-stock variants, recent activity |
| `GET` | `/api/reports` | Counts by status and variant, plus recent stock movements |
| `GET/POST/PATCH` | `/api/brands` | List, add, or deactivate/update catalog brands |
| `GET/POST/PATCH` | `/api/models` | List, add, or deactivate/update device models |
| `GET/POST/PATCH` | `/api/variants` | List, add, or deactivate/update color/storage variants |
| `GET/POST` | `/api/inventory` | Paginated physical-unit list and create |
| `GET` | `/api/inventory/{id}` | Unit detail with movement history |
| `PUT/PATCH` | `/api/inventory/{id}` | Correct IMEI fields or choose another active variant |
| `PATCH` | `/api/inventory/{id}/status` | Change a non-sold unit status |
| `POST` | `/api/inventory/scan-outgoing` | Sell an available unit by IMEI 1 or IMEI 2 |
| `POST` | `/api/inventory/identify` | Check local IMEI first, then optionally call the configured provider |

Inventory accepts `product_variant_id`, `imei1`, optional `imei2`, optional
initial `status` (`available`, `service`, `damaged`, or `returned`), and optional
`note`. A sold status can only be created by the outgoing-scan endpoint.
`GET /api/inventory` supports `page`, `per_page` (1–100), `q`, `status`,
`variant_id`, and `model_id`.

The API returns JSON resources under `data`; validation failures use HTTP 422
and Laravel's `message`/`errors` format. Catalog creation is explicit and
never occurs as a side effect of an IMEI lookup. There are no demo catalog or
inventory seeders.

Catalog rows can be created with the authenticated endpoints before the first
stock intake. For example, use the returned IDs for each next request:

```http
POST /api/brands
{"name":"Samsung"}

POST /api/models
{"brand_id":1,"name":"Galaxy S24 Ultra","model_code":"SM-S928"}

POST /api/variants
{"device_model_id":1,"color":"Titanium Black","storage":"512 GB","sku":"SAM-S24U-512"}
```

The API does not provide a catalog editor screen in the current Flutter app;
create and maintain catalog entries through an authenticated API client or an
admin tool before recording stock.

## Data and stock rules

- A physical phone is one `inventory_units` row, whether it has one or two IMEIs.
- IMEIs are strings validated as 15 digits with a Luhn check digit.
- Unique indexes protect each IMEI field. `inventory_imei_claims` additionally
  enforces uniqueness across both slots, including concurrent writes.
- Unit creation and IMEI claim creation run in one transaction.
- Deleting catalog rows is not exposed; foreign keys restrict deleting
  referenced brand/model/variant rows. Deactivate them instead.
- Sale and status changes create stock movement records. Dashboard/report totals
  count physical unit rows, not IMEI claims.
- Lookup checks `inventory_imei_claims` before contacting any external provider.

## IMEI.info provider

The Laravel adapter is implemented, but provider lookup is disabled until an
account, an active service, and its result fields are configured. Select an
IMEI-based service from the IMEI.info account dashboard and add the following
values to the backend `.env`:

```dotenv
IMEI_LOOKUP_PROVIDER=imei_info
IMEI_LOOKUP_API_KEY=
IMEI_LOOKUP_SERVICE_ID=
IMEI_LOOKUP_SYNC_BASE_URL=https://dash.imei.info/api-sync
IMEI_LOOKUP_TIMEOUT_SECONDS=8
IMEI_LOOKUP_CACHE_MINUTES=360
IMEI_LOOKUP_BRAND_PATH=
IMEI_LOOKUP_MODEL_PATH=
IMEI_LOOKUP_MODEL_CODE_PATH=
IMEI_LOOKUP_TAC_PATH=
```

Do not place the API key in Flutter, source control, requests from the mobile
client, or API responses. The provider's published Postman collection documents
the one-step request as `GET /api-sync/check/{service_id}/` with `API_KEY` and
`imei` query parameters. The official OpenAPI defines the corresponding
`GET /api/check/{service}/` operation, requires `API_KEY`, and lists `imei` as
a service-dependent query parameter. The `/api-sync/` prefix selects the
documented one-step variant. Copy the numeric service ID from the account's
available-services endpoint or dashboard; the application cannot select or
infer it. The available input parameter and response fields depend on the
service selected in that account.

The OpenAPI describes `status` and an object `result`, but does not define
universal brand/model property names within `result`. Inspect one authorized
service response in the provider's dashboard/API tooling and set `*_PATH` to
the exact JSON paths returned by that service (for example
`result.<verified-brand-field>` and `result.<verified-model-field>`). Do not
guess these paths. The API does not assume fields exist and does not fabricate
a model when they are missing. The ordinary API's queued `202` response is not
polled; it falls back to manual catalog selection.

The documentation page advertises a minimum `$5` balance and simple lookups
from `$0.02` per request; actual service pricing and available fields must be
checked in the provider account. Each external lookup may incur a charge. Local
inventory hits never call the provider. A SHA-256 cache key avoids placing the
raw IMEI in the cache key; only successful identification and not-found results
are cached for six hours by default. Temporary failures, incomplete responses,
pending requests, and rate limits are not cached, so a retry can recover.

IMEICheck.com also documents
`https://alpha.imeicheck.com/api/modelBrandName?imei=...&format=json` and says a
personal key is free with a 60-request-per-minute limit after contacting the
provider. Its public endpoint is CAPTCHA-protected, and the published page does
not document how the personal key is passed in API requests. This project does
not call the CAPTCHA-protected endpoint or invent an authentication method.
IMEI.info is used by the existing adapter because its API key, service-ID,
request-method, and query-parameter contract is documented; it is paid, so no
lookup is sent until credentials and account service configuration are
provided.

Provider output identifies a possible model only. It is not proof of device
authenticity, legal status, or blacklist status. Admins must select/confirm
color, storage, and status before adding a physical unit. If the configured
provider is unavailable, rate-limited, pending, or returns incomplete data,
the API returns a manual-fallback status.

Documentation reviewed:

- [IMEI.info API overview and pricing](https://www.imei.info/id/api/imei/docs/)
- [IMEI.info API v5 OpenAPI](https://dash.imei.info/swagger/?format=openapi)
- [IMEI.info API v5 Postman collection](https://www.imei.info/strapi/uploads/IMEI_info_API_v5_postman_collection_5f797bd3a4.json)
- [IMEICheck TAC database and API notice](https://imeicheck.com/imei-tac-database-info/)
- [IMEICheck contact page for personal API key](https://imeicheck.com/contact)

## Flutter Android app

The app supports both the original in-memory mock mode and the Laravel API.
Without a `JAKSTORE_API_BASE_URL` define it starts in mock mode. When the
define is supplied, the app requires an admin login, stores the Sanctum token
using Android secure storage, and loads the catalog, inventory, and recent
movements from the backend. Unit creation, status changes, outgoing scans, and
IMEI identification call the API; server validation errors are shown in the UI.
After each stock mutation the app reloads the authoritative server data.

The API base URL must include `/api` and must not end with a route name.

Android emulator connecting to a development server on the same PC:

```powershell
flutter run --dart-define=JAKSTORE_API_BASE_URL=http://10.0.2.2:8000/api
```

An APK built without `JAKSTORE_API_BASE_URL` intentionally runs with mock
in-memory data and cannot call Laravel or an IMEI provider. To build an
emulator-connected debug APK, pass the same define:

```powershell
flutter build apk --debug --dart-define=JAKSTORE_API_BASE_URL=http://10.0.2.2:8000/api
```

For a physical Android phone on the same network, use the development computer's
LAN address. For deployment, use the actual HTTPS API origin. `localhost` in
Android refers to the device itself, not the development PC. Debug builds allow
cleartext HTTP for local development only; release builds must use HTTPS. Do not
ship the development HTTP configuration in a production build.

The mobile app stores bearer tokens using Android secure storage. Configure the
deployment base URL only after DNS, HTTPS, MySQL credentials, and the admin
account are set up. No production server or database credentials are included
in this repository.

## Hosting and deployment

Use a hosting plan that supports the required PHP version, Composer deployment,
MySQL, HTTPS, and Laravel's `public/` document root (or a hosting-supported
front-controller arrangement). Point the web root at `backend/public`; do not
expose `.env`, `vendor/`, or the project root directly. Set production
environment values out of band, including `APP_ENV=production`,
`APP_DEBUG=false`, a unique `APP_KEY`, MySQL credentials, `IMEI_LOOKUP_*`
secrets if applicable, and `APP_URL=https://<your-actual-api-domain>`. Run
migrations against the intended database after a backup and deployment review.

## Current implementation limitations

- MySQL migrations and credentials have not been applied to the currently
  running local MariaDB services. Backend feature tests use in-memory SQLite;
  configure and verify the target MySQL database before use.
- The Flutter API client and admin sign-in are implemented. Backend/MySQL
  end-to-end sign-in still requires a configured database, an admin created
  with `php artisan app:make-admin`, and a reachable server.
- Live provider lookup has not been called. It requires an account API key,
  paid balance, valid service ID, and field paths confirmed against that
  service's real response.
- No real inventory records are present in the backend. Import only
  administrator-verified catalog and stock data; never use the Flutter demo
  IMEIs as production records.
