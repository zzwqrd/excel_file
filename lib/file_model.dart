class FileModel {
  final String id;
  final String name;
  final String path;
  final int size;
  final String type;
  final String? mimeType;
  String? manualLabel;
  DateTime? lastAccessed;

  FileModel({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.type,
    this.mimeType,
    this.manualLabel,
    this.lastAccessed,
  });

  FileModel copyWith({
    String? id,
    String? name,
    String? path,
    int? size,
    String? type,
    String? mimeType,
    String? manualLabel,
    DateTime? lastAccessed,
  }) {
    return FileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      type: type ?? this.type,
      mimeType: mimeType ?? this.mimeType,
      manualLabel: manualLabel ?? this.manualLabel,
      lastAccessed: lastAccessed ?? this.lastAccessed,
    );
  }

  // Get file icon based on type
  String getFileIcon() {
    switch (type) {
      case 'excel':
        return 'assets/icons/excel.png';
      case 'document':
        return 'assets/icons/document.png';
      case 'pdf':
        return 'assets/icons/pdf.png';
      case 'image':
        return 'assets/icons/image.png';
      case 'video':
        return 'assets/icons/video.png';
      case 'audio':
        return 'assets/icons/audio.png';
      case 'presentation':
        return 'assets/icons/presentation.png';
      case 'archive':
        return 'assets/icons/archive.png';
      default:
        return 'assets/icons/file.png';
    }
  }

  // Format file size
  String getFormattedSize() {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
