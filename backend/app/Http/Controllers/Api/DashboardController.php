<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\InventoryUnit;
use App\Models\ProductVariant;
use App\Models\StockMovement;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
    public function show(): JsonResponse
    {
        $today = now()->toDateString();
        $counts = InventoryUnit::query()
            ->selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');
        $movementsToday = StockMovement::query()
            ->whereDate('created_at', $today)
            ->selectRaw('type, COUNT(*) as total')
            ->groupBy('type')
            ->pluck('total', 'type');
        $lowStock = ProductVariant::query()
            ->withCount([
                'units as available_units_count' => fn ($units) => $units
                    ->where('status', 'available'),
            ])
            ->where('is_active', true)
            ->whereHas('deviceModel', fn ($models) => $models
                ->where('is_active', true)
                ->whereHas('brand', fn ($brands) => $brands->where('is_active', true)))
            ->with('deviceModel.brand')
            ->orderBy('available_units_count')
            ->get()
            ->filter(fn (ProductVariant $variant): bool => $variant->available_units_count <= 2)
            ->values();

        return response()->json([
            'data' => [
                'total_units' => InventoryUnit::query()->count(),
                'available_units' => (int) ($counts['available'] ?? 0),
                'sold_units' => (int) ($counts['sold'] ?? 0),
                'service_units' => (int) ($counts['service'] ?? 0),
                'damaged_units' => (int) ($counts['damaged'] ?? 0),
                'returned_units' => (int) ($counts['returned'] ?? 0),
                'incoming_today' => (int) ($movementsToday['incoming'] ?? 0),
                'outgoing_today' => (int) ($movementsToday['outgoing'] ?? 0),
                'low_stock_variants' => $lowStock->map(fn (ProductVariant $variant): array => [
                    'id' => $variant->id,
                    'sku' => $variant->sku,
                    'color' => $variant->color,
                    'ram' => $variant->ram,
                    'storage' => $variant->storage,
                    'available_units' => $variant->available_units_count,
                    'model' => [
                        'id' => $variant->deviceModel->id,
                        'brand' => $variant->deviceModel->brand->name,
                        'name' => $variant->deviceModel->name,
                    ],
                ])->values(),
                'recent_movements' => $this->recentMovements(),
            ],
        ]);
    }

    private function recentMovements(): array
    {
        return StockMovement::query()
            ->with(['unit.variant.deviceModel.brand'])
            ->latest()
            ->limit(4)
            ->get()
            ->map(fn (StockMovement $movement): array => [
                'id' => $movement->id,
                'imei' => $movement->imei,
                'type' => $movement->type,
                'from_status' => $movement->from_status,
                'to_status' => $movement->to_status,
                'created_at' => $movement->created_at?->toISOString(),
                'variant' => [
                    'id' => $movement->unit->variant->id,
                    'brand' => $movement->unit->variant->deviceModel->brand->name,
                    'model' => $movement->unit->variant->deviceModel->name,
                    'color' => $movement->unit->variant->color,
                    'storage' => $movement->unit->variant->storage,
                ],
            ])
            ->all();
    }
}
