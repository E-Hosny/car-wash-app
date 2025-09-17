<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AdminMiddleware
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        
        if (!$user) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }
        
        // Check if user is admin (you can modify this logic based on your user structure)
        if ($user->role !== 'admin' && $user->is_admin !== true) {
            return response()->json(['message' => 'Access denied. Admin privileges required.'], 403);
        }
        
        return $next($request);
    }
}
