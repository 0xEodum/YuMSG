// constants/file_types.dart
import 'package:flutter/material.dart';

class FileTypeInfo {
  final Color color;
  final IconData icon;
  final String extension;

  const FileTypeInfo({
    required this.color,
    required this.icon,
    required this.extension,
  });
}

class FileTypes {
  static const Map<String, FileTypeInfo> types = {
    'pdf': FileTypeInfo(color: Color(0xFFDC2626), icon: Icons.description, extension: 'PDF'),
    'doc': FileTypeInfo(color: Color(0xFF2563EB), icon: Icons.description, extension: 'DOC'),
    'docx': FileTypeInfo(color: Color(0xFF2563EB), icon: Icons.description, extension: 'DOCX'),
    'jpg': FileTypeInfo(color: Color(0xFF059669), icon: Icons.image, extension: 'JPG'),
    'jpeg': FileTypeInfo(color: Color(0xFF059669), icon: Icons.image, extension: 'JPEG'),
    'png': FileTypeInfo(color: Color(0xFF7C3AED), icon: Icons.image, extension: 'PNG'),
    'gif': FileTypeInfo(color: Color(0xFFEC4899), icon: Icons.gif, extension: 'GIF'),
    'mp3': FileTypeInfo(color: Color(0xFFEA580C), icon: Icons.audio_file, extension: 'MP3'),
    'wav': FileTypeInfo(color: Color(0xFFEA580C), icon: Icons.audio_file, extension: 'WAV'),
    'mp4': FileTypeInfo(color: Color(0xFFDB2777), icon: Icons.video_file, extension: 'MP4'),
    'avi': FileTypeInfo(color: Color(0xFFDB2777), icon: Icons.video_file, extension: 'AVI'),
    'zip': FileTypeInfo(color: Color(0xFF6B7280), icon: Icons.archive, extension: 'ZIP'),
    'rar': FileTypeInfo(color: Color(0xFF6B7280), icon: Icons.archive, extension: 'RAR'),
    'txt': FileTypeInfo(color: Color(0xFF374151), icon: Icons.text_snippet, extension: 'TXT'),
  };

  static FileTypeInfo getFileTypeInfo(String type) {
    return types[type] ?? const FileTypeInfo(
      color: Color(0xFF6B7280), 
      icon: Icons.insert_drive_file, 
      extension: 'FILE'
    );
  }
}