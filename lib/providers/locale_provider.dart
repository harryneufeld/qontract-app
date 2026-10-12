import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/strings.dart';

/// Device-wide choice; null follows the OS and unknown languages use English.
class LocaleProvider extends ChangeNotifier with WidgetsBindingObserver {
  LocaleProvider({SharedPreferences? prefs}) : _prefs = prefs {
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }
  static const storageKey = 'app.language';
  final SharedPreferences? _prefs;
  String? _selection;
  String? _linkLanguage;
  String? get selection => _linkLanguage ?? _selection;
  Locale _locale = const Locale('en');
  Locale get locale => _locale;
  bool _edited = false;
  Future<void> init() async {
    final raw = (await _resolvePrefs()).getString(storageKey);
    if (_edited) return;
    _selection = raw == 'de' || raw == 'en' ? raw : null;
    _sync();
    notifyListeners();
  }

  Future<void> setLanguage(String? language) async {
    if (language != null && language != 'en' && language != 'de') return;
    _edited = true;
    _linkLanguage = null;
    _selection = language;
    _sync();
    notifyListeners();
    final prefs = await _resolvePrefs();
    if (language == null) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, language);
    }
  }

  Future<SharedPreferences> _resolvePrefs() async =>
      _prefs ?? await SharedPreferences.getInstance();
  void _sync() {
    final device = WidgetsBinding.instance.platformDispatcher.locales
            .map((locale) => locale.languageCode)
            .where((code) => code == 'en' || code == 'de')
            .firstOrNull ??
        'en';
    _locale = Locale(_linkLanguage ?? _selection ?? device);
    S.languageCode = _locale.languageCode;
    Intl.defaultLocale = S.languageCode == 'de' ? 'de_DE' : 'en_US';
  }

  /// A reset link carries the requesting language to another device. Apply it
  /// for this session without overwriting that device's stored preference.
  void useLinkLanguage(String? language) {
    if (language != 'de' && language != 'en') return;
    _linkLanguage = language;
    _sync();
    notifyListeners();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_selection == null) {
      _sync();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
