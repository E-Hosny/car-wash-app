<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class TimeSlot extends Model
{
    use HasFactory;

    protected $fillable = [
        'hour',
        'label',
        'is_active',
        'is_booked',
        'date',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'is_booked' => 'boolean',
        'date' => 'date',
    ];

    /**
     * Scope to get active time slots
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Scope to get available time slots (active and not booked)
     */
    public function scopeAvailable($query)
    {
        return $query->where('is_active', true)->where('is_booked', false);
    }

    /**
     * Scope to get booked time slots
     */
    public function scopeBooked($query)
    {
        return $query->where('is_booked', true);
    }

    /**
     * Scope to get time slots for a specific date
     */
    public function scopeForDate($query, $date)
    {
        return $query->where('date', $date);
    }

    /**
     * Generate time slots for a specific date
     */
    public static function generateForDate($date)
    {
        $timeSlots = [];
        
        for ($hour = 10; $hour <= 23; $hour++) {
            $period = $hour < 12 ? 'AM' : 'PM';
            $displayHour = $hour > 12 ? $hour - 12 : $hour;
            if ($hour == 12) $displayHour = 12;
            
            $label = sprintf('%d:00 %s', $displayHour, $period);
            
            $timeSlots[] = [
                'hour' => $hour,
                'label' => $label,
                'is_active' => true,
                'is_booked' => false,
                'date' => $date,
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }
        
        return $timeSlots;
    }

    /**
     * Create or update time slots for a date
     */
    public static function createOrUpdateForDate($date)
    {
        $existingSlots = self::forDate($date)->get()->keyBy('hour');
        $generatedSlots = self::generateForDate($date);
        
        foreach ($generatedSlots as $slotData) {
            if ($existingSlots->has($slotData['hour'])) {
                // Update existing slot
                $existingSlots[$slotData['hour']]->update([
                    'label' => $slotData['label'],
                    'updated_at' => now(),
                ]);
            } else {
                // Create new slot
                self::create($slotData);
            }
        }
    }
}
