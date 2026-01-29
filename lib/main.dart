import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Running Log',
      theme: ThemeData(
        // 全体の色味を少し大人っぽく「インディゴ」に
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        // ★エラーの原因だった cardTheme の行を削除しました
      ),
      home: const RunningHomePage(),
    );
  }
}

class RunningHomePage extends StatefulWidget {
  const RunningHomePage({super.key});

  @override
  State<RunningHomePage> createState() => _RunningHomePageState();
}

class _RunningHomePageState extends State<RunningHomePage> {
  List<String> _runRecords = [];
  double _totalDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _runRecords = prefs.getStringList('run_data') ?? [];
      _calculateTotal();
    });
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('run_data', _runRecords);
    _calculateTotal();
  }

  void _calculateTotal() {
    double tempTotal = 0.0;
    for (var record in _runRecords) {
      try {
        final parts = record.split(' : ');
        if (parts.length >= 2) {
          final distanceStr = parts[1].replaceAll(' km', '').trim();
          final distance = double.tryParse(distanceStr) ?? 0.0;
          tempTotal += distance;
        }
      } catch (e) {
        debugPrint('Error parsing record: $record');
      }
    }
    setState(() {
      _totalDistance = tempTotal;
    });
  }

  final TextEditingController _textController = TextEditingController();

  void _showRecordDialog({int? index}) {
    if (index != null) {
      final parts = _runRecords[index].split(' : ');
      if (parts.length >= 2) {
        _textController.text = parts[1].replaceAll(' km', '').trim();
      }
    } else {
      _textController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(index == null ? '記録を追加' : '記録を修正'),
          content: TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: '距離 (km)',
              hintText: '例: 5.2',
              border: OutlineInputBorder(),
              suffixText: 'km',
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_textController.text.isNotEmpty) {
                  setState(() {
                    final inputDistance = _textController.text;
                    
                    if (index == null) {
                      final now = DateTime.now();
                      final dateStr = "${now.year}/${now.month}/${now.day}";
                      _runRecords.insert(0, "$dateStr : $inputDistance km");
                    } else {
                      final parts = _runRecords[index].split(' : ');
                      final datePart = parts[0];
                      _runRecords[index] = "$datePart : $inputDistance km";
                    }
                    
                    _saveRecords();
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('RUN LOG', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Column(
              children: [
                const Text('TOTAL DISTANCE',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 5),
                Text(
                  '${_totalDistance.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _runRecords.isEmpty
                ? const Center(child: Text('Let\'s Run!', style: TextStyle(fontSize: 20, color: Colors.grey)))
                : ListView.builder(
                    itemCount: _runRecords.length,
                    itemBuilder: (context, index) {
                      final record = _runRecords[index];
                      final parts = record.split(' : ');
                      final date = parts[0];
                      final distance = parts.length > 1 ? parts[1] : '';

                      return Card(
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.directions_run, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(distance, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          subtitle: Text(date, style: const TextStyle(color: Colors.grey)),
                          onTap: () {
                            _showRecordDialog(index: index);
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.grey),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('削除しますか？'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('キャンセル')),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _runRecords.removeAt(index);
                                          _saveRecords();
                                        });
                                        Navigator.pop(context);
                                      },
                                      child: const Text('削除', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecordDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Record'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}