import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Light / dark / follow-system preference, remembered on the device.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  static const _prefKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeController() {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  /// The brightness actually in effect right now.
  Brightness get brightness => switch (_mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
      };

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull;
      if (mode != null && mode != _mode) {
        _mode = mode;
        notifyListeners();
      }
    } catch (_) {
      // Preferences unavailable: keep following the system
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (_) {}
  }

  @override
  void didChangePlatformBrightness() {
    // Phone switched light/dark while we follow the system
    if (_mode == ThemeMode.system) notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Apply the palette for the current brightness and return the theme.
  ThemeData resolveTheme() {
    final b = brightness;
    AppTheme.use(b);
    return AppTheme.themeFor(b);
  }
}
