<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StockMovementResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'inventory_unit_id' => $this->inventory_unit_id,
            'imei' => $this->imei,
            'type' => $this->type,
            'from_status' => $this->from_status,
            'to_status' => $this->to_status,
            'note' => $this->note,
            'recorded_by' => $this->recorded_by,
            'created_at' => $this->created_at?->toISOString(),
            'unit' => new InventoryUnitResource($this->whenLoaded('unit')),
        ];
    }
}
