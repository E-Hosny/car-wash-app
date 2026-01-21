import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalDebugScreen extends StatefulWidget {
  const OneSignalDebugScreen({super.key});

  @override
  State<OneSignalDebugScreen> createState() => _OneSignalDebugScreenState();
}

class _OneSignalDebugScreenState extends State<OneSignalDebugScreen> {
  String? _permissionStatus;
  String? _subscriptionId;
  String? _userId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get subscription status
      try {
        final subscription = OneSignal.User.pushSubscription;
        final subscriptionId = subscription.id;
        final optedIn = subscription.optedIn ?? false;
        
        _subscriptionId = subscriptionId ?? 'Not available';
        _permissionStatus = optedIn ? 'Granted' : 'Not Granted';
      } catch (e) {
        _subscriptionId = 'Not available: $e';
        _permissionStatus = 'Unknown';
      }

      // Get subscription ID as user identifier
      try {
        final subscriptionId = OneSignal.User.pushSubscription.id;
        _userId = subscriptionId ?? 'Not set (anonymous)';
      } catch (e) {
        _userId = 'Not available: $e';
      }

      // Print to console for debugging
      print("🔍 OneSignal Debug Status:");
      print("   Permission: $_permissionStatus");
      print("   Subscription ID: $_subscriptionId");
      print("   User Subscription ID: $_userId");
    } catch (e) {
      print("❌ Error checking OneSignal status: $e");
      _permissionStatus = 'Error: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OneSignal Debug'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'OneSignal Status',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildStatusCard(
                'Permission Status',
                _permissionStatus ?? 'Unknown',
                _permissionStatus == 'Granted' ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildStatusCard(
                'Subscription ID',
                _subscriptionId ?? 'Unknown',
                Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildStatusCard(
                'User ID',
                _userId ?? 'Unknown',
                Colors.purple,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _checkStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Refresh Status'),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Note: Check console logs for detailed information.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
