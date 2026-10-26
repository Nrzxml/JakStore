<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InventoryUnitResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'product_variant_id' => $this->product_variant_id,
            'variant' => new ProductVariantResource($this->whenLoaded('variant')),
            'imei1' => $this->imei1,
            'imei2' => $this->imei2,
            'status' => $this->status,
            'recorded_at' => $this->recorded_at?->toISOString(),
            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
            'movements' => StockMovementResource::collection(
                $this->whenLoaded('movements'),
            ),
        ];
    }
}
