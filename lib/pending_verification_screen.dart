import 'package:flutter/material.dart';

class PendingVerificationScreen extends StatelessWidget {
  const PendingVerificationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.hourglass_top, size: 72, color: Colors.orange),
              SizedBox(height: 24),
              Text(
                'Account Pending Approval',
                style: TextStyle(fontFamily: 'NexaBold', fontSize: 24),
              ),
              SizedBox(height: 12),
              Text(
                'Your account is awaiting verification by an admin or teacher. You will be notified when approved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'NexaRegular'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
