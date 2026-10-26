<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DeviceModelResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'brand_id' => $this->brand_id,
            'brand' => new BrandResource($this->whenLoaded('brand')),
            'name' => $this->name,
            'model_code' => $this->model_code,
            'is_active' => $this->is_active,
            'total_units' => $this->whenCounted('units'),
            'available_units' => $this->whenCounted('available_units'),
            'units' => InventoryUnitResource::collection($this->whenLoaded('units')),
        ];
    }
}
