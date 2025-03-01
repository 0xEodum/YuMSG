// lib/features/chat/presentation/widgets/message_input.dart
import 'package:flutter/material.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback? onAttachment;

  const MessageInput({
    Key? key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.onAttachment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            // Кнопка прикрепления файла
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: onAttachment,
              color: Colors.grey[700],
            ),
            
            // Поле ввода текста
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Введите сообщение...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            
            // Кнопка отправки
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: onSend,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}