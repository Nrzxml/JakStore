<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\InventoryUnitResource;
use App\Models\DeviceModel;
use App\Models\InventoryImeiClaim;
use App\Rules\ValidImei;
use App\Services\DeviceIdentificationProvider;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceIdentificationController extends Controller
{
    public function __construct(
        private readonly DeviceIdentificationProvider $provider,
    ) {}

    public function identify(Request $request): JsonResponse
    {
        $data = $request->validate([
            'imei' => ['required', 'string', new ValidImei],
        ]);

        $claim = InventoryImeiClaim::query()
            ->with(['unit.variant.deviceModel.brand'])
            ->where('imei', $data['imei'])
            ->first();
        if ($claim !== null) {
            return response()->json([
                'data' => [
                    'status' => 'known_unit',
                    'source' => 'inventory',
                    'unit' => new InventoryUnitResource($claim->unit),
                ],
            ]);
        }

        $result = $this->provider->identify($data['imei']);
        $payload = $result->toArray();
        $device = $payload['device'];
        $payload['catalog_model'] = null;
        $payload['catalog_variants'] = [];

        if ($result->status === 'identified' && is_array($device)) {
            $catalogModel = DeviceModel::query()
                ->with('brand')
                ->where('is_active', true)
                ->whereHas('brand', fn ($brands) => $brands->where('is_active', true))
                ->get()
                ->first(fn (DeviceModel $model): bool => $this->normalize($model->brand->name) === $this->normalize($device['brand'])
                    && $this->normalize($model->name) === $this->normalize($device['model_name']));

            if ($catalogModel !== null) {
                $payload['catalog_model'] = [
                    'id' => $catalogModel->id,
                    'brand' => $catalogModel->brand->name,
                    'name' => $catalogModel->name,
                ];
                $payload['catalog_variants'] = $catalogModel->variants()
                    ->where('is_active', true)
                    ->orderBy('sku')
                    ->get(['id', 'color', 'storage', 'sku'])
                    ->values();
            }
        }

        return response()->json(['data' => $payload]);
    }

    private function normalize(string $value): string
    {
        return mb_strtolower((string) preg_replace('/[^a-z0-9]/i', '', $value));
    }
}
