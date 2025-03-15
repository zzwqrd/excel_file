import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:mime/mime.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'file_model.dart';

class FileAccessService {
  // Get files from device storage with multiple file types
  Future<List<FileModel>> getFilesFromDevice(
      {List<String>? allowedExtensions}) async {
    final List<FileModel> files = [];

    // Request storage permission
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      print('Storage permission not granted');
      return files;
    }

    try {
      // Use FilePicker to get files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );

      if (result != null) {
        for (var file in result.files) {
          if (file.path != null) {
            final mimeType =
                lookupMimeType(file.path!) ?? 'application/octet-stream';
            final fileType = _getFileTypeFromMime(mimeType);

            files.add(
              FileModel(
                id: DateTime.now().millisecondsSinceEpoch.toString() +
                    file.name,
                name: file.name,
                path: file.path!,
                size: file.size,
                type: fileType,
                mimeType: mimeType,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error accessing files: $e');
    }

    return files;
  }

  // Get Excel files specifically
  Future<List<FileModel>> getExcelFilesFromDevice() async {
    return getFilesFromDevice(allowedExtensions: ['xlsx', 'xls', 'csv']);
  }

  // Open a file with the default app
  Future<OpenResult> openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      print('Open file result: ${result.type} - ${result.message}');
      return result;
    } catch (e) {
      print('Error opening file: $e');
      return OpenResult(
          type: ResultType.error, message: 'Could not open file: $e');
    }
  }

  // Open Excel file specifically
  Future<bool> openExcelFile(String filePath) async {
    try {
      // First try to use the system's default app
      final result = await openFile(filePath);

      if (result.type == ResultType.done) {
        return true;
      }

      // If that fails, try to use a URL scheme (for iOS)
      if (Platform.isIOS) {
        final uri = Uri.parse('ms-excel:ofv|u|$filePath');
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      }

      // If all else fails, try a generic content URI (for Android)
      if (Platform.isAndroid) {
        final uri = Uri.parse('content://$filePath');
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      }

      return false;
    } catch (e) {
      print('Error opening Excel file: $e');
      return false;
    }
  }

  // Get file type from path
  String getFileTypeFromPath(String filePath) {
    final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
    return _getFileTypeFromMime(mimeType);
  }

  // Get file type from MIME type
  String _getFileTypeFromMime(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return 'image';
    } else if (mimeType.startsWith('video/')) {
      return 'video';
    } else if (mimeType.startsWith('audio/')) {
      return 'audio';
    } else if (mimeType.startsWith('text/')) {
      return 'text';
    } else if (mimeType.contains('pdf')) {
      return 'pdf';
    } else if (mimeType.contains('excel') ||
        mimeType.contains('spreadsheet') ||
        mimeType.contains('csv')) {
      return 'excel';
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      return 'document';
    } else if (mimeType.contains('presentation') ||
        mimeType.contains('powerpoint')) {
      return 'presentation';
    } else if (mimeType.contains('zip') ||
        mimeType.contains('archive') ||
        mimeType.contains('compressed')) {
      return 'archive';
    }
    return 'other';
  }

  // Request storage permission
  Future<bool> _requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        print('Android SDK: ${androidInfo.version.sdkInt}');

        if (androidInfo.version.sdkInt >= 33) {
          // For Android 13 and above
          print('Requesting permissions for Android 13+');
          final photos = await Permission.photos.request();
          final videos = await Permission.videos.request();
          final audio = await Permission.audio.request();

          print(
              'Photos: ${photos.isGranted}, Videos: ${videos.isGranted}, Audio: ${audio.isGranted}');
          return photos.isGranted || videos.isGranted || audio.isGranted;
        } else if (androidInfo.version.sdkInt >= 30) {
          // For Android 11 and 12
          print('Requesting permissions for Android 11-12');
          final storage = await Permission.storage.request();
          final manageExternal =
              await Permission.manageExternalStorage.request();

          print(
              'Storage: ${storage.isGranted}, Manage External: ${manageExternal.isGranted}');
          return storage.isGranted || manageExternal.isGranted;
        } else {
          // For Android 10 and below
          print('Requesting permissions for Android 10 and below');
          final storage = await Permission.storage.request();

          print('Storage: ${storage.isGranted}');
          return storage.isGranted;
        }
      } else if (Platform.isIOS) {
        final photos = await Permission.photos.request();
        return photos.isGranted;
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }

    return false;
  }

  // Get recently accessed files from app's local storage
  Future<List<FileModel>> getRecentFiles() async {
    final List<FileModel> recentFiles = [];

    try {
      final directory = await getApplicationDocumentsDirectory();
      final recentFilesDir = Directory('${directory.path}/recent_files');

      if (await recentFilesDir.exists()) {
        final recentFilesJson =
            File('${recentFilesDir.path}/recent_files.json');
        if (await recentFilesJson.exists()) {
          // In a real app, you would parse the JSON and convert to FileModel objects
          // This is just a placeholder
        }
      }
    } catch (e) {
      print('Error getting recent files: $e');
    }

    return recentFiles;
  }

  // Extract a zip file
  Future<List<FileModel>> extractArchive(
      String archivePath, String destinationPath) async {
    final List<FileModel> extractedFiles = [];
    final archiveFile = File(archivePath);
    final destinationDir = Directory(destinationPath);

    if (!await destinationDir.exists()) {
      await destinationDir.create(recursive: true);
    }

    try {
      await ZipFile.extractToDirectory(
          zipFile: archiveFile, destinationDir: destinationDir);

      // Get the list of extracted files
      final files = await destinationDir.list().toList();
      for (var entity in files) {
        if (entity is File) {
          final file = entity;
          final mimeType =
              lookupMimeType(file.path) ?? 'application/octet-stream';
          final fileType = _getFileTypeFromMime(mimeType);

          extractedFiles.add(
            FileModel(
              id: DateTime.now().millisecondsSinceEpoch.toString() +
                  file.path.split('/').last,
              name: file.path.split('/').last,
              path: file.path,
              size: await file.length(),
              type: fileType,
              mimeType: mimeType,
            ),
          );
        }
      }
    } catch (e) {
      print('Error extracting archive: $e');
    }

    return extractedFiles;
  }

  // Share a file
  Future<void> shareFile(String filePath, String fileName) async {
    try {
      await Share.shareXFiles([XFile(filePath)],
          text: 'Sharing file: $fileName');
    } catch (e) {
      print('Error sharing file: $e');
    }
  }
}
