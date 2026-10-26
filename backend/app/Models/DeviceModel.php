<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasManyThrough;

class DeviceModel extends Model
{
    use HasFactory;

    protected $fillable = ['brand_id', 'name', 'model_code', 'is_active'];

    protected function casts(): array
    {
        return ['is_active' => 'boolean'];
    }

    public function brand(): BelongsTo
    {
        return $this->belongsTo(Brand::class);
    }

    public function variants(): HasMany
    {
        return $this->hasMany(ProductVariant::class);
    }

    public function units(): HasManyThrough
    {
        return $this->hasManyThrough(
            InventoryUnit::class,
            ProductVariant::class,
            'device_model_id',
            'product_variant_id',
        );
    }
}
