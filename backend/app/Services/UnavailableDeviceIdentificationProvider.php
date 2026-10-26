<?php

namespace App\Services;

class UnavailableDeviceIdentificationProvider implements DeviceIdentificationProvider
{
    public function identify(string $imei): DeviceIdentificationResult
    {
        return new DeviceIdentificationResult(
            status: 'not_configured',
            message: 'Lookup IMEI belum dikonfigurasi. Pilih model secara manual.',
        );
    }
}
