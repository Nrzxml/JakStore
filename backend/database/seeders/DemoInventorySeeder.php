<?php

namespace Database\Seeders;

use App\Models\Brand;
use App\Models\DeviceModel;
use App\Models\InventoryImeiClaim;
use App\Models\InventoryUnit;
use App\Models\ProductVariant;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DemoInventorySeeder extends Seeder
{
    private const TARGET_UNITS_PER_MODEL = 10;

    public function run(): void
    {
        DB::transaction(function (): void {
            foreach ($this->demoModels() as $demoModel) {
                $brand = Brand::query()->firstOrCreate(
                    ['name' => $demoModel['brand']],
                    ['is_active' => true],
                );
                $model = DeviceModel::query()->firstOrCreate(
                    [
                        'brand_id' => $brand->id,
                        'name' => $demoModel['name'],
                    ],
                    [
                        'model_code' => $demoModel['model_code'],
                        'is_active' => true,
                    ],
                );

                $variants = [];
                foreach ($demoModel['variants'] as $variantData) {
                    $variant = ProductVariant::query()->firstOrCreate(
                        [
                            'device_model_id' => $model->id,
                            'color' => $variantData['color'],
                            'ram' => $variantData['ram'],
                            'storage' => $variantData['storage'],
                        ],
                        [
                            'sku' => $variantData['sku'],
                            'is_active' => true,
                        ],
                    );
                    $variants[] = $variant;
                }

                $unitCount = InventoryUnit::query()
                    ->whereHas('variant', fn ($query) => $query
                        ->where('device_model_id', $model->id))
                    ->count();
                $sequence = 1;

                while ($unitCount < self::TARGET_UNITS_PER_MODEL) {
                    $imei = $this->demoImei($demoModel['imei_group'], $sequence++);
                    if (InventoryImeiClaim::query()->where('imei', $imei)->exists()) {
                        continue;
                    }

                    $variant = $variants[($unitCount) % count($variants)];
                    $unit = InventoryUnit::query()->create([
                        'product_variant_id' => $variant->id,
                        'imei1' => $imei,
                        'status' => 'available',
                        'recorded_at' => now()->subDays($unitCount % 30),
                    ]);
                    $unit->imeiClaims()->create([
                        'imei' => $imei,
                        'slot' => 'imei1',
                    ]);
                    $unit->movements()->create([
                        'imei' => $imei,
                        'type' => 'incoming',
                        'to_status' => 'available',
                        'note' => 'Data demo untuk menguji pengelompokan inventori.',
                    ]);
                    $unitCount++;
                }
            }
        });

        $this->command?->info(
            'Demo inventory is ready: at least 10 units for each of 3 phone models.',
        );
    }

    private function demoModels(): array
    {
        return [
            [
                'brand' => 'Xiaomi',
                'name' => 'Redmi Note 14 5G',
                'model_code' => 'DEMO-RN14-5G',
                'imei_group' => '01',
                'variants' => [
                    [
                        'color' => 'Hitam',
                        'ram' => '8 GB',
                        'storage' => '256 GB',
                        'sku' => 'DEMO-RN14-8-256-BLK',
                    ],
                    [
                        'color' => 'Biru',
                        'ram' => '8 GB',
                        'storage' => '256 GB',
                        'sku' => 'DEMO-RN14-8-256-BLU',
                    ],
                    [
                        'color' => 'Ungu',
                        'ram' => '12 GB',
                        'storage' => '512 GB',
                        'sku' => 'DEMO-RN14-12-512-PUR',
                    ],
                ],
            ],
            [
                'brand' => 'Samsung',
                'name' => 'Galaxy A55 5G',
                'model_code' => 'DEMO-GA55-5G',
                'imei_group' => '02',
                'variants' => [
                    [
                        'color' => 'Awesome Navy',
                        'ram' => '8 GB',
                        'storage' => '128 GB',
                        'sku' => 'DEMO-GA55-8-128-NAV',
                    ],
                    [
                        'color' => 'Awesome Iceblue',
                        'ram' => '8 GB',
                        'storage' => '256 GB',
                        'sku' => 'DEMO-GA55-8-256-ICE',
                    ],
                    [
                        'color' => 'Awesome Lilac',
                        'ram' => '12 GB',
                        'storage' => '256 GB',
                        'sku' => 'DEMO-GA55-12-256-LIL',
                    ],
                ],
            ],
            [
                'brand' => 'Apple',
                'name' => 'iPhone 15 Pro Max',
                'model_code' => 'DEMO-IP15PM',
                'imei_group' => '03',
                'variants' => [
                    [
                        'color' => 'Titanium Hitam',
                        'ram' => null,
                        'storage' => '256 GB',
                        'sku' => 'DEMO-IP15PM-256-BLK',
                    ],
                    [
                        'color' => 'Titanium Natural',
                        'ram' => null,
                        'storage' => '512 GB',
                        'sku' => 'DEMO-IP15PM-512-NAT',
                    ],
                    [
                        'color' => 'Titanium Biru',
                        'ram' => null,
                        'storage' => '1 TB',
                        'sku' => 'DEMO-IP15PM-1TB-BLU',
                    ],
                ],
            ],
        ];
    }

    private function demoImei(string $group, int $sequence): string
    {
        $body = '990000'.$group.str_pad((string) $sequence, 6, '0', STR_PAD_LEFT);
        $sum = 0;

        for ($index = 0; $index < strlen($body); $index++) {
            $digit = (int) $body[$index];
            if ($index % 2 === 1) {
                $digit *= 2;
                if ($digit > 9) {
                    $digit -= 9;
                }
            }
            $sum += $digit;
        }

        return $body.(string) ((10 - ($sum % 10)) % 10);
    }
}
