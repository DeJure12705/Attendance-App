import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text(
              'Terms & Conditions',
              style: TextStyle(fontSize: 22, fontFamily: 'NexaBold'),
            ),
            SizedBox(height: 12),
            Text(
              '1. Data Usage: Collected profile and attendance data are used solely for academic attendance tracking and verification purposes.\n\n'
              '2. Privacy: Your images (profile and ID) are stored securely in Firebase Storage. Access is restricted by Firestore security rules.\n\n'
              '3. Accuracy: You agree to provide accurate, current, and complete information. False submissions may lead to rejection.\n\n'
              '4. Verification: Pending accounts are reviewed by authorized staff. Approved accounts gain access; rejected accounts may resubmit corrected data.\n\n'
              '5. Security: Do not share your login credentials. Any misuse may result in suspension.\n\n'
              '6. Updates: These terms may change; continued use after updates constitutes acceptance of the revised terms.\n\n'
              '7. Consent: By submitting credentials you consent to the processing of your data as described.',
              style: TextStyle(fontSize: 14, fontFamily: 'NexaRegular'),
            ),
          ],
        ),
      ),
    );
  }
}
