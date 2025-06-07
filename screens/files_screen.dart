// screens/files_screen.dart
import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../constants/file_types.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';


  // Примеры файлов
  final List<FileInfo> _sampleFiles = [
    FileInfo(name: 'Презентация проекта.pdf', type: 'pdf', size: '2.4 MB', date: '15 мин назад'),
    FileInfo(name: 'Техническое задание.docx', type: 'docx', size: '856 KB', date: '1 час назад'),
    FileInfo(name: 'Логотип компании.png', type: 'png', size: '124 KB', date: '3 часа назад'),
    FileInfo(name: 'Фото команды.jpg', type: 'jpg', size: '3.2 MB', date: 'Вчера'),
    FileInfo(name: 'Демо трек.mp3', type: 'mp3', size: '4.8 MB', date: '2 дня назад'),
    FileInfo(name: 'Демонстрация.mp4', type: 'mp4', size: '12.1 MB', date: '3 дня назад'),
    FileInfo(name: 'Архив проекта.zip', type: 'zip', size: '15.6 MB', date: 'Неделю назад'),
    FileInfo(name: 'Заметки.txt', type: 'txt', size: '12 KB', date: 'Вчера'),
    FileInfo(name: 'Отчет Q4.pdf', type: 'pdf', size: '1.8 MB', date: '2 дня назад'),
    FileInfo(name: 'Макет интерфейса.png', type: 'png', size: '890 KB', date: '4 дня назад'),
  ];

  List<FileInfo> get _filteredFiles {
    List<FileInfo> filtered = _sampleFiles;
    
    // Фильтр по категории
    if (_selectedCategory != 'all') {
      filtered = filtered.where((file) {
        switch (_selectedCategory) {
          case 'documents':
            return ['pdf', 'doc', 'docx', 'txt'].contains(file.type);
          case 'images':
            return ['jpg', 'jpeg', 'png', 'gif'].contains(file.type);
          case 'media':
            return ['mp3', 'wav', 'mp4', 'avi'].contains(file.type);
          case 'archives':
            return ['zip', 'rar'].contains(file.type);
          default:
            return true;
        }
      }).toList();
    }
    
    // Фильтр по поиску
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((file) =>
        file.name.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;

    return Scaffold(
      body: Column(
        children: [
          // Заголовок
          _buildHeader(isDark, statusBarHeight),
          
          // Основной контент
          Expanded(
            child: Column(
              children: [
                // Статистика и фильтры
                _buildTopSection(isDark),
                
                // Список файлов
                Expanded(
                  child: _buildFileGrid(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, double statusBarHeight) {
    return Container(
      padding: EdgeInsets.only(
        top: statusBarHeight + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Файлы',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ),
          IconButton(
            onPressed: () => ThemeService().toggleTheme(),
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Статистика
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_sampleFiles.length} файлов • ${_getTotalSize()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Поиск и фильтры
          Row(
            children: [
              // Поиск
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск файлов...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 12),
              
              // Фильтр
              PopupMenuButton<String>(
                onSelected: (value) => setState(() => _selectedCategory = value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'all', child: Text('Все файлы')),
                  const PopupMenuItem(value: 'documents', child: Text('Документы')),
                  const PopupMenuItem(value: 'images', child: Text('Изображения')),
                  const PopupMenuItem(value: 'media', child: Text('Медиа')),
                  const PopupMenuItem(value: 'archives', child: Text('Архивы')),
                ],
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.filter_list),
                ),
              ),
            ],
          ),
          
          // Категории (чипы)
          const SizedBox(height: 16),
          _buildCategoryChips(isDark),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(bool isDark) {
    final categories = [
      {'key': 'all', 'label': 'Все', 'icon': Icons.folder},
      {'key': 'documents', 'label': 'Документы', 'icon': Icons.description},
      {'key': 'images', 'label': 'Изображения', 'icon': Icons.image},
      {'key': 'media', 'label': 'Медиа', 'icon': Icons.play_circle},
      {'key': 'archives', 'label': 'Архивы', 'icon': Icons.archive},
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category['key'];
          
          return Padding(
            padding: EdgeInsets.only(right: index < categories.length - 1 ? 8 : 0),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category['icon'] as IconData,
                    size: 16,
                    color: isSelected 
                        ? Colors.white 
                        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 4),
                  Text(category['label'] as String),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category['key'] as String;
                });
              },
              backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
              selectedColor: Theme.of(context).colorScheme.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected 
                    ? Colors.white 
                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileGrid(bool isDark) {
    final filteredFiles = _filteredFiles;

    if (filteredFiles.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: filteredFiles.length,
        itemBuilder: (context, index) {
          return _buildFileCard(filteredFiles[index], isDark);
        },
      ),
    );
  }

  Widget _buildFileCard(FileInfo file, bool isDark) {
    final typeInfo = FileTypes.getFileTypeInfo(file.type);

    return GestureDetector(
      onTap: () => _handleFileTap(file),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              typeInfo.color.withOpacity(isDark ? 0.15 : 0.08),
              isDark ? const Color(0xFF1F2937).withOpacity(0.95) : Colors.white.withOpacity(0.95),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: typeInfo.color.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Верхняя секция с градиентом
            Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    typeInfo.color.withOpacity(0.25),
                    typeInfo.color.withOpacity(0.4),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Иконка файла
                  Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        typeInfo.icon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  
                  // Расширение файла
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeInfo.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        typeInfo.extension,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Нижняя секция с информацией
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название файла
                    Expanded(
                      child: Text(
                        file.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Метаданные и действия
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.size,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                              Text(
                                file.date,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Кнопки действий
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildActionButton(
                              icon: Icons.download,
                              color: typeInfo.color,
                              onPressed: () => _handleDownload(file),
                            ),
                            const SizedBox(width: 4),
                            _buildActionButton(
                              icon: Icons.share,
                              color: typeInfo.color,
                              onPressed: () => _handleShare(file),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: color,
          size: 14,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'Файлы не найдены' : 'Нет файлов',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
                ? 'Попробуйте изменить поисковый запрос'
                : 'Файлы появятся здесь после загрузки',
            style: TextStyle(
              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getTotalSize() {
    double totalMB = 0;
    for (final file in _sampleFiles) {
      final sizeStr = file.size.replaceAll(RegExp(r'[^0-9.]'), '');
      final size = double.tryParse(sizeStr) ?? 0;
      if (file.size.contains('GB')) {
        totalMB += size * 1024;
      } else if (file.size.contains('MB')) {
        totalMB += size;
      } else if (file.size.contains('KB')) {
        totalMB += size / 1024;
      }
    }
    
    if (totalMB > 1024) {
      return '${(totalMB / 1024).toStringAsFixed(1)} GB общий размер';
    } else {
      return '${totalMB.toStringAsFixed(1)} MB общий размер';
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _handleFileTap(FileInfo file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Открыть файл: ${file.name}')),
    );
  }

  void _handleDownload(FileInfo file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Скачать: ${file.name}')),
    );
  }

  void _handleShare(FileInfo file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Поделиться: ${file.name}')),
    );
  }
}

class FileInfo {
  final String name;
  final String type;
  final String size;
  final String date;

  FileInfo({
    required this.name,
    required this.type,
    required this.size,
    required this.date,
  });
}