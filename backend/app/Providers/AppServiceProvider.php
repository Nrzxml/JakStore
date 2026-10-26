<?php

namespace App\Providers;

use App\Services\DeviceIdentificationProvider;
use App\Services\ImeiInfoDeviceIdentificationProvider;
use App\Services\UnavailableDeviceIdentificationProvider;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->bind(DeviceIdentificationProvider::class, function (): DeviceIdentificationProvider {
            return match (config('services.imei_info.provider')) {
                'imei_info' => $this->app->make(ImeiInfoDeviceIdentificationProvider::class),
                default => $this->app->make(UnavailableDeviceIdentificationProvider::class),
            };
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
