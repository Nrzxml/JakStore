<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class ImeiInfoDeviceIdentificationProvider implements DeviceIdentificationProvider
{
    public function identify(string $imei): DeviceIdentificationResult
    {
        $config = config('services.imei_info');
        if (
            ! is_string($config['api_key'] ?? null)
            || trim($config['api_key']) === ''
            || ! is_numeric($config['service_id'] ?? null)
            || ! is_string($config['brand_path'] ?? null)
            || trim($config['brand_path']) === ''
            || ! is_string($config['model_path'] ?? null)
            || trim($config['model_path']) === ''
        ) {
            return new DeviceIdentificationResult(
                status: 'not_configured',
                message: 'API key, service ID, atau jalur field hasil IMEI.info '
                    .'belum dikonfigurasi. Pilih model secara manual.',
            );
        }

        $cacheKey = 'imei-lookup:'.hash('sha256', implode("\0", [
            (string) $config['sync_base_url'],
            (string) $config['service_id'],
            $imei,
            (string) $config['brand_path'],
            (string) $config['model_path'],
            (string) ($config['model_code_path'] ?? ''),
            (string) ($config['tac_path'] ?? ''),
        ]));
        $ttlMinutes = max(0, (int) ($config['cache_minutes'] ?? 0));
        if ($ttlMinutes <= 0) {
            return $this->requestLookup($imei, $config);
        }

        $cached = Cache::get($cacheKey);
        if ($cached instanceof DeviceIdentificationResult) {
            return $cached;
        }

        $result = $this->requestLookup($imei, $config);
        if (in_array($result->status, ['identified', 'not_found'], true)) {
            Cache::put($cacheKey, $result, now()->addMinutes($ttlMinutes));
        }

        return $result;
    }

    private function requestLookup(string $imei, array $config): DeviceIdentificationResult
    {
        try {
            $response = Http::acceptJson()
                ->timeout(max(1, (int) ($config['timeout_seconds'] ?? 8)))
                ->get(
                    rtrim((string) $config['sync_base_url'], '/')
                        .'/check/'.rawurlencode((string) $config['service_id']).'/',
                    ['API_KEY' => $config['api_key'], 'imei' => $imei],
                );
        } catch (ConnectionException) {
            return new DeviceIdentificationResult(
                status: 'unavailable',
                message: 'Layanan IMEI.info tidak dapat dihubungi. Pilih model '
                    .'secara manual.',
            );
        }

        if ($response->status() === 202) {
            return new DeviceIdentificationResult(
                status: 'unavailable',
                message: 'Hasil lookup masih diproses oleh provider. Pilih model '
                    .'secara manual atau coba kembali nanti.',
            );
        }

        if ($response->status() === 404) {
            return new DeviceIdentificationResult(
                status: 'unavailable',
                message: 'Layanan provider atau service ID tidak ditemukan. Periksa '
                    .'konfigurasi IMEI.info.',
            );
        }

        if ($response->status() === 429) {
            return new DeviceIdentificationResult(
                status: 'unavailable',
                message: 'Batas permintaan provider tercapai. Pilih model secara '
                    .'manual dan coba lagi nanti.',
            );
        }

        if (! $response->successful()) {
            return new DeviceIdentificationResult(
                status: 'unavailable',
                message: 'Provider lookup sedang tidak tersedia. Pilih model '
                    .'secara manual.',
            );
        }

        $payload = $response->json();
        if (! is_array($payload)) {
            return new DeviceIdentificationResult(
                status: 'incomplete',
                message: 'Provider mengembalikan respons yang tidak dapat dibaca. '
                    .'Pilih model secara manual.',
            );
        }

        $status = strtolower((string) Arr::get($payload, 'status', ''));
        $result = Arr::get($payload, 'result');
        if (in_array($status, ['rejected', 'refunded', 'in_progress'], true)) {
            return new DeviceIdentificationResult(
                status: 'unavailable',
                message: 'Provider tidak menyelesaikan lookup. Pilih model secara '
                    .'manual atau periksa saldo dan service ID provider.',
            );
        }
        if ($status === 'done' && ($result === null || $result === [])) {
            return new DeviceIdentificationResult(
                status: 'not_found',
                message: 'Provider tidak menemukan informasi model untuk IMEI ini.',
            );
        }

        $brand = $this->field($payload, (string) $config['brand_path']);
        $modelName = $this->field($payload, (string) $config['model_path']);
        if ($brand === null || $modelName === null) {
            return new DeviceIdentificationResult(
                status: 'incomplete',
                message: 'Hasil provider tidak memiliki merek/model pada field '
                    .'yang dikonfigurasi. Pilih model secara manual.',
            );
        }

        return new DeviceIdentificationResult(
            status: 'identified',
            message: 'Merek dan model ditemukan oleh provider lookup.',
            brand: $brand,
            modelName: $modelName,
            modelCode: $this->field(
                $payload,
                (string) ($config['model_code_path'] ?? ''),
            ),
            tac: $this->field($payload, (string) ($config['tac_path'] ?? '')),
            source: 'IMEI.info',
        );
    }

    private function field(array $payload, string $path): ?string
    {
        if ($path === '') {
            return null;
        }
        $value = Arr::get($payload, $path);
        if (! is_string($value) && ! is_numeric($value)) {
            return null;
        }
        $value = trim((string) $value);

        return $value === '' ? null : mb_substr($value, 0, 150);
    }
}
