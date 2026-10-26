<?php

namespace App\Http\Requests;

use App\Models\InventoryImeiClaim;
use App\Models\InventoryUnit;
use App\Rules\ValidImei;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class UpdateInventoryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'product_variant_id' => [
                'sometimes',
                'required',
                'integer',
                Rule::exists('product_variants', 'id')->where('is_active', true),
            ],
            'imei1' => ['sometimes', 'required', 'string', new ValidImei],
            'imei2' => ['sometimes', 'nullable', 'string', new ValidImei],
            'note' => ['nullable', 'string', 'max:500'],
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator): void {
                $unit = $this->route('inventory');
                if (! $unit instanceof InventoryUnit) {
                    return;
                }
                $imei1 = $this->input('imei1', $unit->imei1);
                $imei2 = $this->input('imei2', $unit->imei2);
                if (
                    is_string($imei1)
                    && is_string($imei2)
                    && $imei2 !== ''
                    && $imei1 === $imei2
                ) {
                    $validator->errors()->add(
                        'imei2',
                        'IMEI 1 and IMEI 2 must be different.',
                    );
                }
                foreach (['imei1' => $imei1, 'imei2' => $imei2] as $field => $imei) {
                    if (! is_string($imei) || $imei === '') {
                        continue;
                    }
                    $duplicate = InventoryImeiClaim::query()
                        ->where('imei', $imei)
                        ->where('inventory_unit_id', '!=', $unit->id)
                        ->exists();
                    if ($duplicate) {
                        $validator->errors()->add(
                            $field,
                            'This IMEI is already assigned to another unit.',
                        );
                    }
                }
            },
        ];
    }
}
