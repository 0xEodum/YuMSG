import '../../features/startup/domain/enums/work_mode.dart';

class AuthScreenArgs {
  final WorkMode workMode;

  const AuthScreenArgs({required this.workMode});
}

class ChatScreenArgs {
  final String chatId;
  final String chatName;

  const ChatScreenArgs({
    required this.chatId,
    required this.chatName,
  });
}