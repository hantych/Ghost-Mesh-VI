// Web stub — local notifications are not available in browsers.
class NotificationService {
  Future<void> init() async {}
  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String chatId,
  }) async {}
}
