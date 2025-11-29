// GENERATED CODE - placeholder for Firebase config
// Replace the values below by running `flutterfire configure` or
// copying the config from your Firebase console for each platform.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCuTg6Yagjr_Ro5pigYHf95xMcbslFpiW8',
    appId: '1:237655157264:web:0a221ef16e8485698f7895',
    messagingSenderId: '237655157264',
    projectId: 'attendance-app-abd13',
    authDomain: 'attendance-app-abd13.firebaseapp.com',
    storageBucket: 'attendance-app-abd13.firebasestorage.app',
    measurementId: 'G-6ZEY9RH9EE',
  );

  // Web configuration

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBQeGP2n5yCoyPZ2ffNeRyna9iwXBmG6_o',
    appId: '1:237655157264:android:588c226570675dd78f7895',
    messagingSenderId: '237655157264',
    projectId: 'attendance-app-abd13',
    storageBucket: 'attendance-app-abd13.firebasestorage.app',
  );

  // Android configuration

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDHIoDupJJgMqblTo8kXj055d8vtXu8t50',
    appId: '1:237655157264:ios:cdf5e2c439bb67be8f7895',
    messagingSenderId: '237655157264',
    projectId: 'attendance-app-abd13',
    storageBucket: 'attendance-app-abd13.firebasestorage.app',
    androidClientId: '237655157264-ln8mu9q0vbj6g5l9mgmqaj8v4re6i3q5.apps.googleusercontent.com',
    iosClientId: '237655157264-fgpbcjvoacoln844tv6ee9rbn4f8mq2h.apps.googleusercontent.com',
    iosBundleId: 'com.example.attendanceapp',
  );

  // iOS / macOS configuration
}

// Recommended: run `dart pub global activate flutterfire_cli` and
// `flutterfire configure` to generate a proper `firebase_options.dart`.