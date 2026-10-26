<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class MakeAdmin extends Command
{
    protected $signature = 'app:make-admin';

    protected $description = 'Create the first JakStore admin account interactively';

    public function handle(): int
    {
        $name = trim((string) $this->ask('Admin name'));
        $email = mb_strtolower(trim((string) $this->ask('Admin email')));
        $password = (string) $this->secret('Admin password (minimum 12 characters)');
        $confirmation = (string) $this->secret('Confirm admin password');

        $validator = Validator::make(
            compact('name', 'email', 'password'),
            [
                'name' => ['required', 'string', 'max:255'],
                'email' => ['required', 'email', 'max:255', 'unique:users,email'],
                'password' => ['required', 'string', 'min:12', 'confirmed'],
            ],
            [],
            ['password_confirmation' => 'password confirmation'],
        );
        $validator->setData([
            'name' => $name,
            'email' => $email,
            'password' => $password,
            'password_confirmation' => $confirmation,
        ]);
        if ($validator->fails()) {
            $this->error($validator->errors()->first());

            return self::FAILURE;
        }

        User::query()->create([
            'name' => $name,
            'email' => $email,
            'password' => Hash::make($password),
            'is_admin' => true,
        ]);

        $this->info('Admin account created. No password was displayed.');

        return self::SUCCESS;
    }
}
