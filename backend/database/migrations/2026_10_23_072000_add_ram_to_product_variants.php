<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('product_variants', 'ram')) {
            Schema::table('product_variants', function (Blueprint $table): void {
                $table->string('ram', 40)->nullable()->after('color');
            });
        }

        foreach (DB::table('product_variants')->select(['id', 'storage'])->get() as $variant) {
            if (preg_match('/^\s*(\d+)\s*(?:GB)?\s*\/\s*(\d+)\s*GB\s*$/i', $variant->storage, $matches) !== 1) {
                continue;
            }

            DB::table('product_variants')
                ->where('id', $variant->id)
                ->update([
                    'ram' => $matches[1].' GB',
                    'storage' => $matches[2].' GB',
                ]);
        }

        Schema::table('product_variants', function (Blueprint $table): void {
            if (! Schema::hasIndex('product_variants', 'product_variants_device_model_id_index')) {
                $table->index('device_model_id');
            }
            if (Schema::hasIndex(
                'product_variants',
                'product_variants_device_model_id_color_storage_unique',
            )) {
                $table->dropUnique('product_variants_device_model_id_color_storage_unique');
            }
            if (! Schema::hasIndex(
                'product_variants',
                'product_variants_device_model_id_color_ram_storage_unique',
            )) {
                $table->unique(['device_model_id', 'color', 'ram', 'storage']);
            }
        });
    }

    public function down(): void
    {
        Schema::table('product_variants', function (Blueprint $table): void {
            if (Schema::hasIndex(
                'product_variants',
                'product_variants_device_model_id_color_ram_storage_unique',
            )) {
                $table->dropUnique('product_variants_device_model_id_color_ram_storage_unique');
            }
        });

        foreach (DB::table('product_variants')->whereNotNull('ram')->select(['id', 'ram', 'storage'])->get() as $variant) {
            DB::table('product_variants')
                ->where('id', $variant->id)
                ->update(['storage' => $variant->ram.'/'.$variant->storage]);
        }

        if (Schema::hasColumn('product_variants', 'ram')) {
            Schema::table('product_variants', function (Blueprint $table): void {
                $table->dropColumn('ram');
            });
        }
        Schema::table('product_variants', function (Blueprint $table): void {
            if (! Schema::hasIndex(
                'product_variants',
                'product_variants_device_model_id_color_storage_unique',
            )) {
                $table->unique(['device_model_id', 'color', 'storage']);
            }
            if (Schema::hasIndex(
                'product_variants',
                'product_variants_device_model_id_index',
            )) {
                $table->dropIndex('product_variants_device_model_id_index');
            }
        });
    }
};
