<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('time_slots', function (Blueprint $table) {
            $table->id();
            $table->integer('hour'); // 10-23 (10 AM to 11 PM)
            $table->string('label'); // "10:00 AM", "11:00 AM", etc.
            $table->boolean('is_active')->default(true); // true = available, false = disabled
            $table->boolean('is_booked')->default(false); // true = booked by customer
            $table->date('date'); // The specific date
            $table->timestamps();
            
            // Ensure unique combination of hour and date
            $table->unique(['hour', 'date']);
            
            // Index for better performance
            $table->index(['date', 'is_active']);
            $table->index(['date', 'is_booked']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('time_slots');
    }
};
