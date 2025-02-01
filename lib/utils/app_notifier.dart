import 'package:flutter/material.dart';
import 'package:github_var_updater/main.dart';


/// NotificationManager handles user notifications inside the app UI.
/// It supports both, dialog notifications and overlay notifications.
/// 
/// Dialog Notifications can be used to notify user about any important event or thing.
/// Overlay Notifications can be used to notify user about any unimportant event or thing.
class AppNotifier {
  static final GlobalKey<HomePageState> _globalKey = GlobalKey<HomePageState>();
  static final List<NotificationWidget> _notifications = [];

  static GlobalKey<HomePageState> get homePageKey => _globalKey;
  static List<NotificationWidget> get notifications => _notifications;

  static OverlayEntry? _mainOverlayEntry ;

  /// Returns a styled alert dialog with custom theme, title, icon and message
  static AlertDialog _getStyledDialog(
      {required MaterialColor themeColor,
      required BuildContext context,
      required String title,
      required String msg,
      Icon? icon,
      void Function()? okButtonBehaviour}) {
    return AlertDialog(
      backgroundColor: themeColor.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: themeColor,
          width: 2.0,
        ),
      ),
      title: Column(
        children: [
          Row(children: [
            if (icon != null) ...[icon, SizedBox(width: 12)],
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: themeColor,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Divider(
            color: themeColor,
            thickness: 1.5,
          )
        ],
      ),
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            msg,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            if (okButtonBehaviour != null) {
              okButtonBehaviour();
            }
          },
          style: TextButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }

  static Future<void> showErrorDialog({required String errorMessage,
      void Function()? okButtonBehaviour}) async {
    BuildContext? context = homePageKey.currentContext;
    if (context != null) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return _getStyledDialog(
              themeColor: Colors.red,
              context: context,
              title: 'Error',
              msg: errorMessage,
              icon: Icon(Icons.error_outline, color: Colors.red, size: 24));
        },
      );
    }
  }

  static Future<void> showInfoDialog({required String info,
      void Function()? okButtonBehaviour}) async {
    BuildContext? context = homePageKey.currentContext;
    if (context != null) {
      await showDialog(
          context: context,
          builder: (context) {
            return _getStyledDialog(
                themeColor: Colors.blue,
                context: context,
                title: 'Info',
                msg: info,
                icon: Icon(Icons.info_outline, color: Colors.blue, size: 24));
          });
    }
  }

  /// It removes given [notification] from [_notifications] list if it is present
  static void _removeNotification(NotificationWidget notification) {
    int index = _notifications.indexOf(notification);
    if (index == -1) return;
    _notifications.removeAt(index);

    _mainOverlayEntry?.markNeedsBuild();

    if (_notifications.isEmpty) {
      _mainOverlayEntry?.remove();
      _mainOverlayEntry?.dispose();
      _mainOverlayEntry = null;
    }
  }

  /// Shows given [notification] on the top portion of screen.
  /// If not dismissed manually in given [duration], it removes it automatically
  static void showNotification({
    required NotificationWidget notification,
    Duration duration = const Duration(seconds: 5),
  }) {
    
    BuildContext? context = homePageKey.currentContext;
    if (context == null) return;

    // Get the overlay instance
    final overlay = Overlay.of(context);

    _notifications.insert(0, notification);

    // Schedules automatic dismissal of notification after given
    // period of time
    Future.delayed(duration, () {
      if (notification.onDismissed != null) {
        notification.onDismissed!(DismissDirection.none);
      }
      _removeNotification(notification);
    });

    if (_mainOverlayEntry != null) {
      _mainOverlayEntry!.markNeedsBuild();
    } else {
      _mainOverlayEntry = OverlayEntry(
        builder: (context) {
          return Positioned(
            top: MediaQuery.of(context).size.height * 0.1,
            left: MediaQuery.of(context).size.width * 0.03,
            right: MediaQuery.of(context).size.width * 0.03,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.25, // 25% of available height
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: _notifications.map((message) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: message
                    );
                  }).toList()
                ),
              ),
            ),
          );
        }
      );
      overlay.insert(_mainOverlayEntry!);
    }
  }

  static void notifyUserAboutError({
    required String errorMessage,
    Duration duration = const Duration(seconds: 5),
    void Function(DismissDirection)? onDismissed
  }) {
    showNotification(
      notification: NotificationWidget(
        message: errorMessage,
        themeColor: Colors.red,
        icon: Icon(Icons.error_outline, color: Colors.red, size: 24),
        onDismissed: onDismissed,
      ),
      duration: duration
    );
  }

  static void notifyUserAboutInfo({
    required String info,
    Duration duration = const Duration(seconds: 5),
    void Function(DismissDirection)? onDismissed
  }) {
    showNotification(
      notification: NotificationWidget(
        message: info,
        themeColor: Colors.blue,
        icon: const Icon(Icons.info_outline, color: Colors.blue, size: 24),
        onDismissed: onDismissed,
      ),
      duration: duration
    );
  }

  static void notifyUserAboutSuccess({
    required String successMessage,
    Duration duration = const Duration(seconds: 5),
    void Function(DismissDirection)? onDismissed
  }) {
    showNotification(
      notification: NotificationWidget(
        message: successMessage,
        themeColor: Colors.green,
        icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 24)
      ),
      duration: duration
    );
  }
}

/// It encapsulates fields related to notification message that will appear
/// on the screen without dialog (like notifications)
class NotificationWidget extends StatelessWidget {
  final String message; // The message that is being displayed in the notification
  final void Function(DismissDirection)? onDismissed;  // What to do when Notifcation is dismissed
  final MaterialColor themeColor;
  final Icon icon;
  final TextStyle messageStyle;

  const NotificationWidget({
    super.key,
    required this.message,
    required this.themeColor,
    required this.icon,
    this.messageStyle = const TextStyle(color: Colors.black, fontSize: 18),
    this.onDismissed
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.horizontal,
      onDismissed: (dir) {
        // Call on dismissed callback
        if (onDismissed != null) {
          onDismissed!(dir);
        }

        // Remove notification from notifications list
        AppNotifier._removeNotification(this);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: themeColor.shade50, // Light Shade of themeColor
          border: Border.all(color: themeColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: messageStyle
              ),
            ),
          ],
        ),
      ),
    );
  }
}