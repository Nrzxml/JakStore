<?php

namespace App\Services;

final readonly class DeviceIdentificationResult
{
    public function __construct(
        public string $status,
        public string $message,
        public ?string $brand = null,
        public ?string $modelName = null,
        public ?string $modelCode = null,
        public ?string $tac = null,
        public ?string $source = null,
    ) {}

    public function toArray(): array
    {
        return [
            'status' => $this->status,
            'message' => $this->message,
            'device' => $this->brand !== null && $this->modelName !== null
                ? [
                    'brand' => $this->brand,
                    'model_name' => $this->modelName,
                    'model_code' => $this->modelCode,
                    'tac' => $this->tac,
                    'source' => $this->source,
                ]
                : null,
        ];
    }
}
