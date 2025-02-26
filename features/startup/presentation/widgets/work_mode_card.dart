import 'package:flutter/material.dart';
import '../../domain/enums/work_mode.dart';

class WorkModeRadioCard extends StatelessWidget {
  final WorkMode mode;
  final bool isSelected;
  final ValueChanged<WorkMode> onSelected;

  const WorkModeRadioCard({
    super.key,
    required this.mode,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSelected(mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Radio<WorkMode>(
              value: mode,
              groupValue: isSelected ? mode : null,
              onChanged: (_) => onSelected(mode),
            ),
            const SizedBox(width: 12),
            Icon(
              mode == WorkMode.server 
                  ? Icons.cloud_outlined 
                  : Icons.laptop_outlined,
              color: mode == WorkMode.server 
                  ? Colors.blue 
                  : Colors.green,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    mode.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}