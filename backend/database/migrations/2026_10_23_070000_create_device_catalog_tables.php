<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('brands', function (Blueprint $table): void {
            $table->id();
            $table->string('name', 100)->unique();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
        });

        Schema::create('device_models', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('brand_id')->constrained()->restrictOnDelete();
            $table->string('name', 150);
            $table->string('model_code', 80)->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
            $table->unique(['brand_id', 'name']);
            $table->index(['brand_id', 'model_code']);
        });

        Schema::create('product_variants', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('device_model_id')->constrained()->restrictOnDelete();
            $table->string('color', 80);
            $table->string('storage', 40);
            $table->string('sku', 80)->unique();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
            $table->unique(['device_model_id', 'color', 'storage']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_variants');
        Schema::dropIfExists('device_models');
        Schema::dropIfExists('brands');
    }
};
