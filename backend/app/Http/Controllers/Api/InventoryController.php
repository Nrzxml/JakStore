<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreInventoryRequest;
use App\Http\Requests\UpdateInventoryRequest;
use App\Http\Requests\UpdateInventoryStatusRequest;
use App\Http\Resources\InventoryUnitResource;
use App\Models\InventoryImeiClaim;
use App\Models\InventoryUnit;
use App\Models\StockMovement;
use App\Rules\ValidImei;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class InventoryController extends Controller
{
    public function index(Request $request)
    {
        $query = InventoryUnit::query()
            ->with(['variant.deviceModel.brand'])
            ->latest('recorded_at');

        if ($request->filled('status')) {
            $request->validate(['status' => ['string', 'in:available,sold,service,damaged,returned']]);
            $query->where('status', $request->query('status'));
        }
        if ($request->filled('variant_id')) {
            $request->validate(['variant_id' => ['integer', 'min:1']]);
            $query->where('product_variant_id', $request->integer('variant_id'));
        }
        if ($request->filled('model_id')) {
            $request->validate(['model_id' => ['integer', 'min:1']]);
            $query->whereHas('variant', fn ($variants) => $variants
                ->where('device_model_id', $request->integer('model_id')));
        }
        if (is_string($search = $request->query('q')) && trim($search) !== '') {
            $term = '%'.str_replace(['%', '_'], ['\\%', '\\_'], mb_substr(trim($search), 0, 100)).'%';
            $query->where(function ($units) use ($term): void {
                $units->where('imei1', 'like', $term)
                    ->orWhere('imei2', 'like', $term)
                    ->orWhereHas('variant', fn ($variants) => $variants
                        ->where('sku', 'like', $term)
                        ->orWhere('color', 'like', $term)
                        ->orWhere('storage', 'like', $term)
                        ->orWhereHas('deviceModel', fn ($models) => $models
                            ->where('name', 'like', $term)
                            ->orWhereHas('brand', fn ($brands) => $brands->where('name', 'like', $term))));
            });
        }

        $perPage = min(100, max(1, $request->integer('per_page', 25)));

        return InventoryUnitResource::collection($query->paginate($perPage));
    }

    public function store(StoreInventoryRequest $request): JsonResponse
    {
        $data = $request->validated();
        try {
            $unit = DB::transaction(function () use ($data, $request): InventoryUnit {
                $unit = InventoryUnit::query()->create([
                    'product_variant_id' => $data['product_variant_id'],
                    'imei1' => $data['imei1'],
                    'imei2' => $data['imei2'] ?? null,
                    'status' => $data['status'] ?? 'available',
                    'recorded_at' => now(),
                ]);

                $unit->imeiClaims()->create([
                    'imei' => $unit->imei1,
                    'slot' => 'imei1',
                ]);
                if ($unit->imei2 !== null) {
                    $unit->imeiClaims()->create([
                        'imei' => $unit->imei2,
                        'slot' => 'imei2',
                    ]);
                }

                StockMovement::query()->create([
                    'inventory_unit_id' => $unit->id,
                    'imei' => $unit->imei1,
                    'type' => 'incoming',
                    'to_status' => $unit->status,
                    'recorded_by' => $request->user()->id,
                    'note' => $data['note'] ?? null,
                ]);

                return $unit;
            });
        } catch (QueryException $exception) {
            if ($this->isDuplicateImei($exception)) {
                throw ValidationException::withMessages([
                    'imei1' => ['One of these IMEIs is already assigned to another unit.'],
                ]);
            }
            throw $exception;
        }

        return (new InventoryUnitResource(
            $unit->load(['variant.deviceModel.brand']),
        ))->response()->setStatusCode(201);
    }

    public function show(InventoryUnit $inventory): InventoryUnitResource
    {
        return new InventoryUnitResource(
            $inventory->load([
                'variant.deviceModel.brand',
                'movements' => fn ($movements) => $movements->latest(),
            ]),
        );
    }

    public function update(UpdateInventoryRequest $request, InventoryUnit $inventory): InventoryUnitResource
    {
        $data = $request->validated();
        try {
            $unit = DB::transaction(function () use ($data, $inventory): InventoryUnit {
                $unit = InventoryUnit::query()->lockForUpdate()->findOrFail($inventory->id);
                if (array_key_exists('product_variant_id', $data)) {
                    $unit->product_variant_id = $data['product_variant_id'];
                }
                if (array_key_exists('imei1', $data)) {
                    $unit->imei1 = $data['imei1'];
                }
                if (array_key_exists('imei2', $data)) {
                    $unit->imei2 = $data['imei2'] ?: null;
                }
                $unit->save();

                $unit->imeiClaims()->delete();
                $unit->imeiClaims()->create([
                    'imei' => $unit->imei1,
                    'slot' => 'imei1',
                ]);
                if ($unit->imei2 !== null) {
                    $unit->imeiClaims()->create([
                        'imei' => $unit->imei2,
                        'slot' => 'imei2',
                    ]);
                }

                return $unit;
            });
        } catch (QueryException $exception) {
            if ($this->isDuplicateImei($exception)) {
                throw ValidationException::withMessages([
                    array_key_exists('imei1', $data) ? 'imei1' : 'imei2' => ['This IMEI is already assigned to another unit.'],
                ]);
            }
            throw $exception;
        }

        return new InventoryUnitResource($unit->load('variant.deviceModel.brand'));
    }

    public function updateStatus(
        UpdateInventoryStatusRequest $request,
        InventoryUnit $inventory,
    ): InventoryUnitResource {
        $data = $request->validated();
        $unit = DB::transaction(function () use ($data, $inventory, $request): InventoryUnit {
            $unit = InventoryUnit::query()->lockForUpdate()->findOrFail($inventory->id);
            if ($unit->status === 'sold') {
                throw ValidationException::withMessages([
                    'status' => ['A sold unit cannot be changed through this endpoint.'],
                ]);
            }
            if ($unit->status === $data['status']) {
                return $unit;
            }

            $previous = $unit->status;
            $unit->status = $data['status'];
            $unit->save();
            StockMovement::query()->create([
                'inventory_unit_id' => $unit->id,
                'imei' => $unit->imei1,
                'type' => 'statusChanged',
                'from_status' => $previous,
                'to_status' => $unit->status,
                'recorded_by' => $request->user()->id,
                'note' => $data['note'] ?? null,
            ]);

            return $unit;
        });

        return new InventoryUnitResource($unit->load('variant.deviceModel.brand'));
    }

    public function scanOutgoing(Request $request): InventoryUnitResource
    {
        $data = $request->validate([
            'imei' => ['required', 'string', new ValidImei],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $unit = DB::transaction(function () use ($data, $request): InventoryUnit {
            $claim = InventoryImeiClaim::query()
                ->where('imei', $data['imei'])
                ->lockForUpdate()
                ->first();
            if ($claim === null) {
                throw ValidationException::withMessages([
                    'imei' => ['IMEI was not found in inventory.'],
                ]);
            }
            $unit = InventoryUnit::query()->lockForUpdate()->findOrFail($claim->inventory_unit_id);
            if ($unit->status !== 'available') {
                throw ValidationException::withMessages([
                    'imei' => ['This unit is not available for outgoing stock.'],
                ]);
            }

            $unit->status = 'sold';
            $unit->save();
            StockMovement::query()->create([
                'inventory_unit_id' => $unit->id,
                'imei' => $data['imei'],
                'type' => 'outgoing',
                'from_status' => 'available',
                'to_status' => 'sold',
                'recorded_by' => $request->user()->id,
                'note' => $data['note'] ?? null,
            ]);

            return $unit;
        });

        return new InventoryUnitResource($unit->load('variant.deviceModel.brand'));
    }

    private function isDuplicateImei(QueryException $exception): bool
    {
        $message = strtolower($exception->getMessage());

        return str_contains($message, 'imei')
            && (str_contains($message, 'unique') || str_contains($message, 'duplicate'));
    }
}
