# Guest Browsing Implementation

## Overview
The Car Wash App has been modified to allow users to browse the app without requiring login, addressing app store rejection concerns. Users can now explore services and packages as guests, with login required only when attempting to make purchases or place orders.

## Changes Made

### 1. Main Navigation Screen (`main_navigation_screen.dart`)
- Added `isGuest` parameter to support guest mode
- Made `token` parameter nullable
- Added login prompts for restricted actions (New Order, Orders)
- Modified navigation bar to show disabled states for guest-restricted tabs
- Added "Browse Services" title for guest users
- Replaced logout button with login button for guests

### 2. Splash Screen (`splash_screen.dart`)
- Modified to show welcome dialog when no token is found
- Provides options to "Browse as Guest" or "Login"
- Guest users start on the packages tab (index 1)

### 3. All Packages Screen (`all_packages_screen.dart`)
- Added `isGuest` parameter support
- Modified API calls to work without authentication for guests
- Added login prompts when guests try to purchase packages
- Skips user package fetching for guest users

### 4. Guest Services Screen (`guest_services_screen.dart`)
- Created new screen specifically for guest users to browse services
- Displays all available services with pricing information
- Shows login prompts when guests try to request services
- Uses public API endpoints that don't require authentication

### 5. API Routes (`car-wash-api/routes/api.php`)
- Moved packages index endpoint outside authentication middleware
- Added public services endpoints for guest browsing
- Kept service creation/modification and user-specific endpoints protected
- Reorganized public endpoints section

## User Experience Flow

### Guest Users
1. **App Launch**: Welcome dialog with "Browse as Guest" or "Login" options
2. **Services Tab**: Can browse all available services with pricing information
3. **Packages Tab**: Can view all packages and pricing without restrictions
4. **Service Request**: Login prompt appears when trying to request services
5. **Package Purchase**: Login prompt appears when trying to buy packages
6. **Orders Tab**: Login prompt appears when trying to access orders

### Authenticated Users
1. **App Launch**: Direct access to main navigation
2. **Full Access**: All features available without restrictions
3. **Logout**: Option to logout and return to guest mode

## Technical Implementation

### Frontend (Flutter)
- **Guest Mode Navigation**: Conditional rendering based on `isGuest` flag
- **Login Prompts**: Modal dialogs that redirect to login screen
- **API Calls**: Headers conditionally include authentication tokens
- **UI States**: Visual indicators for disabled/restricted features

### Backend (Laravel)
- **Public Endpoints**: Packages listing accessible without authentication
- **Protected Endpoints**: User-specific and purchase endpoints require authentication
- **Middleware**: `auth:sanctum` middleware protects sensitive operations

## Benefits
1. **App Store Compliance**: Users can explore the app without forced registration
2. **Better User Experience**: Progressive disclosure of features
3. **Increased Conversions**: Users can see value before committing to registration
4. **Maintained Security**: Sensitive operations still require authentication

## Future Considerations
- Consider adding more public content (service descriptions, pricing)
- Implement analytics to track guest vs authenticated user behavior
- Add guest user feedback collection
- Consider guest checkout with minimal information collection 