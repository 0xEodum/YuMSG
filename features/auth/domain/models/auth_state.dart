enum AuthMode {
  login,
  register;

  String get title {
    switch (this) {
      case AuthMode.login:
        return 'Вход';
      case AuthMode.register:
        return 'Регистрация';
    }
  }
}