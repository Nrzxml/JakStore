<?php

namespace App\Http\Requests;

use App\Models\InventoryImeiClaim;
use App\Rules\ValidImei;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class StoreInventoryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'product_variant_id' => [
                'required',
                'integer',
                Rule::exists('product_variants', 'id')->where('is_active', true),
            ],
            'imei1' => ['required', 'string', new ValidImei],
            'imei2' => ['nullable', 'string', new ValidImei],
            'status' => [
                'sometimes',
                Rule::in(['available', 'service', 'damaged', 'returned']),
            ],
            'note' => ['nullable', 'string', 'max:500'],
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator): void {
                $imei1 = $this->input('imei1');
                $imei2 = $this->input('imei2');
                $imeis = array_values(array_filter(
                    [$imei1, $imei2],
                    fn (mixed $imei): bool => is_string($imei) && $imei !== '',
                ));

                if (
                    is_string($imei1)
                    && is_string($imei2)
                    && $imei2 !== ''
                    && $imei1 === $imei2
                ) {
                    $validator->errors()->add('imei2', 'IMEI 1 and IMEI 2 must be different.');
                }

                if ($imeis !== []) {
                    $duplicates = InventoryImeiClaim::query()
                        ->whereIn('imei', $imeis)
                        ->pluck('imei')
                        ->all();
                    foreach ($duplicates as $duplicate) {
                        $field = $duplicate === $imei1 ? 'imei1' : 'imei2';
                        $validator->errors()->add($field, 'This IMEI is already assigned to another unit.');
                    }
                }
            },
        ];
    }
}
