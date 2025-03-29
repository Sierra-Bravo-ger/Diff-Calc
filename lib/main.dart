import 'package:flutter/material.dart';

void main() {
  runApp(const DiffApp());
}

class DiffApp extends StatelessWidget {
  const DiffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diff-Korrektur',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const DiffForm(),
    );
  }
}

class DiffForm extends StatefulWidget {
  const DiffForm({super.key});

  @override
  State<DiffForm> createState() => _DiffFormState();
}

class _DiffFormState extends State<DiffForm> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _results = {};
  final ScrollController _leftScroll = ScrollController();
  final ScrollController _rightScroll = ScrollController();
  bool _isSyncing = false;

  final List<String> _fields = [
    "WBC",
    "STAB", "SEG", "META", "MYELO", "PROMYELO",
    "EO", "BASO", "MONO", "LYMPH",
    "LYMPH-RE", "LYMPH-AT", "BLAST", "KERNSCHATTEN"
  ];

  double _n = 0.0;

  @override
  void initState() {
    for (var key in _fields) {
      _controllers[key] = TextEditingController();
    }

    _leftScroll.addListener(() {
      if (_isSyncing) return;
      _isSyncing = true;
      _rightScroll.jumpTo(_leftScroll.offset);
      _isSyncing = false;
    });

    _rightScroll.addListener(() {
      if (_isSyncing) return;
      _isSyncing = true;
      _leftScroll.jumpTo(_rightScroll.offset);
      _isSyncing = false;
    });

    super.initState();
  }

  @override
  void dispose() {
    for (var ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _leftScroll.dispose();
    _rightScroll.dispose();
    super.dispose();
  }

  void _reset() {
    for (var ctrl in _controllers.values) {
      ctrl.clear();
    }
    setState(() {
      _results.clear();
      _n = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color nColor = _n == 0
        ? Colors.grey.shade200
        : _n >= 100
            ? Colors.green.shade100
            : Colors.red.shade100;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Diff-Korrektur Rechner"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _leftScroll,
                      children: [
                        for (var key in _fields)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: TextField(
                              controller: _controllers[key],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: key == "WBC" ? "WBC [10³/µl]" : "$key [%]",
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ListView(
                      controller: _rightScroll,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: TextField(
                            readOnly: true,
                            controller: TextEditingController(text: _n.toStringAsFixed(2)),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: "n = Summe [%]",
                              filled: true,
                              fillColor: nColor,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        for (var key in _fields)
                          if (key != "WBC")
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: TextField(
                                readOnly: true,
                                controller: TextEditingController(text: _results[key] ?? ""),
                                decoration: InputDecoration(
                                  labelText: "$key# [10³/µl]",
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: _calculate,
                  child: const Text("Berechnen"),
                ),
                const SizedBox(width: 20),
                OutlinedButton(
                  onPressed: _reset,
                  child: const Text("Zurücksetzen"),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _calculate() {
    double wbc = double.tryParse(_controllers["WBC"]?.text.replaceAll(',', '.') ?? "") ?? 0.0;
    if (wbc <= 0) {
      setState(() {
        _results.clear();
        _results["WBC"] = "Ungültiger WBC-Wert";
        _n = 0;
      });
      return;
    }

    double sum = 0.0;
    final Map<String, double?> values = {};

    for (var key in _fields) {
      if (key != "WBC") {
        final input = _controllers[key]?.text.replaceAll(',', '.');
        final parsed = double.tryParse(input ?? "");
        if (parsed != null) {
          values[key] = parsed;
          sum += parsed;
        } else {
          values[key] = null;
        }
      }
    }

    if (sum == 0) {
      setState(() {
        _results.clear();
        _results["WBC"] = "Keine gültigen Prozentwerte";
        _n = 0;
      });
      return;
    }

    final Map<String, String> newResults = {};

    for (var key in _fields) {
      if (key != "WBC") {
        final percent = values[key];
        if (percent != null) {
          final rel = percent / sum;
          final abs = (wbc * rel * 1);
          newResults[key] = abs.toStringAsFixed(2);
        } else {
          newResults[key] = "---";
        }
      }
    }

    setState(() {
      _results.clear();
      _results.addAll(newResults);
      _n = sum;
    });
  }
}
