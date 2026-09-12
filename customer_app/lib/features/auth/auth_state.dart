import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthState extends ChangeNotifier {
  AuthState({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance {
    _subscription = _auth.authStateChanges().listen((user) {
      _user = user;
      _initialized = true;
      notifyListeners();
    });
  }

  final FirebaseAuth _auth;

  StreamSubscription<User?>? _subscription;

  User? _user;
  bool _initialized = false;

  User? get user => _user;

  bool get isLoggedIn => _user != null;

  bool get initialized => _initialized;

  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
