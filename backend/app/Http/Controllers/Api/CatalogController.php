<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\BrandResource;
use App\Http\Resources\DeviceModelResource;
use App\Http\Resources\ProductVariantResource;
use App\Models\Brand;
use App\Models\DeviceModel;
use App\Models\ProductVariant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class CatalogController extends Controller
{
    public function brands(Request $request)
    {
        $query = Brand::query()->orderBy('name');
        if ($request->boolean('active_only', true)) {
            $query->where('is_active', true);
        }
        if (is_string($search = $request->query('q')) && $search !== '') {
            $query->where('name', 'like', '%'.mb_substr($search, 0, 100).'%');
        }

        return BrandResource::collection($query->get());
    }

    public function models(Request $request)
    {
        $query = DeviceModel::query()
            ->with('brand')
            ->withCount('units')
            ->withCount([
                'units as available_units_count' => fn ($units) => $units
                    ->where('status', 'available'),
            ])
            ->orderBy('name');
        if ($request->boolean('active_only', true)) {
            $query->where('is_active', true)
                ->whereHas('brand', fn ($brands) => $brands->where('is_active', true));
        }
        if ($request->filled('brand_id')) {
            $query->where('brand_id', $request->integer('brand_id'));
        }
        if (is_string($search = $request->query('q')) && $search !== '') {
            $term = '%'.mb_substr($search, 0, 100).'%';
            $query->where(fn ($models) => $models
                ->where('name', 'like', $term)
                ->orWhere('model_code', 'like', $term)
                ->orWhereHas('brand', fn ($brands) => $brands->where('name', 'like', $term)));
        }

        return DeviceModelResource::collection($query->get());
    }

    public function showModel(DeviceModel $model): DeviceModelResource
    {
        $model->load([
            'brand',
            'units.variant.deviceModel.brand',
            'units.movements' => fn ($movements) => $movements->latest(),
        ])->loadCount('units')->loadCount([
            'units as available_units_count' => fn ($units) => $units
                ->where('status', 'available'),
        ]);

        return new DeviceModelResource($model);
    }

    public function variants(Request $request)
    {
        $query = ProductVariant::query()
            ->with(['deviceModel.brand'])
            ->orderBy('sku');
        if ($request->boolean('active_only', true)) {
            $query->where('is_active', true)
                ->whereHas('deviceModel', fn ($models) => $models
                    ->where('is_active', true)
                    ->whereHas('brand', fn ($brands) => $brands->where('is_active', true)));
        }
        if ($request->filled('model_id')) {
            $query->where('device_model_id', $request->integer('model_id'));
        }
        if ($request->filled('brand_id')) {
            $query->whereHas('deviceModel', fn ($models) => $models->where('brand_id', $request->integer('brand_id')));
        }
        if (is_string($search = $request->query('q')) && $search !== '') {
            $term = '%'.mb_substr($search, 0, 100).'%';
            $query->where(fn ($variants) => $variants
                ->where('sku', 'like', $term)
                ->orWhere('color', 'like', $term)
                ->orWhere('ram', 'like', $term)
                ->orWhere('storage', 'like', $term)
                ->orWhereHas('deviceModel', fn ($models) => $models
                    ->where('name', 'like', $term)
                    ->orWhereHas('brand', fn ($brands) => $brands->where('name', 'like', $term))));
        }

        return ProductVariantResource::collection($query->get());
    }

    public function storeBrand(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100', Rule::unique('brands', 'name')],
        ]);
        $brand = Brand::query()->create($data);

        return (new BrandResource($brand))->response()->setStatusCode(201);
    }

    public function updateBrand(Request $request, Brand $brand): BrandResource
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:100', Rule::unique('brands', 'name')->ignore($brand->id)],
            'is_active' => ['sometimes', 'required', 'boolean'],
        ]);
        $brand->update($data);

        return new BrandResource($brand->refresh());
    }

    public function storeModel(Request $request): JsonResponse
    {
        $data = $request->validate([
            'brand_id' => ['required', 'integer', Rule::exists('brands', 'id')->where('is_active', true)],
            'name' => [
                'required',
                'string',
                'max:150',
                Rule::unique('device_models')->where('brand_id', $request->input('brand_id')),
            ],
            'model_code' => ['nullable', 'string', 'max:80'],
        ]);
        $model = DeviceModel::query()->create($data)->load('brand');

        return (new DeviceModelResource($model))->response()->setStatusCode(201);
    }

    public function storeCatalogModel(Request $request): JsonResponse
    {
        $data = $request->validate([
            'brand' => ['required', 'string', 'max:100'],
            'name' => ['required', 'string', 'max:150'],
            'model_code' => ['nullable', 'string', 'max:80'],
        ]);

        [$model, $created] = DB::transaction(function () use ($data): array {
            $brand = Brand::query()->firstOrCreate(
                ['name' => trim($data['brand'])],
                ['is_active' => true],
            );
            if (! $brand->is_active) {
                throw ValidationException::withMessages([
                    'brand' => ['The selected brand is inactive.'],
                ]);
            }

            $model = DeviceModel::query()->firstOrCreate(
                [
                    'brand_id' => $brand->id,
                    'name' => trim($data['name']),
                ],
                [
                    'model_code' => $data['model_code'] ?? null,
                    'is_active' => true,
                ],
            );
            if (! $model->is_active) {
                throw ValidationException::withMessages([
                    'name' => ['This catalog model is inactive.'],
                ]);
            }

            return [$model->load('brand'), $model->wasRecentlyCreated];
        });

        return (new DeviceModelResource($model))
            ->response()
            ->setStatusCode($created ? 201 : 200);
    }

    public function updateModel(Request $request, DeviceModel $model): DeviceModelResource
    {
        $data = $request->validate([
            'brand_id' => ['sometimes', 'required', 'integer', Rule::exists('brands', 'id')->where('is_active', true)],
            'name' => [
                'sometimes',
                'required',
                'string',
                'max:150',
                Rule::unique('device_models')
                    ->where('brand_id', $request->input('brand_id', $model->brand_id))
                    ->ignore($model->id),
            ],
            'model_code' => ['sometimes', 'nullable', 'string', 'max:80'],
            'is_active' => ['sometimes', 'required', 'boolean'],
        ]);
        $model->update($data);

        return new DeviceModelResource($model->refresh()->load('brand'));
    }

    public function storeVariant(Request $request): JsonResponse
    {
        $data = $request->validate([
            'device_model_id' => ['required', 'integer', Rule::exists('device_models', 'id')->where('is_active', true)],
            'color' => [
                'required',
                'string',
                'max:80',
                Rule::unique('product_variants', 'color')
                    ->where('device_model_id', $request->input('device_model_id'))
                    ->where('ram', $request->input('ram'))
                    ->where('storage', $request->input('storage')),
            ],
            'ram' => [
                'nullable',
                'string',
                'max:40',
                Rule::unique('product_variants', 'ram')
                    ->where('device_model_id', $request->input('device_model_id'))
                    ->where('color', $request->input('color'))
                    ->where('storage', $request->input('storage')),
            ],
            'storage' => [
                'required',
                'string',
                'max:40',
                Rule::unique('product_variants', 'storage')
                    ->where('device_model_id', $request->input('device_model_id'))
                    ->where('color', $request->input('color'))
                    ->where('ram', $request->input('ram')),
            ],
            'sku' => ['nullable', 'string', 'max:80', Rule::unique('product_variants', 'sku')],
        ]);
        $data['color'] = trim($data['color']);
        $data['ram'] = isset($data['ram']) ? trim($data['ram']) : null;
        $data['storage'] = trim($data['storage']);
        $data['sku'] = $this->uniqueSku($data['sku'] ?? null, $data);
        $variant = ProductVariant::query()->create($data)->load('deviceModel.brand');

        return (new ProductVariantResource($variant))->response()->setStatusCode(201);
    }

    public function updateVariant(Request $request, ProductVariant $variant): ProductVariantResource
    {
        $data = $request->validate([
            'device_model_id' => ['sometimes', 'required', 'integer', Rule::exists('device_models', 'id')->where('is_active', true)],
            'color' => [
                'sometimes',
                'required',
                'string',
                'max:80',
                Rule::unique('product_variants', 'color')
                    ->where('device_model_id', $request->input('device_model_id', $variant->device_model_id))
                    ->where('ram', $request->input('ram', $variant->ram))
                    ->where('storage', $request->input('storage', $variant->storage))
                    ->ignore($variant->id),
            ],
            'ram' => [
                'sometimes',
                'nullable',
                'string',
                'max:40',
                Rule::unique('product_variants', 'ram')
                    ->where('device_model_id', $request->input('device_model_id', $variant->device_model_id))
                    ->where('color', $request->input('color', $variant->color))
                    ->where('storage', $request->input('storage', $variant->storage))
                    ->ignore($variant->id),
            ],
            'storage' => [
                'sometimes',
                'required',
                'string',
                'max:40',
                Rule::unique('product_variants', 'storage')
                    ->where('device_model_id', $request->input('device_model_id', $variant->device_model_id))
                    ->where('color', $request->input('color', $variant->color))
                    ->where('ram', $request->input('ram', $variant->ram))
                    ->ignore($variant->id),
            ],
            'sku' => ['sometimes', 'required', 'string', 'max:80', Rule::unique('product_variants', 'sku')->ignore($variant->id)],
            'is_active' => ['sometimes', 'required', 'boolean'],
        ]);
        $variant->update($data);

        return new ProductVariantResource($variant->refresh()->load('deviceModel.brand'));
    }

    private function uniqueSku(?string $sku, array $data): string
    {
        if ($sku !== null && trim($sku) !== '') {
            return trim($sku);
        }

        $model = DeviceModel::query()->with('brand')->findOrFail($data['device_model_id']);
        $base = Str::upper(Str::slug(implode('-', array_filter([
            $model->brand->name,
            $model->name,
            $data['color'],
            $data['ram'] ?? null,
            $data['storage'],
        ]))));
        $base = Str::limit($base, 70, '');
        $sku = $base;
        $suffix = 2;
        while (ProductVariant::query()->where('sku', $sku)->exists()) {
            $sku = Str::limit($base, 70 - strlen((string) $suffix), '').'-'.$suffix++;
        }

        return $sku;
    }
}
