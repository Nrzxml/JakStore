<?php

namespace Tests\Feature;

use App\Models\Brand;
use App\Models\DeviceModel;
use App\Models\InventoryImeiClaim;
use App\Models\InventoryUnit;
use App\Models\ProductVariant;
use App\Models\User;
use App\Services\DeviceIdentificationProvider;
use App\Services\DeviceIdentificationResult;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Mockery;
use Tests\TestCase;

class ApiInventoryTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private ProductVariant $variant;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::factory()->create([
            'email' => 'admin@jakstore.test',
            'password' => Hash::make('correct-password'),
            'is_admin' => true,
        ]);
        $brand = Brand::query()->create(['name' => 'Apple']);
        $model = DeviceModel::query()->create([
            'brand_id' => $brand->id,
            'name' => 'iPhone 15 Pro Max',
            'model_code' => 'A3108',
        ]);
        $this->variant = ProductVariant::query()->create([
            'device_model_id' => $model->id,
            'color' => 'Natural Titanium',
            'ram' => '8 GB',
            'storage' => '256 GB',
            'sku' => 'APL-IP15PM-256',
        ]);
    }

    public function test_health_is_public_and_reveals_only_status(): void
    {
        $this->getJson('/api/health')
            ->assertOk()
            ->assertExactJson(['data' => ['status' => 'ok']]);
    }

    public function test_inventory_and_dashboard_require_admin_token(): void
    {
        $this->getJson('/api/inventory')->assertUnauthorized();
        $this->getJson('/api/dashboard')->assertUnauthorized();
        $this->getJson('/api/reports')->assertUnauthorized();
        $this->getJson('/api/brands')->assertUnauthorized();
    }

    public function test_admin_login_issues_a_bounded_token_and_logout_revokes_it(): void
    {
        $login = $this->postJson('/api/login', [
            'email' => 'ADMIN@JAKSTORE.TEST',
            'password' => 'correct-password',
            'device_name' => 'test-phone',
        ])->assertOk()->assertJsonPath('data.user.email', 'admin@jakstore.test');
        $token = $login->json('data.token');
        $this->assertNotEmpty($token);

        $this->withToken($token)->getJson('/api/me')->assertOk();
        $this->withToken($token)->postJson('/api/logout')->assertOk();
        $this->assertDatabaseCount('personal_access_tokens', 0);
        Auth::forgetGuards();
        $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
    }

    public function test_login_rejects_wrong_password_and_non_admin_users(): void
    {
        $this->postJson('/api/login', [
            'email' => 'admin@jakstore.test',
            'password' => 'wrong-password',
        ])->assertUnprocessable();

        $user = User::factory()->create(['is_admin' => false]);
        $this->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'password',
        ])->assertUnprocessable();
    }

    public function test_create_inventory_stores_one_unit_and_two_unique_imei_claims(): void
    {
        $response = $this->asAdmin()->postJson('/api/inventory', [
            'product_variant_id' => $this->variant->id,
            'imei1' => '490154203237518',
            'imei2' => '490154203237542',
            'status' => 'available',
        ])->assertCreated()
            ->assertJsonPath('data.imei1', '490154203237518')
            ->assertJsonPath('data.imei2', '490154203237542');

        $unitId = $response->json('data.id');
        $this->assertSame(1, InventoryUnit::query()->count());
        $this->assertSame(2, InventoryImeiClaim::query()->count());
        $this->assertSame(1, $this->asAdmin()->getJson('/api/inventory')
            ->assertOk()->json('meta.total'));
        $this->assertSame(1, $this->asAdmin()->getJson('/api/dashboard')
            ->assertOk()->json('data.total_units'));
        $this->assertDatabaseHas('inventory_units', ['id' => $unitId]);
    }

    public function test_model_catalog_counts_physical_units_and_returns_unit_details(): void
    {
        $unit = $this->createUnit('490154203237518', '490154203237542');

        $this->asAdmin()->getJson('/api/models')
            ->assertOk()
            ->assertJsonPath('data.0.total_units', 1)
            ->assertJsonPath('data.0.available_units', 1);

        $this->asAdmin()->getJson("/api/models/{$this->variant->device_model_id}")
            ->assertOk()
            ->assertJsonPath('data.total_units', 1)
            ->assertJsonPath('data.units.0.id', $unit->id)
            ->assertJsonPath('data.units.0.imei2', '490154203237542')
            ->assertJsonPath('data.units.0.variant.ram', '8 GB')
            ->assertJsonPath('data.units.0.variant.storage', '256 GB');

        $this->assertSame(1, InventoryUnit::query()->count());
        $this->assertSame(2, InventoryImeiClaim::query()->count());
    }

    public function test_catalog_model_creation_reuses_model_without_variant_attributes_in_its_name(): void
    {
        $payload = [
            'brand' => 'Xiaomi',
            'name' => 'Redmi Note 14 5G',
        ];

        $created = $this->asAdmin()->postJson('/api/catalog/models', $payload)
            ->assertCreated()
            ->assertJsonPath('data.name', 'Redmi Note 14 5G')
            ->assertJsonPath('data.brand.name', 'Xiaomi');
        $reused = $this->asAdmin()->postJson('/api/catalog/models', $payload)
            ->assertOk()
            ->assertJsonPath('data.id', $created->json('data.id'));

        $this->assertSame(1, DeviceModel::query()
            ->where('name', 'Redmi Note 14 5G')
            ->count());
    }

    public function test_variant_stores_ram_and_storage_separately_and_generates_sku(): void
    {
        $response = $this->asAdmin()->postJson('/api/variants', [
            'device_model_id' => $this->variant->device_model_id,
            'color' => 'Blue',
            'ram' => '12 GB',
            'storage' => '512 GB',
        ])->assertCreated()
            ->assertJsonPath('data.ram', '12 GB')
            ->assertJsonPath('data.storage', '512 GB');

        $this->assertNotEmpty($response->json('data.sku'));
        $this->assertDatabaseHas('product_variants', [
            'id' => $response->json('data.id'),
            'ram' => '12 GB',
            'storage' => '512 GB',
        ]);
    }

    public function test_duplicate_model_color_memory_variant_is_rejected(): void
    {
        $this->asAdmin()->postJson('/api/variants', [
            'device_model_id' => $this->variant->device_model_id,
            'color' => 'Natural Titanium',
            'ram' => '8 GB',
            'storage' => '256 GB',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('color');

        $this->assertSame(1, ProductVariant::query()->count());
    }

    public function test_duplicate_imei_is_rejected_across_both_slots(): void
    {
        $this->createUnit('490154203237518', '356938035643809');
        $this->asAdmin()->postJson('/api/inventory', [
            'product_variant_id' => $this->variant->id,
            'imei1' => '490154203237542',
            'imei2' => '490154203237518',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('imei2');

        $this->asAdmin()->postJson('/api/inventory', [
            'product_variant_id' => $this->variant->id,
            'imei1' => '356938035643809',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('imei1');
        $this->assertSame(1, InventoryUnit::query()->count());
    }

    public function test_equal_or_invalid_imeis_are_rejected(): void
    {
        $this->asAdmin()->postJson('/api/inventory', [
            'product_variant_id' => $this->variant->id,
            'imei1' => '490154203237518',
            'imei2' => '490154203237518',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('imei2');

        $this->asAdmin()->postJson('/api/inventory', [
            'product_variant_id' => $this->variant->id,
            'imei1' => '490154203237519',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('imei1');
        $this->assertSame(0, InventoryUnit::query()->count());
    }

    public function test_local_imei_lookup_does_not_call_external_provider(): void
    {
        $unit = $this->createUnit('490154203237518', '356938035643809');
        $provider = Mockery::mock(DeviceIdentificationProvider::class);
        $provider->shouldNotReceive('identify');
        $this->app->instance(DeviceIdentificationProvider::class, $provider);

        $this->asAdmin()->postJson('/api/inventory/identify', [
            'imei' => '356938035643809',
        ])->assertOk()
            ->assertJsonPath('data.status', 'known_unit')
            ->assertJsonPath('data.unit.id', $unit->id);
    }

    public function test_external_lookup_result_is_matched_to_catalog_without_creating_models(): void
    {
        $provider = Mockery::mock(DeviceIdentificationProvider::class);
        $provider->shouldReceive('identify')->once()->with('490154203237542')
            ->andReturn(new DeviceIdentificationResult(
                status: 'identified',
                message: 'Found',
                brand: 'Apple',
                modelName: 'iPhone 15 Pro Max',
                modelCode: 'A3108',
                source: 'Fake provider',
            ));
        $this->app->instance(DeviceIdentificationProvider::class, $provider);

        $this->asAdmin()->postJson('/api/inventory/identify', [
            'imei' => '490154203237542',
        ])->assertOk()
            ->assertJsonPath('data.status', 'identified')
            ->assertJsonPath('data.catalog_model.id', $this->variant->device_model_id)
            ->assertJsonPath('data.catalog_variants.0.id', $this->variant->id);

        $this->assertSame(1, DeviceModel::query()->count());
        $this->assertSame(0, InventoryUnit::query()->count());
    }

    public function test_lookup_provider_failure_returns_manual_fallback_state(): void
    {
        $provider = Mockery::mock(DeviceIdentificationProvider::class);
        $provider->shouldReceive('identify')->once()
            ->andReturn(new DeviceIdentificationResult(
                status: 'unavailable',
                message: 'Provider unavailable',
            ));
        $this->app->instance(DeviceIdentificationProvider::class, $provider);

        $this->asAdmin()->postJson('/api/inventory/identify', [
            'imei' => '490154203237542',
        ])->assertOk()
            ->assertJsonPath('data.status', 'unavailable')
            ->assertJsonPath('data.device', null);
    }

    public function test_outgoing_and_status_change_keep_physical_stock_aggregates_consistent(): void
    {
        $unit = $this->createUnit('490154203237518', '356938035643809');
        $this->asAdmin()->patchJson("/api/inventory/{$unit->id}/status", [
            'status' => 'service',
        ])->assertOk();
        $this->asAdmin()->getJson('/api/dashboard')
            ->assertOk()
            ->assertJsonPath('data.total_units', 1)
            ->assertJsonPath('data.service_units', 1)
            ->assertJsonPath('data.available_units', 0);

        $this->asAdmin()->patchJson("/api/inventory/{$unit->id}/status", [
            'status' => 'sold',
        ])->assertUnprocessable();
        $this->asAdmin()->postJson('/api/inventory/scan-outgoing', [
            'imei' => '356938035643809',
        ])->assertUnprocessable();
        $this->assertSame(1, InventoryUnit::query()->count());
    }

    public function test_available_unit_can_be_sold_by_either_registered_imei(): void
    {
        $this->createUnit('490154203237518', '356938035643809');
        $this->asAdmin()->postJson('/api/inventory/scan-outgoing', [
            'imei' => '356938035643809',
        ])->assertOk()
            ->assertJsonPath('data.status', 'sold');

        $this->asAdmin()->getJson('/api/reports')
            ->assertOk()
            ->assertJsonPath('data.total_units', 1)
            ->assertJsonPath('data.by_status.sold', 1)
            ->assertJsonPath('data.by_variant.0.total_units', 1)
            ->assertJsonPath('data.by_model.0.total_units', 1)
            ->assertJsonPath('data.by_model.0.sold_units', 1);
    }

    public function test_update_imei2_rejects_a_claim_owned_by_another_unit(): void
    {
        $first = $this->createUnit('490154203237518', '490154203237542');
        $second = $this->createUnit('356938035643809');

        $this->asAdmin()->patchJson("/api/inventory/{$second->id}", [
            'imei2' => '490154203237542',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('imei2');
        $this->assertSame(2, InventoryUnit::query()->count());
    }

    public function test_catalog_can_be_created_and_deactivated_without_deleting_units(): void
    {
        $this->createUnit('490154203237518');
        $this->asAdmin()->patchJson("/api/variants/{$this->variant->id}", [
            'is_active' => false,
        ])->assertOk()->assertJsonPath('data.is_active', false);

        $this->asAdmin()->getJson('/api/variants')
            ->assertOk()
            ->assertJsonCount(0, 'data');
        $this->assertSame(1, InventoryUnit::query()->count());
    }

    private function asAdmin(): static
    {
        return $this->actingAs($this->admin, 'sanctum');
    }

    private function createUnit(string $imei1, ?string $imei2 = null): InventoryUnit
    {
        $unit = InventoryUnit::query()->create([
            'product_variant_id' => $this->variant->id,
            'imei1' => $imei1,
            'imei2' => $imei2,
            'status' => 'available',
            'recorded_at' => now(),
        ]);
        $unit->imeiClaims()->create(['imei' => $imei1, 'slot' => 'imei1']);
        if ($imei2 !== null) {
            $unit->imeiClaims()->create(['imei' => $imei2, 'slot' => 'imei2']);
        }

        return $unit;
    }
}
