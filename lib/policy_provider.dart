import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import 'file_metadata_service.dart';

class PolicyProvider extends ChangeNotifier {
  List<String> _availableLabels = [];
  Map<String, String> _fileLabels = {}; // file path -> label
  Map<String, String> _labelIcons = {}; // label -> icon path
  bool _isLoading = true;
  final FileMetadataService _metadataService = FileMetadataService();

  PolicyProvider() {
    _loadPolicies();
  }

  bool get isLoading => _isLoading;

  // Get available labels from policies
  List<String> getAvailableLabels() {
    return _availableLabels;
  }

  // Check if manual labels are available
  bool hasManualLabelsAvailable() {
    return _availableLabels.isNotEmpty;
  }

  // Get label for a file
  String? getLabelForFile(String filePath) {
    return _fileLabels[_normalizePath(filePath)];
  }

  // Get icon for a label
  String? getIconForLabel(String label) {
    return _labelIcons[label];
  }

  // Set icon for a label
  Future<bool> setIconForLabel(String label, String iconPath) async {
    if (_availableLabels.contains(label)) {
      _labelIcons[label] = iconPath;
      await _saveLabelIcons();
      notifyListeners();
      return true;
    }
    return false;
  }

  // Apply label to file
  Future<bool> applyLabelToFile(String filePath, String label) async {
    if (_availableLabels.contains(label)) {
      final normalizedPath = _normalizePath(filePath);

      // First, try to write metadata to the actual file
      final metadataSuccess =
          await _metadataService.writeMetadataToFile(filePath, label);

      // Store in our app's storage as well (as backup)
      _fileLabels[normalizedPath] = label;
      await _saveFileLabels();

      notifyListeners();
      return metadataSuccess;
    }
    return false;
  }

  // Remove label from file
  Future<bool> removeLabelFromFile(String filePath) async {
    final normalizedPath = _normalizePath(filePath);
    if (_fileLabels.containsKey(normalizedPath)) {
      // Remove from the actual file
      await _metadataService.removeMetadataFromFile(filePath);

      // Remove from our app's storage
      _fileLabels.remove(normalizedPath);
      await _saveFileLabels();

      notifyListeners();
      return true;
    }
    return false;
  }

  // Add a new label
  Future<bool> addLabel(String label) async {
    if (!_availableLabels.contains(label)) {
      _availableLabels.add(label);
      await _saveLabels();
      notifyListeners();
      return true;
    }
    return false;
  }

  // Remove a label
  Future<bool> removeLabel(String label) async {
    if (_availableLabels.contains(label)) {
      _availableLabels.remove(label);

      // Remove this label from all files
      final filesToUpdate = <String>[];
      _fileLabels.forEach((key, value) {
        if (value == label) {
          filesToUpdate.add(key);
        }
      });

      for (final filePath in filesToUpdate) {
        await _metadataService.removeMetadataFromFile(filePath);
        _fileLabels.remove(filePath);
      }

      await _saveLabels();
      await _saveFileLabels();
      notifyListeners();
      return true;
    }
    return false;
  }

  // Normalize file path for consistent storage
  String _normalizePath(String filePath) {
    return path.normalize(filePath);
  }

  // Load policies from local storage
  Future<void> _loadPolicies() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load available labels
      final labelsJson = prefs.getString('available_labels');
      if (labelsJson != null) {
        final List<dynamic> decoded = jsonDecode(labelsJson);
        _availableLabels = decoded.map((e) => e.toString()).toList();
      } else {
        // Default labels if none are stored
        _availableLabels = [
          'Confidential',
          'Public',
          'Internal Use Only',
          'Restricted',
        ];
        await prefs.setString('available_labels', jsonEncode(_availableLabels));
      }

      // Load file labels
      final fileLabelsJson = prefs.getString('file_labels');
      if (fileLabelsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(fileLabelsJson);
        _fileLabels =
            decoded.map((key, value) => MapEntry(key, value.toString()));
      }

      // Load label icons
      final labelIconsJson = prefs.getString('label_icons');
      if (labelIconsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(labelIconsJson);
        _labelIcons =
            decoded.map((key, value) => MapEntry(key, value.toString()));
      } else {
        // Default icons for labels
        _labelIcons = {
          'Confidential': 'assets/icons/confidential.png',
          'Public': 'assets/icons/public.png',
          'Internal Use Only': 'assets/icons/internal.png',
          'Restricted': 'assets/icons/restricted.png',
        };
        await prefs.setString('label_icons', jsonEncode(_labelIcons));
      }
    } catch (e) {
      print('Error loading policies: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save labels to local storage
  Future<void> _saveLabels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('available_labels', jsonEncode(_availableLabels));
    } catch (e) {
      print('Error saving labels: $e');
    }
  }

  // Save file labels to local storage
  Future<void> _saveFileLabels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('file_labels', jsonEncode(_fileLabels));
    } catch (e) {
      print('Error saving file labels: $e');
    }
  }

  // Save label icons to local storage
  Future<void> _saveLabelIcons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('label_icons', jsonEncode(_labelIcons));
    } catch (e) {
      print('Error saving label icons: $e');
    }
  }

  // Get all files with a specific label
  List<String> getFilesWithLabel(String label) {
    return _fileLabels.entries
        .where((entry) => entry.value == label)
        .map((entry) => entry.key)
        .toList();
  }

  // Get all labeled files
  Map<String, String> getAllLabeledFiles() {
    return Map.from(_fileLabels);
  }

  // Check if a file has metadata directly in the file
  Future<bool> checkFileHasMetadata(String filePath) async {
    final label = await _metadataService.readMetadataFromFile(filePath);
    return label != null;
  }

  // Sync file labels with metadata
  Future<void> syncFileLabelsWithMetadata() async {
    // For each file in our app's storage, check if it has metadata
    // and update our storage accordingly
    for (final entry in _fileLabels.entries.toList()) {
      final filePath = entry.key;
      final file = File(filePath);

      if (await file.exists()) {
        final metadataLabel =
            await _metadataService.readMetadataFromFile(filePath);

        if (metadataLabel != null && metadataLabel != entry.value) {
          // Update our storage to match the file's metadata
          _fileLabels[filePath] = metadataLabel;
        } else if (metadataLabel == null) {
          // Write our label to the file's metadata
          await _metadataService.writeMetadataToFile(filePath, entry.value);
        }
      }
    }

    await _saveFileLabels();
    notifyListeners();
  }
}
