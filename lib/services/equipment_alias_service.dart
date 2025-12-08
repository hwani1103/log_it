import 'package:shared_preferences/shared_preferences.dart';

class EquipmentAliasService {
  static const String _storageKey = 'equipment_alias_rules';

  // 싱글톤 인스턴스
  static final EquipmentAliasService _instance = EquipmentAliasService._internal();
  factory EquipmentAliasService() => _instance;

  // 기본 규칙
  static const Map<String, List<String>> _defaultRules = {
    'LIA': ['LI', 'LT', 'LIC', 'LIA'],
    'TIC': ['TIC', 'TI', 'TIA'],
    'FI': ['FI', 'FT', 'FQIL'],
    'FV': ['FV', 'FIC', 'FQILC'],
    'XC': ['XC', 'XV'],
  };

  // 현재 로드된 규칙 (캐시)
  Map<String, List<String>> _rules = {};

  // 역방향 맵 (빠른 검색용: 변형 → 표준)
  Map<String, String> _aliasToStandard = {};

  // 로드 완료 여부
  bool _isLoaded = false;

  EquipmentAliasService._internal() {
    _initializeDefaultRules();
  }

  void _initializeDefaultRules() {
    _rules = Map.from(_defaultRules);
    _buildReverseMap();
  }

  void _buildReverseMap() {
    _aliasToStandard.clear();
    for (var entry in _rules.entries) {
      final standard = entry.key;
      for (var alias in entry.value) {
        _aliasToStandard[alias.toUpperCase()] = standard;
      }
    }
  }

  // SharedPreferences에서 규칙 로드
  Future<void> loadRules() async {
    if (_isLoaded) return; // 이미 로드되었으면 건너뛰기

    try {
      final prefs = await SharedPreferences.getInstance();
      final rulesJson = prefs.getStringList(_storageKey);

      if (rulesJson != null && rulesJson.isNotEmpty) {
        _rules.clear();
        for (var ruleStr in rulesJson) {
          final parts = ruleStr.split(':');
          if (parts.length == 2) {
            final standard = parts[0].trim();
            final aliases = parts[1].trim().split(' ').where((s) => s.isNotEmpty).toList();
            _rules[standard] = aliases;
          }
        }
      } else {
        // 저장된 규칙이 없으면 기본 규칙 저장
        _initializeDefaultRules();
        await saveRules();
      }

      _buildReverseMap();
      _isLoaded = true;
    } catch (e) {
      print('규칙 로드 실패: $e');
      _initializeDefaultRules();
      _isLoaded = true;
    }
  }

  // 규칙 저장
  Future<void> saveRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rulesJson = _rules.entries
          .map((e) => '${e.key}:${e.value.join(' ')}')
          .toList();
      await prefs.setStringList(_storageKey, rulesJson);
      _buildReverseMap();
    } catch (e) {
      print('규칙 저장 실패: $e');
    }
  }

  // 규칙 추가
  void addRule(String standard, List<String> aliases) {
    _rules[standard.toUpperCase()] = aliases.map((a) => a.toUpperCase()).toList();
  }

  // 규칙 삭제
  void removeRule(String standard) {
    _rules.remove(standard.toUpperCase());
  }

  // 모든 규칙 가져오기
  Map<String, List<String>> getAllRules() {
    return Map.from(_rules);
  }

  // prefix를 표준 형식으로 변환
  String getStandardPrefix(String prefix) {
    final upper = prefix.toUpperCase();
    return _aliasToStandard[upper] ?? upper;
  }

  // 텍스트 파싱 (사용자 입력: "LIA : LI LT LIC LIA")
  static Map<String, List<String>>? parseRuleText(String text) {
    try {
      final parts = text.split(':');
      if (parts.length != 2) return null;

      final standard = parts[0].trim().toUpperCase();
      final aliases = parts[1]
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .map((s) => s.toUpperCase())
          .toList();

      if (standard.isEmpty || aliases.isEmpty) return null;

      return {standard: aliases};
    } catch (e) {
      return null;
    }
  }
}
