<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductVariantResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'device_model_id' => $this->device_model_id,
            'model' => new DeviceModelResource($this->whenLoaded('deviceModel')),
            'color' => $this->color,
            'ram' => $this->ram,
            'storage' => $this->storage,
            'sku' => $this->sku,
            'is_active' => $this->is_active,
        ];
    }
}
