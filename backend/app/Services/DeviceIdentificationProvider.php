<?php

namespace App\Services;

interface DeviceIdentificationProvider
{
    public function identify(string $imei): DeviceIdentificationResult;
}
