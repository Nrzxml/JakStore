<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $variants = DB::table('product_variants')
            ->select(['id', 'device_model_id', 'color', 'ram', 'storage'])
            ->get();
        $updates = [];
        foreach ($variants as $variant) {
            if (
                $variant->ram === null
                && preg_match(
                    '/^\s*(\d+)\s*(?:GB)?\s*\/\s*(\d+)\s*GB\s*$/i',
                    $variant->storage,
                    $matches,
                ) === 1
            ) {
                $updates[$variant->id] = [
                    'device_model_id' => $variant->device_model_id,
                    'color' => $variant->color,
                    'ram' => $matches[1].' GB',
                    'storage' => $matches[2].' GB',
                ];
            }
        }

        $occupied = [];
        foreach ($variants as $variant) {
            $effective = $updates[$variant->id] ?? [
                'device_model_id' => $variant->device_model_id,
                'color' => $variant->color,
                'ram' => $variant->ram,
                'storage' => $variant->storage,
            ];
            if ($effective['ram'] === null) {
                continue;
            }

            $key = implode('|', [
                $effective['device_model_id'],
                mb_strtolower($effective['color']),
                mb_strtolower($effective['ram']),
                mb_strtolower($effective['storage']),
            ]);
            if (isset($occupied[$key])) {
                throw new RuntimeException(
                    'Cannot split existing RAM/storage values because a matching catalog variant already exists.',
                );
            }
            $occupied[$key] = true;
        }

        foreach ($updates as $id => $update) {
            DB::table('product_variants')
                ->where('id', $id)
                ->update([
                    'ram' => $update['ram'],
                    'storage' => $update['storage'],
                ]);
        }
    }

    public function down(): void
    {
        foreach (DB::table('product_variants')->whereNotNull('ram')->select(['id', 'ram', 'storage'])->get() as $variant) {
            DB::table('product_variants')
                ->where('id', $variant->id)
                ->update([
                    'ram' => null,
                    'storage' => $variant->ram.'/'.$variant->storage,
                ]);
        }
    }
};
