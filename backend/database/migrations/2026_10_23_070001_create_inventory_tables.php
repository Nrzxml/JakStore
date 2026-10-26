<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventory_units', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('product_variant_id')->constrained()->restrictOnDelete();
            $table->char('imei1', 15)->unique();
            $table->char('imei2', 15)->nullable()->unique();
            $table->string('status', 20)->default('available')->index();
            $table->timestamp('recorded_at')->useCurrent();
            $table->timestamps();
        });

        Schema::create('inventory_imei_claims', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('inventory_unit_id')
                ->constrained('inventory_units')
                ->cascadeOnDelete();
            $table->char('imei', 15)->unique();
            $table->string('slot', 5);
            $table->timestamps();
            $table->unique(['inventory_unit_id', 'slot']);
        });

        Schema::create('stock_movements', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('inventory_unit_id')
                ->constrained('inventory_units')
                ->restrictOnDelete();
            $table->char('imei', 15);
            $table->string('type', 20)->index();
            $table->string('from_status', 20)->nullable();
            $table->string('to_status', 20)->nullable();
            $table->foreignId('recorded_by')->nullable()
                ->constrained('users')
                ->nullOnDelete();
            $table->string('note', 500)->nullable();
            $table->timestamps();
            $table->index(['created_at', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_movements');
        Schema::dropIfExists('inventory_imei_claims');
        Schema::dropIfExists('inventory_units');
    }
};
