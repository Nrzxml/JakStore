<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DeviceModel;
use App\Models\InventoryUnit;
use App\Models\ProductVariant;
use App\Models\StockMovement;
use Illuminate\Http\JsonResponse;

class ReportsController extends Controller
{
    public function show(): JsonResponse
    {
        $statusCounts = InventoryUnit::query()
            ->selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');
        $variants = ProductVariant::query()
            ->with(['deviceModel.brand'])
            ->withCount('units')
            ->withCount([
                'units as available_units_count' => fn ($units) => $units
                    ->where('status', 'available'),
                'units as sold_units_count' => fn ($units) => $units
                    ->where('status', 'sold'),
                'units as service_units_count' => fn ($units) => $units
                    ->where('status', 'service'),
                'units as damaged_units_count' => fn ($units) => $units
                    ->where('status', 'damaged'),
                'units as returned_units_count' => fn ($units) => $units
                    ->where('status', 'returned'),
            ])
            ->orderBy('sku')
            ->get()
            ->map(fn (ProductVariant $variant): array => [
                'id' => $variant->id,
                'sku' => $variant->sku,
                'color' => $variant->color,
                'ram' => $variant->ram,
                'storage' => $variant->storage,
                'total_units' => $variant->units_count,
                'available_units' => $variant->available_units_count,
                'sold_units' => $variant->sold_units_count,
                'service_units' => $variant->service_units_count,
                'damaged_units' => $variant->damaged_units_count,
                'returned_units' => $variant->returned_units_count,
                'model' => [
                    'id' => $variant->deviceModel->id,
                    'brand' => $variant->deviceModel->brand->name,
                    'name' => $variant->deviceModel->name,
                ],
            ]);

        $models = DeviceModel::query()
            ->with('brand')
            ->withCount('units')
            ->withCount([
                'units as available_units_count' => fn ($units) => $units
                    ->where('status', 'available'),
                'units as sold_units_count' => fn ($units) => $units
                    ->where('status', 'sold'),
                'units as service_units_count' => fn ($units) => $units
                    ->where('status', 'service'),
                'units as damaged_units_count' => fn ($units) => $units
                    ->where('status', 'damaged'),
                'units as returned_units_count' => fn ($units) => $units
                    ->where('status', 'returned'),
            ])
            ->orderBy('name')
            ->get()
            ->map(fn (DeviceModel $model): array => [
                'id' => $model->id,
                'brand' => $model->brand->name,
                'name' => $model->name,
                'total_units' => $model->units_count,
                'available_units' => $model->available_units_count,
                'sold_units' => $model->sold_units_count,
                'service_units' => $model->service_units_count,
                'damaged_units' => $model->damaged_units_count,
                'returned_units' => $model->returned_units_count,
            ]);

        return response()->json([
            'data' => [
                'total_units' => InventoryUnit::query()->count(),
                'by_status' => [
                    'available' => (int) ($statusCounts['available'] ?? 0),
                    'sold' => (int) ($statusCounts['sold'] ?? 0),
                    'service' => (int) ($statusCounts['service'] ?? 0),
                    'damaged' => (int) ($statusCounts['damaged'] ?? 0),
                    'returned' => (int) ($statusCounts['returned'] ?? 0),
                ],
                'by_variant' => $variants->values(),
                'by_model' => $models->values(),
                'recent_movements' => StockMovement::query()
                    ->with(['unit.variant.deviceModel.brand'])
                    ->latest()
                    ->limit(50)
                    ->get()
                    ->map(fn (StockMovement $movement): array => [
                        'id' => $movement->id,
                        'inventory_unit_id' => $movement->inventory_unit_id,
                        'imei' => $movement->imei,
                        'type' => $movement->type,
                        'from_status' => $movement->from_status,
                        'to_status' => $movement->to_status,
                        'note' => $movement->note,
                        'created_at' => $movement->created_at?->toISOString(),
                        'variant_name' => $movement->unit->variant->deviceModel->brand->name
                            .' '.$movement->unit->variant->deviceModel->name,
                    ])
                    ->all(),
            ],
        ]);
    }
}
