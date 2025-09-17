<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\TimeSlot;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Carbon\Carbon;

class TimeSlotController extends Controller
{
    /**
     * Get time slots for a specific date
     */
    public function getTimeSlots(Request $request): JsonResponse
    {
        $request->validate([
            'date' => 'required|date',
        ]);

        $date = Carbon::parse($request->date)->format('Y-m-d');
        
        // Generate time slots for the date if they don't exist
        TimeSlot::createOrUpdateForDate($date);
        
        $timeSlots = TimeSlot::forDate($date)
            ->orderBy('hour')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $timeSlots,
        ]);
    }

    /**
     * Get booked time slots for a specific date
     */
    public function getBookedTimeSlots(Request $request): JsonResponse
    {
        $request->validate([
            'date' => 'required|date',
        ]);

        $date = Carbon::parse($request->date)->format('Y-m-d');
        
        // Generate time slots for the date if they don't exist
        TimeSlot::createOrUpdateForDate($date);
        
        $bookedHours = TimeSlot::forDate($date)
            ->where(function($query) {
                $query->where('is_booked', true)
                      ->orWhere('is_active', false);
            })
            ->pluck('hour')
            ->toArray();

        return response()->json([
            'success' => true,
            'booked_hours' => $bookedHours,
        ]);
    }

    /**
     * Toggle time slot status (admin only)
     */
    public function toggleTimeSlot(Request $request): JsonResponse
    {
        $request->validate([
            'date' => 'required|date',
            'hour' => 'required|integer|min:10|max:23',
            'is_active' => 'required|boolean',
        ]);

        $date = Carbon::parse($request->date)->format('Y-m-d');
        
        // Generate time slots for the date if they don't exist
        TimeSlot::createOrUpdateForDate($date);
        
        $timeSlot = TimeSlot::forDate($date)
            ->where('hour', $request->hour)
            ->first();

        if (!$timeSlot) {
            return response()->json([
                'success' => false,
                'message' => 'Time slot not found',
            ], 404);
        }

        $timeSlot->update([
            'is_active' => $request->is_active,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Time slot status updated successfully',
            'data' => $timeSlot,
        ]);
    }

    /**
     * Book a time slot
     */
    public function bookTimeSlot(Request $request): JsonResponse
    {
        $request->validate([
            'date' => 'required|date',
            'hour' => 'required|integer|min:10|max:23',
        ]);

        $date = Carbon::parse($request->date)->format('Y-m-d');
        
        $timeSlot = TimeSlot::forDate($date)
            ->where('hour', $request->hour)
            ->first();

        if (!$timeSlot) {
            return response()->json([
                'success' => false,
                'message' => 'Time slot not found',
            ], 404);
        }

        if (!$timeSlot->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Time slot is disabled',
            ], 400);
        }

        if ($timeSlot->is_booked) {
            return response()->json([
                'success' => false,
                'message' => 'Time slot is already booked',
            ], 400);
        }

        $timeSlot->update([
            'is_booked' => true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Time slot booked successfully',
            'data' => $timeSlot,
        ]);
    }

    /**
     * Release a time slot (admin only)
     */
    public function releaseTimeSlot(Request $request): JsonResponse
    {
        $request->validate([
            'date' => 'required|date',
            'hour' => 'required|integer|min:10|max:23',
        ]);

        $date = Carbon::parse($request->date)->format('Y-m-d');
        
        $timeSlot = TimeSlot::forDate($date)
            ->where('hour', $request->hour)
            ->first();

        if (!$timeSlot) {
            return response()->json([
                'success' => false,
                'message' => 'Time slot not found',
            ], 404);
        }

        $timeSlot->update([
            'is_booked' => false,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Time slot released successfully',
            'data' => $timeSlot,
        ]);
    }

    /**
     * Get time slots management data for admin
     */
    public function getManagementData(Request $request): JsonResponse
    {
        $request->validate([
            'date' => 'required|date',
        ]);

        $date = Carbon::parse($request->date)->format('Y-m-d');
        
        // Generate time slots for the date if they don't exist
        TimeSlot::createOrUpdateForDate($date);
        
        $timeSlots = TimeSlot::forDate($date)
            ->orderBy('hour')
            ->get();

        $stats = [
            'total' => $timeSlots->count(),
            'active' => $timeSlots->where('is_active', true)->count(),
            'disabled' => $timeSlots->where('is_active', false)->count(),
            'booked' => $timeSlots->where('is_booked', true)->count(),
            'available' => $timeSlots->where('is_active', true)->where('is_booked', false)->count(),
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'time_slots' => $timeSlots,
                'stats' => $stats,
            ],
        ]);
    }
}
