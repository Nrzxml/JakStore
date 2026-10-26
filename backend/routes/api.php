<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CatalogController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\DeviceIdentificationController;
use App\Http\Controllers\Api\InventoryController;
use App\Http\Controllers\Api\ReportsController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => response()->json(['data' => ['status' => 'ok']]));
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:5,1');

Route::middleware('auth:sanctum')->group(function (): void {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    Route::get('/dashboard', [DashboardController::class, 'show']);
    Route::get('/reports', [ReportsController::class, 'show']);

    Route::get('/brands', [CatalogController::class, 'brands']);
    Route::post('/brands', [CatalogController::class, 'storeBrand']);
    Route::patch('/brands/{brand}', [CatalogController::class, 'updateBrand'])
        ->whereNumber('brand');
    Route::get('/models', [CatalogController::class, 'models']);
    Route::post('/catalog/models', [CatalogController::class, 'storeCatalogModel']);
    Route::post('/models', [CatalogController::class, 'storeModel']);
    Route::get('/models/{model}', [CatalogController::class, 'showModel'])
        ->whereNumber('model');
    Route::patch('/models/{model}', [CatalogController::class, 'updateModel'])
        ->whereNumber('model');
    Route::get('/variants', [CatalogController::class, 'variants']);
    Route::post('/variants', [CatalogController::class, 'storeVariant']);
    Route::patch('/variants/{variant}', [CatalogController::class, 'updateVariant'])
        ->whereNumber('variant');

    Route::post('/inventory/identify', [DeviceIdentificationController::class, 'identify']);
    Route::get('/inventory', [InventoryController::class, 'index']);
    Route::post('/inventory', [InventoryController::class, 'store']);
    Route::post('/inventory/scan-outgoing', [InventoryController::class, 'scanOutgoing']);
    Route::get('/inventory/{inventory}', [InventoryController::class, 'show'])
        ->whereNumber('inventory');
    Route::match(['put', 'patch'], '/inventory/{inventory}', [InventoryController::class, 'update'])
        ->whereNumber('inventory');
    Route::patch('/inventory/{inventory}/status', [InventoryController::class, 'updateStatus'])
        ->whereNumber('inventory');
});
