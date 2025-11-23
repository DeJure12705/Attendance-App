import 'dart:async';
import 'package:flutter/material.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:attendanceapp/login_page.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});
  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  Timer? _timer;
  int _seconds = 0;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= 8) {
        // Fallback: user still here, show retry option.
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waitingTooLong = _seconds >= 8;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade700,
              Colors.green.shade400,
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 72,
                  width: 72,
                  child: CircularProgressIndicator(strokeWidth: 6),
                ),
                const SizedBox(height: 28),
                Text(
                  'Signing you in...',
                  style: const TextStyle(
                    fontFamily: 'NexaBold',
                    fontSize: 24,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  User.email.isNotEmpty ? User.email : 'Finalizing credentials',
                  style: TextStyle(
                    fontFamily: 'NexaRegular',
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                AnimatedOpacity(
                  opacity: waitingTooLong ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: waitingTooLong
                      ? Column(
                          children: [
                            Text(
                              'Taking longer than expected. You can retry.',
                              style: TextStyle(
                                fontFamily: 'NexaRegular',
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginPage(),
                                  ),
                                  (route) => false,
                                );
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                if (!waitingTooLong)
                  Text(
                    'Please wait while we prepare your dashboard.',
                    style: TextStyle(
                      fontFamily: 'NexaRegular',
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
