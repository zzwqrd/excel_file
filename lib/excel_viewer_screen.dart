import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import 'file_model.dart';

class ExcelViewerScreen extends StatefulWidget {
  final FileModel file;

  const ExcelViewerScreen({Key? key, required this.file}) : super(key: key);

  @override
  State<ExcelViewerScreen> createState() => _ExcelViewerScreenState();
}

class _ExcelViewerScreenState extends State<ExcelViewerScreen> {
  Excel? _excel;
  List<String> _sheetNames = [];
  String? _currentSheet;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExcelFile();
  }

  Future<void> _loadExcelFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await File(widget.file.path).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final sheetNames = excel.tables.keys.toList();

      setState(() {
        _excel = excel;
        _sheetNames = sheetNames;
        _currentSheet = sheetNames.isNotEmpty ? sheetNames.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load Excel file: ${e.toString()}';
        _isLoading = false;
      });
      print('Error loading Excel file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        actions: [
          if (_sheetNames.length > 1)
            PopupMenuButton<String>(
              onSelected: (sheetName) {
                setState(() {
                  _currentSheet = sheetName;
                });
              },
              itemBuilder: (context) => _sheetNames
                  .map((sheetName) => PopupMenuItem<String>(
                        value: sheetName,
                        child: Text(sheetName),
                      ))
                  .toList(),
              tooltip: 'Select Sheet',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text(_currentSheet ?? ''),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    if (_excel == null ||
        _currentSheet == null ||
        !_excel!.tables.containsKey(_currentSheet)) {
      return const Center(child: Text('No data available'));
    }

    final sheet = _excel!.tables[_currentSheet]!;
    final maxRows = sheet.maxRows;
    final maxCols = sheet.maxCols;

    // If the sheet is empty
    if (maxRows == 0 || maxCols == 0) {
      return const Center(child: Text('This sheet is empty'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: List.generate(
            maxCols,
            (colIndex) => DataColumn(
              label: Text(_getColumnName(colIndex)),
            ),
          ),
          rows: List.generate(
            maxRows,
            (rowIndex) => DataRow(
              cells: List.generate(
                maxCols,
                (colIndex) {
                  final cell = sheet.cell(CellIndex.indexByColumnRow(
                      columnIndex: colIndex, rowIndex: rowIndex));
                  return DataCell(Text(cell.value?.toString() ?? ''));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Convert column index to Excel column name (A, B, C, ..., Z, AA, AB, ...)
  String _getColumnName(int columnIndex) {
    String columnName = '';
    int dividend = columnIndex + 1;
    int modulo;

    while (dividend > 0) {
      modulo = (dividend - 1) % 26;
      columnName = String.fromCharCode(65 + modulo) + columnName;
      dividend = (dividend - modulo) ~/ 26;
    }

    return columnName;
  }
}
