// lib/features/chat/presentation/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isFromMe;
  final bool showStatus;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isFromMe,
    this.showStatus = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isFromMe ? 64 : 0,
          right: isFromMe ? 0 : 64,
        ),
        decoration: BoxDecoration(
          color: isFromMe 
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Контент сообщения
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    message.content,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                
                // Время и статус сообщения
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  color: isFromMe
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.grey[300]!.withOpacity(0.5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (isFromMe && showStatus) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusIcon() {
  // Если сообщение ожидает отправки, показываем специальный индикатор
  if (message.isPending) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time, size: 12, color: Colors.orange[700]),
        const SizedBox(width: 4),
        Text(
          'Ожидает',
          style: TextStyle(
            fontSize: 10,
            color: Colors.orange[700],
          ),
        ),
      ],
    );
  }
  
  switch (message.status) {
    case MessageStatus.sending:
      return const Icon(Icons.schedule, size: 12, color: Colors.grey);
    case MessageStatus.sent:
      return const Icon(Icons.check, size: 12, color: Colors.grey);
    case MessageStatus.delivered:
      return const Icon(Icons.done_all, size: 12, color: Colors.grey);
    case MessageStatus.read:
      return Icon(Icons.done_all, size: 12, color: Colors.blue[700]);
    case MessageStatus.error:
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 12, color: Colors.red),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              // TODO: Добавить повторную отправку сообщения
            },
            child: const Text(
              'Повторить',
              style: TextStyle(
                fontSize: 10,
                color: Colors.red,
              ),
            ),
          ),
        ],
      );
    default:
      return const SizedBox();
  }
}
  
  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }
}