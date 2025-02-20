import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:github_var_updater/utils/app_notifier.dart';
import 'package:url_launcher/url_launcher.dart';

class LocalServer with WidgetsBindingObserver {
  static String? _authCode;
  static Isolate? _serverIsolate;
  static bool _isWaitingForAuth = false;
  static bool _isServerRunning = false;

  static String? get googleAuthCode => _authCode;

  /// This method simply initiates authentication and exits. To wait
  /// for authentication to complete, await the waitForAuth() method.
  static Future<void> initiateAuthentication(Uri authUri) async {
    _authCode = null;
    _isWaitingForAuth = true;

    // Start the server to listen for redirects
    await _startServerIsolate();

    if (await canLaunchUrl(authUri)) {
      WidgetsBinding.instance.addObserver(LocalServer());
      await launchUrl(authUri, mode: LaunchMode.externalApplication);
    } else {
      AppNotifier.notifyUserAboutError(errorMessage: "Could not initiate authentication via browser!");
      _isWaitingForAuth = false;
    }
  }

  static Future<bool> _checkAuthCompletion() async {
    while (_isWaitingForAuth) {
      await Future.delayed(Duration(milliseconds: 100));
    }
    return false;
  }

  /// Waits for authentication to completes and returns whether a timeout occured
  /// 
  /// To check if authentication is successfull, check whether googleAuthCode is null or not
  static Future<bool> waitForAuth({Duration timeoutDuration = const Duration(seconds: 120)}) async {
    // It must be called only after initiating authentication
    if (!_isWaitingForAuth) return true;
    return await Future.any([
      _checkAuthCompletion(), // Check for authentication
      Future.delayed(timeoutDuration, () => true) // Also create a timeout timer
    ]);
  }

  /// Starts the server in background (isolated process) if it is not running
  static Future<void> _startServerIsolate() async {
    if (_serverIsolate != null) return;

    ReceivePort receiverPort = ReceivePort();
    _serverIsolate = await Isolate.spawn(_serverIsolateEntryPoint, receiverPort.sendPort);

    receiverPort.listen((message) {
      if (message is bool) {
        _isServerRunning = message;
      } else if (message is String?) {
        _authCode = message;
        // Stop server isolate to free resources
        _stopServerIsolate();
      }
    });
  }

  /// The entry point for server isolate.
  static Future<void> _serverIsolateEntryPoint(SendPort port) async {
    
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
    port.send(true);  // Server has started running

    bool shouldServerStop = false;

    await for (HttpRequest request in server) {
      final response = request.response;

      if (request.uri.path == '/oauth2redirect') {
        final code = request.uri.queryParameters['code'];
        // Send authCode back to main isolate for processing
        port.send(code);
        response.write("Authentication ${code == null? 'cancelled' : 'flow completed'}. You may close this window now.");
        shouldServerStop = true;
      } else {
        response.write('Local server is running...');
      }

      await response.close();

      if (shouldServerStop) {
        await server.close(force: true);
        port.send(false); // Meaning server is not running
      }
    }
  }

  /// Stops server isolate. When authentication flow completes
  /// server isolate and server is shut down to free resources
  static Future<void> _stopServerIsolate() async {
    if (_serverIsolate != null) {
      // Wait for server to stop running
      while (_isServerRunning) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      _serverIsolate!.kill(priority: Isolate.immediate);
      _serverIsolate = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Remove observer to prevent redundant calls
      WidgetsBinding.instance.removeObserver(this);

      // User reopens app after authentication process, so waiting is over
      _isWaitingForAuth = false;
    }
  }
}
