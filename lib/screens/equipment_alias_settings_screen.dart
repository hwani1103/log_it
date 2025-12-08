import 'package:flutter/material.dart';
import '../services/equipment_alias_service.dart';

class EquipmentAliasSettingsScreen extends StatefulWidget {
  final EquipmentAliasService aliasService;

  const EquipmentAliasSettingsScreen({super.key, required this.aliasService});

  @override
  State<EquipmentAliasSettingsScreen> createState() => _EquipmentAliasSettingsScreenState();
}

class _EquipmentAliasSettingsScreenState extends State<EquipmentAliasSettingsScreen> {
  final TextEditingController _standardController = TextEditingController();
  final TextEditingController _aliasesController = TextEditingController();
  Map<String, List<String>> _rules = {};

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  @override
  void dispose() {
    _standardController.dispose();
    _aliasesController.dispose();
    super.dispose();
  }

  void _loadRules() {
    setState(() {
      _rules = widget.aliasService.getAllRules();
    });
  }

  Future<void> _addRule() async {
    final standard = _standardController.text.trim().toUpperCase();
    final aliasesText = _aliasesController.text.trim().toUpperCase();

    if (standard.isEmpty || aliasesText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 필드를 입력하세요')),
      );
      return;
    }

    final aliases = aliasesText
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();

    if (aliases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('변형될 텍스트를 입력하세요')),
      );
      return;
    }

    widget.aliasService.addRule(standard, aliases);
    await widget.aliasService.saveRules();

    setState(() {
      _standardController.clear();
      _aliasesController.clear();
      _loadRules();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('규칙이 추가되었습니다: $standard')),
      );
    }
  }

  Future<void> _editRule(String standard, List<String> currentAliases) async {
    final standardController = TextEditingController(text: standard);
    final aliasesController = TextEditingController(text: currentAliases.join(' '));

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('규칙 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: standardController,
              decoration: const InputDecoration(
                labelText: '저장될 텍스트',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: aliasesController,
              decoration: const InputDecoration(
                labelText: '변형될 텍스트',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'standard': standardController.text.trim().toUpperCase(),
                'aliases': aliasesController.text.trim().toUpperCase(),
              });
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );

    if (result != null) {
      final newStandard = result['standard']!;
      final aliasesText = result['aliases']!;

      if (newStandard.isEmpty || aliasesText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모든 필드를 입력하세요')),
          );
        }
        return;
      }

      final aliases = aliasesText
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();

      // 기존 규칙 삭제 (standard가 변경된 경우)
      if (standard != newStandard) {
        widget.aliasService.removeRule(standard);
      }

      widget.aliasService.addRule(newStandard, aliases);
      await widget.aliasService.saveRules();

      setState(() {
        _loadRules();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$newStandard 규칙이 수정되었습니다')),
        );
      }
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
          // 규칙 추가 영역
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _standardController,
                        decoration: const InputDecoration(
                          labelText: '저장될 텍스트',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _aliasesController,
                        decoration: const InputDecoration(
                          labelText: '변형될 텍스트',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addRule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('추가', style: TextStyle(fontSize: 16)),
                  ),
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
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rules.length,
                    itemBuilder: (context, index) {
                      final standard = _rules.keys.elementAt(index);
                      final aliases = _rules[standard]!;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    standard,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        color: Colors.blue,
                                        onPressed: () => _editRule(standard, aliases),
                                        tooltip: '수정',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20),
                                        color: Colors.red,
                                        onPressed: () => _deleteRule(standard),
                                        tooltip: '삭제',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                aliases.join(' '),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
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
