<?php

namespace App\Rules;

use Closure;
use Illuminate\Contracts\Validation\ValidationRule;

class ValidImei implements ValidationRule
{
    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        if (! is_string($value) || preg_match('/^[0-9]{15}$/D', $value) !== 1) {
            $fail('The :attribute must contain exactly 15 digits.');

            return;
        }

        $sum = 0;
        for ($index = 0; $index < 15; $index++) {
            $digit = (int) $value[$index];
            if ($index % 2 === 1) {
                $digit *= 2;
                if ($digit > 9) {
                    $digit -= 9;
                }
            }
            $sum += $digit;
        }

        if ($sum % 10 !== 0) {
            $fail('The :attribute check digit is invalid.');
        }
    }
}
