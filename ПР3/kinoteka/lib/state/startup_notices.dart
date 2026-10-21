import 'package:flutter/foundation.dart';

/// Сообщения, накопленные при чтении хранилища: перенос данных из старого
/// формата или восстановление испорченной коллекции.
class StartupNotices extends ChangeNotifier {
  StartupNotices(List<String> messages) : _messages = [...messages];

  final List<String> _messages;

  List<String> get messages => List.unmodifiable(_messages);

  void dismiss() {
    _messages.clear();
    notifyListeners();
  }
}
