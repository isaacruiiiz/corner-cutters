import 'dart:convert';

import 'package:flutter/services.dart';

/// Configuración en assets/config.json (claves de Supabase y web).
class AppConfig {
  final String supabaseUrl;
  final String supabaseKey;
  final String webUrl;
  final String contacto;
  /// Unidades de AdMob reales: {"android": {"rewarded": "...", "interstitial": "..."}, "ios": {...}}.
  final Map<String, dynamic> admob;
  const AppConfig({this.supabaseUrl = '', this.supabaseKey = '', this.webUrl = '', this.contacto = '', this.admob = const {}});

  /// Unidad de anuncio configurada, o null para usar las de prueba de Google.
  String? adUnit(String kind, String os) {
    final v = (admob[os] as Map?)?[kind] as String?;
    return v == null || v.trim().isEmpty ? null : v.trim();
  }

  bool get hasSupabase => supabaseUrl.startsWith('http') && supabaseKey.isNotEmpty;

  static AppConfig current = const AppConfig();

  static Future<AppConfig> load() async {
    try {
      final raw = await rootBundle.loadString('assets/config.json');
      final j = jsonDecode(raw) as Map<String, dynamic>;
      current = AppConfig(
        // Acepta también la URL de la API REST (…/rest/v1/) y la deja en la base.
        supabaseUrl: (j['supabaseUrl'] as String? ?? '').trim().replaceFirst(RegExp(r'/rest/v1/?$'), '').replaceFirst(RegExp(r'/$'), ''),
        supabaseKey: (j['supabaseKey'] as String? ?? '').trim(),
        webUrl: j['webUrl'] as String? ?? '',
        contacto: j['contacto'] as String? ?? '',
        admob: Map<String, dynamic>.from(j['admob'] as Map? ?? const {}),
      );
    } catch (_) {
      current = const AppConfig();
    }
    return current;
  }
}
