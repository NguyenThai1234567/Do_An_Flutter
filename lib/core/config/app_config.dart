import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _keyEmarketBaseUrl = 'emarket_base_url';
  static const String _keyAiBaseUrl = 'ai_base_url';

  // Production Cloud Endpoints
  static const String presetCustomDomain = 'https://nguyenhaphuongthai.id.vn/';
  static const String presetAzure = 'https://nguyenhaphuongthai.id.vn/';
  static const String presetAzureLegacy = 'https://emarketsystem-e5afekgsdzbtcngf.japaneast-01.azurewebsites.net/';
  static const String presetProductionDemo = presetCustomDomain;

  // AI Assistant Cloud Endpoint (Azure App Service)
  static const String presetAiAzure = 'https://emarket-assistant-cjdgcjegdxd8hnby.japaneast-01.azurewebsites.net/';

  static String get defaultEmarketBaseUrl => presetCustomDomain;
  static String get defaultAiBaseUrl => presetAiAzure;

  static String _emarketBaseUrl = defaultEmarketBaseUrl;
  static String _aiBaseUrl = defaultAiBaseUrl;

  static String get emarketBaseUrl => _emarketBaseUrl;
  static String get aiBaseUrl => _aiBaseUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Tự động nâng cấp sang Cloud nếu thiết bị từng lưu URL localhost/10.0.2.2 cũ
    final savedEmarketUrl = prefs.getString(_keyEmarketBaseUrl);
    if (savedEmarketUrl == null || savedEmarketUrl.contains('localhost') || savedEmarketUrl.contains('10.0.2.2')) {
      _emarketBaseUrl = defaultEmarketBaseUrl;
      await prefs.setString(_keyEmarketBaseUrl, defaultEmarketBaseUrl);
    } else {
      _emarketBaseUrl = savedEmarketUrl;
    }

    final savedAiUrl = prefs.getString(_keyAiBaseUrl);
    if (savedAiUrl == null || savedAiUrl.contains('localhost') || savedAiUrl.contains('10.0.2.2')) {
      _aiBaseUrl = defaultAiBaseUrl;
      await prefs.setString(_keyAiBaseUrl, defaultAiBaseUrl);
    } else {
      _aiBaseUrl = savedAiUrl;
    }
  }

  static Future<void> updateEmarketBaseUrl(String newUrl) async {
    String url = newUrl.trim();
    if (!url.endsWith('/')) url += '/';
    _emarketBaseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmarketBaseUrl, url);
  }

  static Future<void> updateAiBaseUrl(String newUrl) async {
    String url = newUrl.trim();
    if (!url.endsWith('/')) url += '/';
    _aiBaseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiBaseUrl, url);
  }

  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmarketBaseUrl);
    await prefs.remove(_keyAiBaseUrl);
    _emarketBaseUrl = defaultEmarketBaseUrl;
    _aiBaseUrl = defaultAiBaseUrl;
  }
}
