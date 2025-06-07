// screens/encryption_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:yumsg/widgets/scrollable_card.dart';
import '../services/app_state_service.dart';

class EncryptionSettingsScreen extends StatefulWidget {
  const EncryptionSettingsScreen({super.key});

  @override
  State<EncryptionSettingsScreen> createState() => _EncryptionSettingsScreenState();
}

class _EncryptionSettingsScreenState extends State<EncryptionSettingsScreen> {
  // Текущие выбранные алгоритмы (для локального режима)
  String _selectedKem = 'NTRU';
  String _selectedEncryption = 'AES';
  String _selectedSignature = 'Falcon';

  // Доступные алгоритмы для локального режима
  final List<AlgorithmOption> _kemOptions = [
    AlgorithmOption('NTRU', 'NTRU Prime', 'Основан на задаче кратчайшего вектора в решетке'),
    AlgorithmOption('BIKE', 'BIKE', 'Основан на декодировании линейных кодов'),
    AlgorithmOption('HQC', 'HQC', 'Hamming Quasi-Cyclic коды'),
    AlgorithmOption('SABER', 'SABER', 'Module Learning With Errors'),
  ];

  final List<AlgorithmOption> _encryptionOptions = [
    AlgorithmOption('AES', 'AES-256', 'Advanced Encryption Standard'),
    AlgorithmOption('ChaCha', 'ChaCha20', 'Высокопроизводительное потоковое шифрование'),
    AlgorithmOption('Salsa', 'Salsa20', 'Быстрое потоковое шифрование'),
  ];

  final List<AlgorithmOption> _signatureOptions = [
    AlgorithmOption('Falcon', 'Falcon-512', 'Компактные подписи на решетках'),
    AlgorithmOption('Rainbow', 'Rainbow', 'Многомерные квадратичные системы'),
    AlgorithmOption('Dilithium', 'Dilithium', 'Module Learning With Errors подписи'),
  ];

  // Фиксированные алгоритмы для серверного режима
  final Map<String, AlgorithmOption> _serverAlgorithms = {
    'kem': AlgorithmOption('Kyber', 'Kyber-768', 'Стандарт NIST для квантово-устойчивого обмена ключами'),
    'encryption': AlgorithmOption('AES', 'AES-256-GCM', 'Стандарт шифрования с аутентификацией'),
    'signature': AlgorithmOption('Rainbow', 'Rainbow III', 'Квантово-устойчивая цифровая подпись'),
  };

  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    final appMode = AppStateService.getAppMode();

    return Scaffold(
      body: Column(
        children: [
          // Заголовок
          _buildHeader(isDark, statusBarHeight),
          
          // Основной контент
          Expanded(
            child: ScrollableCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Информационный блок
                  _buildInfoSection(isDark, appMode),
                  const SizedBox(height: 24),

                  // Настройки алгоритмов
                  if (appMode == 'server')
                    _buildServerAlgorithms(isDark)
                  else
                    _buildLocalAlgorithms(isDark),

                  // Кнопки действий (только для локального режима)
                  if (appMode == 'local') ...[
                    const SizedBox(height: 32),
                    _buildActionButtons(isDark),
                  ],
                ],
              ),
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
              'Сквозное шифрование',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(bool isDark, String? appMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.security,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Квантово-устойчивое шифрование',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            appMode == 'server'
                ? 'Алгоритмы шифрования настроены администратором сервера и не могут быть изменены. Это обеспечивает совместимость и безопасность в рамках организации.'
                : 'В локальном режиме вы можете выбрать алгоритмы шифрования. Все участники чата должны использовать одинаковые настройки для корректной работы.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          if (appMode == 'local') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark 
                    ? const Color(0xFF92400E).withOpacity(0.2) 
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Изменение алгоритмов потребует перезапуска всех активных чатов',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServerAlgorithms(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Текущие алгоритмы',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        
        _buildAlgorithmCard(
          title: 'Обмен ключами (KEM)',
          algorithm: _serverAlgorithms['kem']!,
          isDark: isDark,
          isReadOnly: true,
        ),
        const SizedBox(height: 12),
        
        _buildAlgorithmCard(
          title: 'Шифрование сообщений',
          algorithm: _serverAlgorithms['encryption']!,
          isDark: isDark,
          isReadOnly: true,
        ),
        const SizedBox(height: 12),
        
        _buildAlgorithmCard(
          title: 'Цифровая подпись',
          algorithm: _serverAlgorithms['signature']!,
          isDark: isDark,
          isReadOnly: true,
        ),
      ],
    );
  }

  Widget _buildLocalAlgorithms(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Настройки алгоритмов',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        
        _buildAlgorithmSelector(
          title: 'Обмен ключами (KEM)',
          selectedValue: _selectedKem,
          options: _kemOptions,
          onChanged: (value) => _updateKem(value),
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        
        _buildAlgorithmSelector(
          title: 'Шифрование сообщений',
          selectedValue: _selectedEncryption,
          options: _encryptionOptions,
          onChanged: (value) => _updateEncryption(value),
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        
        _buildAlgorithmSelector(
          title: 'Цифровая подпись',
          selectedValue: _selectedSignature,
          options: _signatureOptions,
          onChanged: (value) => _updateSignature(value),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildAlgorithmCard({
    required String title,
    required AlgorithmOption algorithm,
    required bool isDark,
    required bool isReadOnly,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),
              if (isReadOnly)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Серверные',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            algorithm.fullName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            algorithm.description,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlgorithmSelector({
    required String title,
    required String selectedValue,
    required List<AlgorithmOption> options,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    final selectedOption = options.firstWhere((opt) => opt.key == selectedValue);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          
          // Красивый dropdown
          InkWell(
            onTap: _isLoading ? null : () => _showAlgorithmDialog(title, selectedValue, options, onChanged),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedOption.fullName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedOption.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Column(
      children: [
        if (_hasChanges) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark 
                  ? const Color(0xFF1E3A8A).withOpacity(0.2) 
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'У вас есть несохранённые изменения',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        Row(
          children: [
            if (_hasChanges) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _resetChanges,
                  child: const Text('Сбросить'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _hasChanges && !_isLoading ? _saveChanges : null,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(_hasChanges ? 'Применить изменения' : 'Настройки сохранены'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAlgorithmDialog(
    String title, 
    String currentValue, 
    List<AlgorithmOption> options, 
    ValueChanged<String> onChanged
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Выберите алгоритм',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF9CA3AF) 
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              
              ...options.map((option) => _buildDialogOption(
                option, 
                currentValue == option.key, 
                () {
                  onChanged(option.key);
                  Navigator.pop(context);
                },
              )),
              
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogOption(AlgorithmOption option, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(color: Theme.of(context).colorScheme.primary)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB)),
                  width: 2,
                ),
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
              child: isSelected
                  ? const Center(
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.fullName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
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

  void _updateKem(String value) {
    setState(() {
      _selectedKem = value;
      _hasChanges = true;
    });
  }

  void _updateEncryption(String value) {
    setState(() {
      _selectedEncryption = value;
      _hasChanges = true;
    });
  }

  void _updateSignature(String value) {
    setState(() {
      _selectedSignature = value;
      _hasChanges = true;
    });
  }

  void _resetChanges() {
    setState(() {
      _selectedKem = 'NTRU';
      _selectedEncryption = 'AES';
      _selectedSignature = 'Falcon';
      _hasChanges = false;
    });
  }

  void _saveChanges() async {
    setState(() => _isLoading = true);
    
    // Имитация сохранения настроек
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _isLoading = false;
      _hasChanges = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Настройки шифрования сохранены'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class AlgorithmOption {
  final String key;
  final String fullName;
  final String description;

  AlgorithmOption(this.key, this.fullName, this.description);
}