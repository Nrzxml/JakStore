<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'imei_info' => [
        'provider' => env('IMEI_LOOKUP_PROVIDER', 'none'),
        'api_key' => env('IMEI_LOOKUP_API_KEY'),
        'service_id' => env('IMEI_LOOKUP_SERVICE_ID'),
        'sync_base_url' => env('IMEI_LOOKUP_SYNC_BASE_URL', 'https://dash.imei.info/api-sync'),
        'timeout_seconds' => (int) env('IMEI_LOOKUP_TIMEOUT_SECONDS', 8),
        'cache_minutes' => (int) env('IMEI_LOOKUP_CACHE_MINUTES', 360),
        'brand_path' => env('IMEI_LOOKUP_BRAND_PATH'),
        'model_path' => env('IMEI_LOOKUP_MODEL_PATH'),
        'model_code_path' => env('IMEI_LOOKUP_MODEL_CODE_PATH'),
        'tac_path' => env('IMEI_LOOKUP_TAC_PATH'),
    ],

];
