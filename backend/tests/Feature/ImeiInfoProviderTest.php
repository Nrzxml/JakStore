<?php

namespace Tests\Feature;

use App\Services\ImeiInfoDeviceIdentificationProvider;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ImeiInfoProviderTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config([
            'services.imei_info.provider' => 'imei_info',
            'services.imei_info.api_key' => 'test-secret',
            'services.imei_info.service_id' => '17',
            'services.imei_info.sync_base_url' => 'https://dash.imei.info/api-sync',
            'services.imei_info.timeout_seconds' => 4,
            'services.imei_info.cache_minutes' => 360,
            'services.imei_info.brand_path' => 'result.brand',
            'services.imei_info.model_path' => 'result.model',
            'services.imei_info.model_code_path' => 'result.model_code',
            'services.imei_info.tac_path' => 'result.tac',
        ]);
        Cache::flush();
    }

    public function test_calls_the_documented_sync_endpoint_and_normalizes_configured_fields(): void
    {
        Http::fake([
            'dash.imei.info/api-sync/check/17/*' => Http::response([
                'status' => 'Done',
                'result' => [
                    'brand' => 'Samsung',
                    'model' => 'Galaxy S24',
                    'model_code' => 'SM-S921B',
                    'tac' => '12345678',
                ],
            ]),
        ]);

        $result = app(ImeiInfoDeviceIdentificationProvider::class)
            ->identify('490154203237518');

        $this->assertSame('identified', $result->status);
        $this->assertSame('Samsung', $result->brand);
        $this->assertSame('Galaxy S24', $result->modelName);
        $this->assertSame('SM-S921B', $result->modelCode);
        $this->assertSame('IMEI.info', $result->source);
        Http::assertSent(fn ($request): bool => $request->method() === 'GET'
            && str_contains($request->url(), '/api-sync/check/17/')
            && $request['API_KEY'] === 'test-secret'
            && $request['imei'] === '490154203237518');
    }

    public function test_missing_credentials_or_field_mapping_never_calls_provider(): void
    {
        config(['services.imei_info.api_key' => null]);
        Http::preventStrayRequests();

        $result = app(ImeiInfoDeviceIdentificationProvider::class)
            ->identify('490154203237518');

        $this->assertSame('not_configured', $result->status);
        Http::assertNothingSent();
    }

    public function test_incomplete_provider_response_is_not_guessed(): void
    {
        Http::fake([
            'dash.imei.info/api-sync/check/17/*' => Http::response([
                'status' => 'Done',
                'result' => ['brand' => 'Samsung'],
            ]),
        ]);

        $result = app(ImeiInfoDeviceIdentificationProvider::class)
            ->identify('490154203237518');

        $this->assertSame('incomplete', $result->status);
        $this->assertNull($result->modelName);
    }

    public function test_provider_rate_limit_and_pending_results_allow_manual_fallback(): void
    {
        Http::fakeSequence()
            ->push(['message' => 'pending'], 202)
            ->push(['message' => 'rate limited'], 429);

        $provider = app(ImeiInfoDeviceIdentificationProvider::class);
        $pending = $provider->identify('490154203237518');
        $limited = $provider->identify('356938035643809');

        $this->assertSame('unavailable', $pending->status);
        $this->assertSame('unavailable', $limited->status);
    }

    public function test_transient_provider_errors_are_not_cached(): void
    {
        Http::fakeSequence()
            ->push(['message' => 'rate limited'], 429)
            ->push([
                'status' => 'Done',
                'result' => [
                    'brand' => 'Samsung',
                    'model' => 'Galaxy S24',
                ],
            ]);

        $provider = app(ImeiInfoDeviceIdentificationProvider::class);
        $first = $provider->identify('490154203237518');
        $second = $provider->identify('490154203237518');

        $this->assertSame('unavailable', $first->status);
        $this->assertSame('identified', $second->status);
        Http::assertSentCount(2);
    }

    public function test_provider_http_failures_and_invalid_json_do_not_create_fake_models(): void
    {
        Http::fakeSequence()
            ->push('bad gateway', 502)
            ->push('not-json', 200, ['Content-Type' => 'text/plain']);

        $provider = app(ImeiInfoDeviceIdentificationProvider::class);
        $failed = $provider->identify('490154203237518');
        $invalid = $provider->identify('356938035643809');

        $this->assertSame('unavailable', $failed->status);
        $this->assertSame('incomplete', $invalid->status);
        $this->assertNull($invalid->brand);
    }
}
