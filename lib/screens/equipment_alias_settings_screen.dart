import 'package:flutter/material.dart';
import '../services/equipment_alias_service.dart';

class EquipmentAliasSettingsScreen extends StatefulWidget {
  final EquipmentAliasService aliasService;

  const EquipmentAliasSettingsScreen({super.key, required this.aliasService});

  @override
  State<EquipmentAliasSettingsScreen> createState() => _EquipmentAliasSettingsScreenState();
}

class _EquipmentAliasSettingsScreenState extends State<EquipmentAliasSettingsScreen> {
  final TextEditingController _ruleController = TextEditingController();
  Map<String, List<String>> _rules = {};

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  @override
  void dispose() {
    _ruleController.dispose();
    super.dispose();
  }

  void _loadRules() {
    setState(() {
      _rules = widget.aliasService.getAllRules();
    });
  }

  Future<void> _addRule() async {
    final text = _ruleController.text.trim();
    if (text.isEmpty) return;

    final parsed = EquipmentAliasService.parseRuleText(text);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 형식이 아닙니다.\n예: LIA : LI LT LIC LIA')),
      );
      return;
    }

    final standard = parsed.keys.first;
    final aliases = parsed.values.first;

    widget.aliasService.addRule(standard, aliases);
    await widget.aliasService.saveRules();

    setState(() {
      _ruleController.clear();
      _loadRules();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('규칙이 추가되었습니다: $standard')),
      );
    }
  }

  Future<void> _deleteRule(String standard) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('규칙 삭제'),
        content: Text('$standard 규칙을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.aliasService.removeRule(standard);
      await widget.aliasService.saveRules();

      setState(() {
        _loadRules();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$standard 규칙이 삭제되었습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설비명 변환 규칙'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 설명
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '설비명 변환 규칙 설정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '입력 형식: 저장될텍스트 : 변형될텍스트들\n예: LIA : LI LT LIC LIA',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          // 규칙 추가
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ruleController,
                    decoration: const InputDecoration(
                      labelText: '새 규칙 추가',
                      hintText: 'LIA : LI LT LIC LIA',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addRule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  child: const Text('추가'),
                ),
              ],
            ),
          ),
          // 규칙 목록
          Expanded(
            child: _rules.isEmpty
                ? const Center(
                    child: Text(
                      '등록된 규칙이 없습니다',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _rules.length,
                    itemBuilder: (context, index) {
                      final standard = _rules.keys.elementAt(index);
                      final aliases = _rules[standard]!;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            standard,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: aliases.map((alias) {
                                return Chip(
                                  label: Text(
                                    alias,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                );
                              }).toList(),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteRule(standard),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
