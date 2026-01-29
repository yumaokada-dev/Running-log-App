import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';

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
        // ★ここを水色（Cyan）ベースに変更
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
        useMaterial3: true,
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
  
  List<double> _weeklyDistance = List.filled(7, 0.0);
  List<String> _weekLabels = [];
  Map<DateTime, int> _calendarData = {};

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _runRecords = prefs.getStringList('run_data') ?? [];
      _calculateStats();
    });
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('run_data', _runRecords);
    _calculateStats();
  }

  void _calculateStats() {
    double tempTotal = 0.0;
    List<double> tempWeekly = List.filled(7, 0.0);
    List<String> tempLabels = [];
    Map<DateTime, int> tempCalendar = {};
    
    final now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      tempLabels.add("${date.month}/${date.day}");
    }

    for (var record in _runRecords) {
      try {
        final parts = record.split(' : ');
        if (parts.length >= 2) {
          final dateStr = parts[0]; 
          final distStr = parts[1].replaceAll(' km', '').trim();
          final distance = double.tryParse(distStr) ?? 0.0;

          tempTotal += distance;

          final recordDateParts = dateStr.split('/');
          if (recordDateParts.length == 3) {
            final year = int.parse(recordDateParts[0]);
            final month = int.parse(recordDateParts[1]);
            final day = int.parse(recordDateParts[2]);
            
            final normalizedDate = DateTime(year, month, day);
            tempCalendar[normalizedDate] = (tempCalendar[normalizedDate] ?? 0) + distance.toInt();

            final recordDate = DateTime(year, month, day);
            final diff = now.difference(recordDate).inDays;
            if (diff >= 0 && diff < 7) {
              int graphIndex = 6 - diff;
              tempWeekly[graphIndex] += distance;
            }
          }
        }
      } catch (e) {
        debugPrint('Error: $record');
      }
    }

    setState(() {
      _totalDistance = tempTotal;
      _weeklyDistance = tempWeekly;
      _weekLabels = tempLabels;
      _calendarData = tempCalendar;
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
          title: Text(index == null ? 'Record Run' : 'Edit Run'),
          content: TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Distance (km)',
              suffixText: 'km',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
                      _runRecords[index] = "${parts[0]} : $inputDistance km";
                    }
                    _saveRecords();
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
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
        title: const Text('MY RUN LOG', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.cyan, // ★ヘッダーを水色に
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ■ 1. 合計エリア
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.cyan.shade50, // ★背景を薄い水色に
              child: Column(
                children: [
                  const Text('TOTAL DISTANCE', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('${_totalDistance.toStringAsFixed(1)} km', 
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.cyan) // ★文字も水色
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 120,
                    child: BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                int index = value.toInt();
                                if (index >= 0 && index < _weekLabels.length) {
                                  return Text(_weekLabels[index], style: const TextStyle(fontSize: 10, color: Colors.grey));
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _weeklyDistance.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value,
                                color: entry.value > 0 ? Colors.cyan : Colors.grey.shade300, // ★棒グラフも水色
                                width: 12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ■ 2. カレンダー
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CONSISTENCY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  HeatMap(
                    datasets: _calendarData,
                    colorMode: ColorMode.opacity,
                    showText: false,
                    scrollable: true,
                    colorsets: const {
                      1: Colors.cyan, // ★カレンダーの「草」も水色
                    },
                    onClick: (value) {},
                    startDate: DateTime.now().subtract(const Duration(days: 60)),
                    endDate: DateTime.now().add(const Duration(days: 14)),
                    size: 20,
                    fontSize: 12,
                    defaultColor: Colors.grey.shade200,
                    textColor: Colors.black,
                  ),
                ],
              ),
            ),

            const Divider(),

            // ■ 3. リスト
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _runRecords.length,
              itemBuilder: (context, index) {
                final record = _runRecords[index];
                final parts = record.split(' : ');
                return ListTile(
                  leading: const Icon(Icons.run_circle, color: Colors.cyan, size: 30), // ★アイコンも水色
                  title: Text(parts.length > 1 ? parts[1] : '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(parts[0]),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                    onPressed: () => _showRecordDialog(index: index),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRecordDialog(),
        backgroundColor: Colors.cyan, // ★追加ボタンも水色
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}