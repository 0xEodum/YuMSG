enum WorkMode {
  server,
  local;

  String get title {
    switch (this) {
      case WorkMode.server:
        return 'Серверный режим';
      case WorkMode.local:
        return 'Локальный режим';
    }
  }

  String get description {
    switch (this) {
      case WorkMode.server:
        return 'Подключение к корпоративному серверу';
      case WorkMode.local:
        return 'Работа в локальной сети';
    }
  }
}