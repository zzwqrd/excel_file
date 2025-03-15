import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'excel_viewer_screen.dart';
import 'file_access_service.dart';
import 'file_model.dart';
import 'file_viewer_screen.dart';
import 'label_icon_mapping.dart';
import 'label_icon_screen.dart';
import 'manual_labelling_screen.dart';
import 'policy_provider.dart';

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({Key? key}) : super(key: key);

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen>
    with SingleTickerProviderStateMixin {
  final FileAccessService _fileAccessService = FileAccessService();
  List<FileModel> _files = [];
  bool _isLoading = false;
  late TabController _tabController;
  String _currentFilter = 'all';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecentFiles();
    _syncFileMetadata();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _syncFileMetadata() async {
    final policyProvider = Provider.of<PolicyProvider>(context, listen: false);
    await policyProvider.syncFileLabelsWithMetadata();
  }

  Future<void> _loadRecentFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final recentFiles = await _fileAccessService.getRecentFiles();
      setState(() {
        _files = recentFiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load recent files');
    }
  }

  Future<void> _refreshFiles() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Sync metadata with files
      await _syncFileMetadata();

      setState(() {
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        _isRefreshing = false;
      });
      _showErrorSnackBar('Failed to refresh files');
    }
  }

  Future<void> _pickFiles({List<String>? allowedExtensions}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await _fileAccessService.getFilesFromDevice(
        allowedExtensions: allowedExtensions,
      );
      setState(() {
        _files = [..._files, ...files];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to access files');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  List<FileModel> _getFilteredFiles() {
    if (_currentFilter == 'all') {
      return _files;
    } else {
      return _files.where((file) => file.type == _currentFilter).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final policyProvider = Provider.of<PolicyProvider>(context);
    final filteredFiles = _getFilteredFiles();

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Browser'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Files'),
            Tab(text: 'Labeled Files'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshFiles,
            tooltip: 'Refresh Metadata',
          ),
          IconButton(
            icon: const Icon(Icons.label),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LabelIconScreen(),
                ),
              ).then((_) => _refreshFiles());
            },
            tooltip: 'Manage Labels',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _currentFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'all',
                child: Text('All Files'),
              ),
              const PopupMenuItem<String>(
                value: 'excel',
                child: Text('Excel Files'),
              ),
              const PopupMenuItem<String>(
                value: 'document',
                child: Text('Documents'),
              ),
              const PopupMenuItem<String>(
                value: 'pdf',
                child: Text('PDFs'),
              ),
              const PopupMenuItem<String>(
                value: 'image',
                child: Text('Images'),
              ),
              const PopupMenuItem<String>(
                value: 'video',
                child: Text('Videos'),
              ),
              const PopupMenuItem<String>(
                value: 'audio',
                child: Text('Audio'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading || policyProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    // All Files Tab
                    filteredFiles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('No files found'),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => _pickFiles(),
                                  child: const Text('Browse Files'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredFiles.length,
                            itemBuilder: (context, index) {
                              final file = filteredFiles[index];
                              final fileLabel =
                                  policyProvider.getLabelForFile(file.path);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: ListTile(
                                  leading: _getFileIcon(file.type, fileLabel),
                                  title: Text(file.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Size: ${file.getFormattedSize()}'),
                                      if (file.lastAccessed != null)
                                        Text(
                                            'Last accessed: ${DateFormat('yyyy-MM-dd HH:mm').format(file.lastAccessed!)}'),
                                      if (fileLabel != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Color(LabelIconMapping
                                                    .getColorForLabel(
                                                        fileLabel))
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            fileLabel,
                                            style: TextStyle(
                                              color: Color(LabelIconMapping
                                                  .getColorForLabel(fileLabel)),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'open') {
                                        _openFile(file);
                                      } else if (value == 'openExternal') {
                                        _openFileExternal(file);
                                      } else if (value == 'preview') {
                                        _previewFile(file);
                                      } else if (value == 'dataMind') {
                                        _openDataMind(context, file);
                                      } else if (value == 'removeLabel') {
                                        await policyProvider
                                            .removeLabelFromFile(file.path);
                                        setState(() {});
                                      } else if (value == 'share') {
                                        await _fileAccessService.shareFile(
                                            file.path, file.name);
                                      } else if (value == 'extract' &&
                                          file.type == 'archive') {
                                        final directory =
                                            await getApplicationDocumentsDirectory();
                                        final extractPath =
                                            '${directory.path}/extracted/${file.name}';
                                        await _fileAccessService.extractArchive(
                                            file.path, extractPath);
                                        _showSuccessSnackBar(
                                            'Archive extracted successfully');
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (file.type == 'excel')
                                        const PopupMenuItem<String>(
                                          value: 'preview',
                                          child: Text('Preview in App'),
                                        ),
                                      const PopupMenuItem<String>(
                                        value: 'open',
                                        child: Text('Open'),
                                      ),
                                      if (file.type == 'excel')
                                        const PopupMenuItem<String>(
                                          value: 'openExternal',
                                          child: Text('Open in Excel'),
                                        ),
                                      const PopupMenuItem<String>(
                                        value: 'dataMind',
                                        child: Text('Data Mind'),
                                      ),
                                      if (fileLabel != null)
                                        const PopupMenuItem<String>(
                                          value: 'removeLabel',
                                          child: Text('Remove Label'),
                                        ),
                                      const PopupMenuItem<String>(
                                        value: 'share',
                                        child: Text('Share'),
                                      ),
                                      if (file.type == 'archive')
                                        const PopupMenuItem<String>(
                                          value: 'extract',
                                          child: Text('Extract'),
                                        ),
                                    ],
                                  ),
                                  onTap: () {
                                    _openFile(file);
                                  },
                                ),
                              );
                            },
                          ),

                    // Labeled Files Tab
                    _buildLabeledFilesTab(policyProvider),
                  ],
                ),
                if (_isRefreshing)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'pickExcel',
            onPressed: () =>
                _pickFiles(allowedExtensions: ['xlsx', 'xls', 'csv']),
            child: const Icon(Icons.table_chart),
            tooltip: 'Pick Excel Files',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'pickAny',
            onPressed: () => _pickFiles(),
            child: const Icon(Icons.add),
            tooltip: 'Pick Any Files',
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledFilesTab(PolicyProvider policyProvider) {
    final labeledFilePaths = policyProvider.getAllLabeledFiles();
    final labeledFiles = _files
        .where((file) => policyProvider.getLabelForFile(file.path) != null)
        .toList();

    // Add files that are labeled but not in the current list
    for (var filePath in labeledFilePaths.keys) {
      if (!_files.any((file) => file.path == filePath)) {
        final file = File(filePath);
        if (file.existsSync()) {
          try {
            final fileStats = file.statSync();
            final fileName = filePath.split('/').last;
            final fileSize = fileStats.size;
            final fileType = _fileAccessService.getFileTypeFromPath(filePath);

            labeledFiles.add(
              FileModel(
                id: DateTime.now().millisecondsSinceEpoch.toString() + fileName,
                name: fileName,
                path: filePath,
                size: fileSize,
                type: fileType,
              ),
            );
          } catch (e) {
            print('Error loading labeled file: $e');
          }
        }
      }
    }

    if (labeledFiles.isEmpty) {
      return const Center(
        child: Text('No labeled files yet'),
      );
    }

    // Group files by label
    final Map<String, List<FileModel>> filesByLabel = {};
    for (var file in labeledFiles) {
      final label = policyProvider.getLabelForFile(file.path);
      if (label != null) {
        if (!filesByLabel.containsKey(label)) {
          filesByLabel[label] = [];
        }
        filesByLabel[label]!.add(file);
      }
    }

    return ListView.builder(
      itemCount: filesByLabel.length,
      itemBuilder: (context, index) {
        final label = filesByLabel.keys.elementAt(index);
        final files = filesByLabel[label]!;

        return ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: Color(LabelIconMapping.getColorForLabel(label))
                .withOpacity(0.2),
            child: Icon(
              Icons.label,
              color: Color(LabelIconMapping.getColorForLabel(label)),
            ),
          ),
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${files.length} files'),
          children: files
              .map((file) => ListTile(
                    leading: _getFileIcon(file.type, label),
                    title: Text(file.name),
                    subtitle: Text('Size: ${file.getFormattedSize()}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () {
                        _openFile(file);
                      },
                    ),
                    onTap: () {
                      _openFile(file);
                    },
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _getFileIcon(String fileType, String? label) {
    if (label != null) {
      // Use label-based icon/color
      return CircleAvatar(
        backgroundColor:
            Color(LabelIconMapping.getColorForLabel(label)).withOpacity(0.2),
        child: Icon(
          _getIconDataForFileType(fileType),
          color: Color(LabelIconMapping.getColorForLabel(label)),
        ),
      );
    } else {
      // Use default file type icon
      IconData iconData = _getIconDataForFileType(fileType);
      Color iconColor = _getColorForFileType(fileType);

      return CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.2),
        child: Icon(iconData, color: iconColor),
      );
    }
  }

  IconData _getIconDataForFileType(String fileType) {
    switch (fileType) {
      case 'excel':
        return Icons.table_chart;
      case 'document':
        return Icons.description;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      case 'presentation':
        return Icons.slideshow;
      case 'archive':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getColorForFileType(String fileType) {
    switch (fileType) {
      case 'excel':
        return Colors.green;
      case 'document':
        return Colors.blue;
      case 'pdf':
        return Colors.red;
      case 'image':
        return Colors.purple;
      case 'video':
        return Colors.orange;
      case 'audio':
        return Colors.pink;
      case 'presentation':
        return Colors.deepOrange;
      case 'archive':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  void _openFile(FileModel file) async {
    // Update last accessed time
    setState(() {
      final index = _files.indexWhere((f) => f.id == file.id);
      if (index != -1) {
        _files[index] = _files[index].copyWith(lastAccessed: DateTime.now());
      }
    });

    if (file.type == 'excel') {
      // For Excel files, show a dialog to choose how to open
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Open Excel File'),
          content: const Text('How would you like to open this Excel file?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _previewFile(file);
              },
              child: const Text('Preview in App'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openFileExternal(file);
              },
              child: const Text('Open in Excel'),
            ),
          ],
        ),
      );
    } else if (file.type == 'pdf' || file.type == 'image') {
      // For PDF and image files, use custom viewers
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FileViewerScreen(file: file),
        ),
      );
    } else {
      // For other file types, use the system's default app
      _openFileExternal(file);
    }
  }

  void _openFileExternal(FileModel file) async {
    if (file.type == 'excel') {
      final success = await _fileAccessService.openExcelFile(file.path);
      if (!success) {
        _showErrorSnackBar(
            'Could not open Excel file. Make sure you have an Excel app installed.');
      }
    } else {
      final result = await _fileAccessService.openFile(file.path);
      if (result.type != ResultType.done) {
        _showErrorSnackBar('Could not open file: ${result.message}');
      }
    }
  }

  void _previewFile(FileModel file) {
    if (file.type == 'excel') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExcelViewerScreen(file: file),
        ),
      );
    } else if (file.type == 'pdf' || file.type == 'image') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FileViewerScreen(file: file),
        ),
      );
    } else {
      _showErrorSnackBar('Preview not available for this file type');
    }
  }

  void _openDataMind(BuildContext context, FileModel file) async {
    final policyProvider = Provider.of<PolicyProvider>(context, listen: false);

    if (!policyProvider.hasManualLabelsAvailable()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No manual labels are available in policies'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManualLabellingScreen(file: file),
      ),
    );

    if (result == true) {
      // Refresh the UI and sync metadata
      _refreshFiles();
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// class FileBrowserScreen extends StatefulWidget {
//   const FileBrowserScreen({Key? key}) : super(key: key);
//
//   @override
//   State<FileBrowserScreen> createState() => _FileBrowserScreenState();
// }
//
// class _FileBrowserScreenState extends State<FileBrowserScreen>
//     with SingleTickerProviderStateMixin {
//   final FileAccessService _fileAccessService = FileAccessService();
//   List<FileModel> _files = [];
//   bool _isLoading = false;
//   late TabController _tabController;
//   String _currentFilter = 'all';
//
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _loadRecentFiles();
//   }
//
//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _loadRecentFiles() async {
//     setState(() {
//       _isLoading = true;
//     });
//
//     try {
//       final recentFiles = await _fileAccessService.getRecentFiles();
//       setState(() {
//         _files = recentFiles;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       _showErrorSnackBar('Failed to load recent files');
//     }
//   }
//
//   Future<void> _pickFiles({List<String>? allowedExtensions}) async {
//     setState(() {
//       _isLoading = true;
//     });
//
//     try {
//       final files = await _fileAccessService.getFilesFromDevice(
//         allowedExtensions: allowedExtensions,
//       );
//       setState(() {
//         _files = [..._files, ...files];
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       _showErrorSnackBar('Failed to access files');
//     }
//   }
//
//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
//
//   List<FileModel> _getFilteredFiles() {
//     if (_currentFilter == 'all') {
//       return _files;
//     } else {
//       return _files.where((file) => file.type == _currentFilter).toList();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final policyProvider = Provider.of<PolicyProvider>(context);
//     final filteredFiles = _getFilteredFiles();
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('File Browser'),
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: const [
//             Tab(text: 'All Files'),
//             Tab(text: 'Labeled Files'),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.label),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => const LabelIconScreen(),
//                 ),
//               );
//             },
//             tooltip: 'Manage Labels',
//           ),
//           PopupMenuButton<String>(
//             onSelected: (value) {
//               setState(() {
//                 _currentFilter = value;
//               });
//             },
//             itemBuilder: (context) => [
//               const PopupMenuItem<String>(
//                 value: 'all',
//                 child: Text('All Files'),
//               ),
//               const PopupMenuItem<String>(
//                 value: 'excel',
//                 child: Text('Excel Files'),
//               ),
//               const PopupMenuItem<String>(
//                 value: 'document',
//                 child: Text('Documents'),
//               ),
//               const PopupMenuItem<String>(
//                 value: 'pdf',
//                 child: Text('PDFs'),
//               ),
//               const PopupMenuItem<String>(
//                 value: 'image',
//                 child: Text('Images'),
//               ),
//               const PopupMenuItem<String>(
//                 value: 'video',
//                 child: Text('Videos'),
//               ),
//               const PopupMenuItem<String>(
//                 value: 'audio',
//                 child: Text('Audio'),
//               ),
//             ],
//           ),
//         ],
//       ),
//       body: _isLoading || policyProvider.isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : TabBarView(
//               controller: _tabController,
//               children: [
//                 // All Files Tab
//                 filteredFiles.isEmpty
//                     ? Center(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             const Text('No files found'),
//                             const SizedBox(height: 16),
//                             ElevatedButton(
//                               onPressed: () => _pickFiles(),
//                               child: const Text('Browse Files'),
//                             ),
//                           ],
//                         ),
//                       )
//                     : ListView.builder(
//                         itemCount: filteredFiles.length,
//                         itemBuilder: (context, index) {
//                           final file = filteredFiles[index];
//                           final fileLabel =
//                               policyProvider.getLabelForFile(file.path);
//
//                           return Card(
//                             margin: const EdgeInsets.symmetric(
//                                 horizontal: 16, vertical: 8),
//                             child: ListTile(
//                               leading: _getFileIcon(file.type, fileLabel),
//                               title: Text(file.name),
//                               subtitle: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text('Size: ${file.getFormattedSize()}'),
//                                   if (file.lastAccessed != null)
//                                     Text(
//                                         'Last accessed: ${DateFormat('yyyy-MM-dd HH:mm').format(file.lastAccessed!)}'),
//                                   if (fileLabel != null)
//                                     Container(
//                                       padding: const EdgeInsets.symmetric(
//                                           horizontal: 8, vertical: 4),
//                                       decoration: BoxDecoration(
//                                         color: Color(LabelIconMapping
//                                                 .getColorForLabel(fileLabel))
//                                             .withOpacity(0.2),
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                       child: Text(
//                                         fileLabel,
//                                         style: TextStyle(
//                                           color: Color(
//                                               LabelIconMapping.getColorForLabel(
//                                                   fileLabel)),
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                               trailing: PopupMenuButton<String>(
//                                 onSelected: (value) async {
//                                   if (value == 'open') {
//                                     _openFile(file);
//                                   } else if (value == 'openExternal') {
//                                     _openFileExternal(file);
//                                   } else if (value == 'preview') {
//                                     _previewFile(file);
//                                   } else if (value == 'dataMind') {
//                                     _openDataMind(context, file);
//                                   } else if (value == 'removeLabel') {
//                                     await policyProvider
//                                         .removeLabelFromFile(file.path);
//                                     setState(() {});
//                                   } else if (value == 'share') {
//                                     await _fileAccessService.shareFile(
//                                         file.path, file.name);
//                                   } else if (value == 'extract' &&
//                                       file.type == 'archive') {
//                                     final directory =
//                                         await getApplicationDocumentsDirectory();
//                                     final extractPath =
//                                         '${directory.path}/extracted/${file.name}';
//                                     await _fileAccessService.extractArchive(
//                                         file.path, extractPath);
//                                     _showSuccessSnackBar(
//                                         'Archive extracted successfully');
//                                   }
//                                 },
//                                 itemBuilder: (context) => [
//                                   if (file.type == 'excel')
//                                     const PopupMenuItem<String>(
//                                       value: 'preview',
//                                       child: Text('Preview in App'),
//                                     ),
//                                   const PopupMenuItem<String>(
//                                     value: 'open',
//                                     child: Text('Open'),
//                                   ),
//                                   if (file.type == 'excel')
//                                     const PopupMenuItem<String>(
//                                       value: 'openExternal',
//                                       child: Text('Open in Excel'),
//                                     ),
//                                   const PopupMenuItem<String>(
//                                     value: 'dataMind',
//                                     child: Text('Data Mind'),
//                                   ),
//                                   if (fileLabel != null)
//                                     const PopupMenuItem<String>(
//                                       value: 'removeLabel',
//                                       child: Text('Remove Label'),
//                                     ),
//                                   const PopupMenuItem<String>(
//                                     value: 'share',
//                                     child: Text('Share'),
//                                   ),
//                                   if (file.type == 'archive')
//                                     const PopupMenuItem<String>(
//                                       value: 'extract',
//                                       child: Text('Extract'),
//                                     ),
//                                 ],
//                               ),
//                               onTap: () {
//                                 _openFile(file);
//                               },
//                             ),
//                           );
//                         },
//                       ),
//
//                 // Labeled Files Tab
//                 _buildLabeledFilesTab(policyProvider),
//               ],
//             ),
//       floatingActionButton: Column(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           FloatingActionButton(
//             heroTag: 'pickExcel',
//             onPressed: () =>
//                 _pickFiles(allowedExtensions: ['xlsx', 'xls', 'csv']),
//             child: const Icon(Icons.table_chart),
//             tooltip: 'Pick Excel Files',
//           ),
//           const SizedBox(height: 16),
//           FloatingActionButton(
//             heroTag: 'pickAny',
//             onPressed: () => _pickFiles(),
//             child: const Icon(Icons.add),
//             tooltip: 'Pick Any Files',
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLabeledFilesTab(PolicyProvider policyProvider) {
//     final labeledFilePaths = policyProvider.getAllLabeledFiles();
//     final labeledFiles = _files
//         .where((file) => policyProvider.getLabelForFile(file.path) != null)
//         .toList();
//
//     // Add files that are labeled but not in the current list
//     for (var filePath in labeledFilePaths.keys) {
//       if (!_files.any((file) => file.path == filePath)) {
//         final file = File(filePath);
//         if (file.existsSync()) {
//           try {
//             final fileStats = file.statSync();
//             final fileName = filePath.split('/').last;
//             final fileSize = fileStats.size;
//             final fileType = _fileAccessService.getFileTypeFromPath(filePath);
//
//             labeledFiles.add(
//               FileModel(
//                 id: DateTime.now().millisecondsSinceEpoch.toString() + fileName,
//                 name: fileName,
//                 path: filePath,
//                 size: fileSize,
//                 type: fileType,
//               ),
//             );
//           } catch (e) {
//             print('Error loading labeled file: $e');
//           }
//         }
//       }
//     }
//
//     if (labeledFiles.isEmpty) {
//       return const Center(
//         child: Text('No labeled files yet'),
//       );
//     }
//
//     // Group files by label
//     final Map<String, List<FileModel>> filesByLabel = {};
//     for (var file in labeledFiles) {
//       final label = policyProvider.getLabelForFile(file.path);
//       if (label != null) {
//         if (!filesByLabel.containsKey(label)) {
//           filesByLabel[label] = [];
//         }
//         filesByLabel[label]!.add(file);
//       }
//     }
//
//     return ListView.builder(
//       itemCount: filesByLabel.length,
//       itemBuilder: (context, index) {
//         final label = filesByLabel.keys.elementAt(index);
//         final files = filesByLabel[label]!;
//
//         return ExpansionTile(
//           leading: CircleAvatar(
//             backgroundColor: Color(LabelIconMapping.getColorForLabel(label))
//                 .withOpacity(0.2),
//             child: Icon(
//               Icons.label,
//               color: Color(LabelIconMapping.getColorForLabel(label)),
//             ),
//           ),
//           title: Text(
//             label,
//             style: const TextStyle(fontWeight: FontWeight.bold),
//           ),
//           subtitle: Text('${files.length} files'),
//           children: files
//               .map((file) => ListTile(
//                     leading: _getFileIcon(file.type, label),
//                     title: Text(file.name),
//                     subtitle: Text('Size: ${file.getFormattedSize()}'),
//                     trailing: IconButton(
//                       icon: const Icon(Icons.open_in_new),
//                       onPressed: () {
//                         _openFile(file);
//                       },
//                     ),
//                     onTap: () {
//                       _openFile(file);
//                     },
//                   ))
//               .toList(),
//         );
//       },
//     );
//   }
//
//   Widget _getFileIcon(String fileType, String? label) {
//     if (label != null) {
//       // Use label-based icon/color
//       return CircleAvatar(
//         backgroundColor:
//             Color(LabelIconMapping.getColorForLabel(label)).withOpacity(0.2),
//         child: Icon(
//           _getIconDataForFileType(fileType),
//           color: Color(LabelIconMapping.getColorForLabel(label)),
//         ),
//       );
//     } else {
//       // Use default file type icon
//       IconData iconData = _getIconDataForFileType(fileType);
//       Color iconColor = _getColorForFileType(fileType);
//
//       return CircleAvatar(
//         backgroundColor: iconColor.withOpacity(0.2),
//         child: Icon(iconData, color: iconColor),
//       );
//     }
//   }
//
//   IconData _getIconDataForFileType(String fileType) {
//     switch (fileType) {
//       case 'excel':
//         return Icons.table_chart;
//       case 'document':
//         return Icons.description;
//       case 'pdf':
//         return Icons.picture_as_pdf;
//       case 'image':
//         return Icons.image;
//       case 'video':
//         return Icons.videocam;
//       case 'audio':
//         return Icons.audiotrack;
//       case 'presentation':
//         return Icons.slideshow;
//       case 'archive':
//         return Icons.archive;
//       default:
//         return Icons.insert_drive_file;
//     }
//   }
//
//   Color _getColorForFileType(String fileType) {
//     switch (fileType) {
//       case 'excel':
//         return Colors.green;
//       case 'document':
//         return Colors.blue;
//       case 'pdf':
//         return Colors.red;
//       case 'image':
//         return Colors.purple;
//       case 'video':
//         return Colors.orange;
//       case 'audio':
//         return Colors.pink;
//       case 'presentation':
//         return Colors.deepOrange;
//       case 'archive':
//         return Colors.brown;
//       default:
//         return Colors.grey;
//     }
//   }
//
//   void _openFile(FileModel file) async {
//     // Update last accessed time
//     setState(() {
//       final index = _files.indexWhere((f) => f.id == file.id);
//       if (index != -1) {
//         _files[index] = _files[index].copyWith(lastAccessed: DateTime.now());
//       }
//     });
//
//     if (file.type == 'excel') {
//       // For Excel files, show a dialog to choose how to open
//       showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: const Text('Open Excel File'),
//           content: const Text('How would you like to open this Excel file?'),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 _previewFile(file);
//               },
//               child: const Text('Preview in App'),
//             ),
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 _openFileExternal(file);
//               },
//               child: const Text('Open in Excel'),
//             ),
//           ],
//         ),
//       );
//     } else if (file.type == 'pdf' || file.type == 'image') {
//       // For PDF and image files, use custom viewers
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => FileViewerScreen(file: file),
//         ),
//       );
//     } else {
//       // For other file types, use the system's default app
//       _openFileExternal(file);
//     }
//   }
//
//   void _openFileExternal(FileModel file) async {
//     if (file.type == 'excel') {
//       final success = await _fileAccessService.openExcelFile(file.path);
//       if (!success) {
//         _showErrorSnackBar(
//             'Could not open Excel file. Make sure you have an Excel app installed.');
//       }
//     } else {
//       final result = await _fileAccessService.openFile(file.path);
//       if (result.type != ResultType.done) {
//         _showErrorSnackBar('Could not open file: ${result.message}');
//       }
//     }
//   }
//
//   void _previewFile(FileModel file) {
//     if (file.type == 'excel') {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => ExcelViewerScreen(file: file),
//         ),
//       );
//     } else if (file.type == 'pdf' || file.type == 'image') {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => FileViewerScreen(file: file),
//         ),
//       );
//     } else {
//       _showErrorSnackBar('Preview not available for this file type');
//     }
//   }
//
//   void _openDataMind(BuildContext context, FileModel file) async {
//     final policyProvider = Provider.of<PolicyProvider>(context, listen: false);
//
//     if (!policyProvider.hasManualLabelsAvailable()) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('No manual labels are available in policies'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }
//
//     final result = await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => ManualLabellingScreen(file: file),
//       ),
//     );
//
//     if (result == true) {
//       // Refresh the UI
//       setState(() {});
//     }
//   }
//
//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.green,
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:open_file/open_file.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:provider/provider.dart';
//
// import 'excel_viewer_screen.dart';
// import 'file_access_service.dart';
// import 'file_model.dart';
// import 'file_viewer_screen.dart';
// import 'manual_labelling_screen.dart';
// import 'policy_provider.dart';
//
// class FileBrowserScreen extends StatefulWidget {
//   const FileBrowserScreen({Key? key}) : super(key: key);
//
//   @override
//   State<FileBrowserScreen> createState() => _FileBrowserScreenState();
// }
//
// class _FileBrowserScreenState extends State<FileBrowserScreen>
//     with SingleTickerProviderStateMixin {
//   final FileAccessService _fileAccessService = FileAccessService();
//   List<FileModel> _files = [];
//   bool _isLoading = false;
//   late TabController _tabController;
//   String _currentFilter = 'all';
//
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _loadRecentFiles();
//   }
//
//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _loadRecentFiles() async {
//     setState(() {
//       _isLoading = true;
//     });
//
//     try {
//       final recentFiles = await _fileAccessService.getRecentFiles();
//       setState(() {
//         _files = recentFiles;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       _showErrorSnackBar('Failed to load recent files');
//     }
//   }
//
//   Future<void> _pickFiles({List<String>? allowedExtensions}) async {
//     setState(() {
//       _isLoading = true;
//     });
//
//     try {
//       final files = await _fileAccessService.getFilesFromDevice(
//         allowedExtensions: allowedExtensions,
//       );
//       setState(() {
//         _files = [..._files, ...files];
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       _showErrorSnackBar('Failed to access files');
//     }
//   }
//
//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
//
//   List<FileModel> _getFilteredFiles() {
//     if (_currentFilter == 'all') {
//       return _files;
//     } else {
//       return _files.where((file) => file.type == _currentFilter).toList();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final policyProvider = Provider.of<PolicyProvider>(context);
//     final filteredFiles = _getFilteredFiles();
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('File Browser'),
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: const [
//             Tab(text: 'All Files'),
//             Tab(text: 'Labeled Files'),
//           ],
//         ),
//         actions: [
//           PopupMenuButton<String>(
//             onSelected: (value) {
//               setState(() {
//                 _currentFilter = value;
//               });
//             },
//             itemBuilder: (context) => [
//               const PopupMenuItem<String>(
//                 value: 'all',
//                 child: Text('All Files'),
//               ),
//               const PopupMenuItem<String>(
//                 value: 'excel',
//                 child: Text('Excel Files'),
//               ),
//               const PopupMenuItem<String>(
//                 value: 'document',
//                 child: Text('Documents'),
//               ),
//               const PopupMenuItem<String>(
//                 value: 'pdf',
//                 child: Text('PDFs'),
//               ),
//               const PopupMenuItem<String>(
//                 value: 'image',
//                 child: Text('Images'),
//               ),
//               const PopupMenuItem<String>(
//                 value: 'video',
//                 child: Text('Videos'),
//               ),
//               const PopupMenuItem<String>(
//                 value: 'audio',
//                 child: Text('Audio'),
//               ),
//             ],
//           ),
//         ],
//       ),
//       body: _isLoading || policyProvider.isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : TabBarView(
//               controller: _tabController,
//               children: [
//                 // All Files Tab
//                 filteredFiles.isEmpty
//                     ? Center(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             const Text('No files found'),
//                             const SizedBox(height: 16),
//                             ElevatedButton(
//                               onPressed: () => _pickFiles(),
//                               child: const Text('Browse Files'),
//                             ),
//                           ],
//                         ),
//                       )
//                     : ListView.builder(
//                         itemCount: filteredFiles.length,
//                         itemBuilder: (context, index) {
//                           final file = filteredFiles[index];
//                           final fileLabel =
//                               policyProvider.getLabelForFile(file.id);
//
//                           return Card(
//                             margin: const EdgeInsets.symmetric(
//                                 horizontal: 16, vertical: 8),
//                             child: ListTile(
//                               leading: _getFileIcon(file.type),
//                               title: Text(file.name),
//                               subtitle: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text('Size: ${file.getFormattedSize()}'),
//                                   if (file.lastAccessed != null)
//                                     Text(
//                                         'Last accessed: ${DateFormat('yyyy-MM-dd HH:mm').format(file.lastAccessed!)}'),
//                                   if (fileLabel != null)
//                                     Chip(
//                                       label: Text(fileLabel),
//                                       backgroundColor: Colors.blue.shade100,
//                                     ),
//                                 ],
//                               ),
//                               trailing: PopupMenuButton<String>(
//                                 onSelected: (value) async {
//                                   if (value == 'open') {
//                                     _openFile(file);
//                                   } else if (value == 'openExternal') {
//                                     _openFileExternal(file);
//                                   } else if (value == 'preview') {
//                                     _previewFile(file);
//                                   } else if (value == 'dataMind') {
//                                     _openDataMind(context, file);
//                                   } else if (value == 'share') {
//                                     await _fileAccessService.shareFile(
//                                         file.path, file.name);
//                                   } else if (value == 'extract' &&
//                                       file.type == 'archive') {
//                                     final directory =
//                                         await getApplicationDocumentsDirectory();
//                                     final extractPath =
//                                         '${directory.path}/extracted/${file.name}';
//                                     await _fileAccessService.extractArchive(
//                                         file.path, extractPath);
//                                     _showSuccessSnackBar(
//                                         'Archive extracted successfully');
//                                   }
//                                 },
//                                 itemBuilder: (context) => [
//                                   if (file.type == 'excel')
//                                     const PopupMenuItem<String>(
//                                       value: 'preview',
//                                       child: Text('Preview in App'),
//                                     ),
//                                   const PopupMenuItem<String>(
//                                     value: 'open',
//                                     child: Text('Open'),
//                                   ),
//                                   if (file.type == 'excel')
//                                     const PopupMenuItem<String>(
//                                       value: 'openExternal',
//                                       child: Text('Open in Excel'),
//                                     ),
//                                   const PopupMenuItem<String>(
//                                     value: 'dataMind',
//                                     child: Text('Data Mind'),
//                                   ),
//                                   const PopupMenuItem<String>(
//                                     value: 'share',
//                                     child: Text('Share'),
//                                   ),
//                                   if (file.type == 'archive')
//                                     const PopupMenuItem<String>(
//                                       value: 'extract',
//                                       child: Text('Extract'),
//                                     ),
//                                 ],
//                               ),
//                               onTap: () {
//                                 _openFile(file);
//                               },
//                             ),
//                           );
//                         },
//                       ),
//
//                 // Labeled Files Tab
//                 _buildLabeledFilesTab(policyProvider),
//               ],
//             ),
//       floatingActionButton: Column(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           FloatingActionButton(
//             heroTag: 'pickExcel',
//             onPressed: () =>
//                 _pickFiles(allowedExtensions: ['xlsx', 'xls', 'csv']),
//             child: const Icon(Icons.table_chart),
//             tooltip: 'Pick Excel Files',
//           ),
//           const SizedBox(height: 16),
//           FloatingActionButton(
//             heroTag: 'pickAny',
//             onPressed: () => _pickFiles(),
//             child: const Icon(Icons.add),
//             tooltip: 'Pick Any Files',
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLabeledFilesTab(PolicyProvider policyProvider) {
//     final labeledFiles = _files
//         .where((file) => policyProvider.getLabelForFile(file.id) != null)
//         .toList();
//
//     if (labeledFiles.isEmpty) {
//       return const Center(
//         child: Text('No labeled files yet'),
//       );
//     }
//
//     return ListView.builder(
//       itemCount: labeledFiles.length,
//       itemBuilder: (context, index) {
//         final file = labeledFiles[index];
//         final fileLabel = policyProvider.getLabelForFile(file.id);
//
//         return Card(
//           margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           child: ListTile(
//             leading: _getFileIcon(file.type),
//             title: Text(file.name),
//             subtitle: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text('Size: ${file.getFormattedSize()}'),
//                 Chip(
//                   label: Text(fileLabel!),
//                   backgroundColor: Colors.blue.shade100,
//                 ),
//               ],
//             ),
//             trailing: IconButton(
//               icon: const Icon(Icons.open_in_new),
//               onPressed: () {
//                 _openFile(file);
//               },
//             ),
//             onTap: () {
//               _openFile(file);
//             },
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _getFileIcon(String fileType) {
//     IconData iconData;
//     Color iconColor;
//
//     switch (fileType) {
//       case 'excel':
//         iconData = Icons.table_chart;
//         iconColor = Colors.green;
//         break;
//       case 'document':
//         iconData = Icons.description;
//         iconColor = Colors.blue;
//         break;
//       case 'pdf':
//         iconData = Icons.picture_as_pdf;
//         iconColor = Colors.red;
//         break;
//       case 'image':
//         iconData = Icons.image;
//         iconColor = Colors.purple;
//         break;
//       case 'video':
//         iconData = Icons.videocam;
//         iconColor = Colors.orange;
//         break;
//       case 'audio':
//         iconData = Icons.audiotrack;
//         iconColor = Colors.pink;
//         break;
//       case 'presentation':
//         iconData = Icons.slideshow;
//         iconColor = Colors.deepOrange;
//         break;
//       case 'archive':
//         iconData = Icons.archive;
//         iconColor = Colors.brown;
//         break;
//       default:
//         iconData = Icons.insert_drive_file;
//         iconColor = Colors.grey;
//     }
//
//     return CircleAvatar(
//       backgroundColor: iconColor.withOpacity(0.2),
//       child: Icon(iconData, color: iconColor),
//     );
//   }
//
//   void _openFile(FileModel file) async {
//     // Update last accessed time
//     setState(() {
//       final index = _files.indexWhere((f) => f.id == file.id);
//       if (index != -1) {
//         _files[index] = _files[index].copyWith(lastAccessed: DateTime.now());
//       }
//     });
//
//     if (file.type == 'excel') {
//       // For Excel files, show a dialog to choose how to open
//       showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: const Text('Open Excel File'),
//           content: const Text('How would you like to open this Excel file?'),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 _previewFile(file);
//               },
//               child: const Text('Preview in App'),
//             ),
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 _openFileExternal(file);
//               },
//               child: const Text('Open in Excel'),
//             ),
//           ],
//         ),
//       );
//     } else if (file.type == 'pdf' || file.type == 'image') {
//       // For PDF and image files, use custom viewers
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => FileViewerScreen(file: file),
//         ),
//       );
//     } else {
//       // For other file types, use the system's default app
//       _openFileExternal(file);
//     }
//   }
//
//   void _openFileExternal(FileModel file) async {
//     if (file.type == 'excel') {
//       final success = await _fileAccessService.openExcelFile(file.path);
//       if (!success) {
//         _showErrorSnackBar(
//             'Could not open Excel file. Make sure you have an Excel app installed.');
//       }
//     } else {
//       final result = await _fileAccessService.openFile(file.path);
//       if (result.type != ResultType.done) {
//         _showErrorSnackBar('Could not open file: ${result.message}');
//       }
//     }
//   }
//
//   void _previewFile(FileModel file) {
//     if (file.type == 'excel') {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => ExcelViewerScreen(file: file),
//         ),
//       );
//     } else if (file.type == 'pdf' || file.type == 'image') {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => FileViewerScreen(file: file),
//         ),
//       );
//     } else {
//       _showErrorSnackBar('Preview not available for this file type');
//     }
//   }
//
//   void _openDataMind(BuildContext context, FileModel file) async {
//     final policyProvider = Provider.of<PolicyProvider>(context, listen: false);
//
//     if (!policyProvider.hasManualLabelsAvailable()) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('No manual labels are available in policies'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }
//
//     final result = await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => ManualLabellingScreen(file: file),
//       ),
//     );
//
//     if (result == true) {
//       // Refresh the UI
//       setState(() {});
//     }
//   }
//
//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.green,
//       ),
//     );
//   }
// }
