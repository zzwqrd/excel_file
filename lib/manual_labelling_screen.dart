import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'file_model.dart';
import 'label_icon_mapping.dart';
import 'policy_provider.dart';

class ManualLabellingScreen extends StatefulWidget {
  final FileModel file;

  const ManualLabellingScreen({Key? key, required this.file}) : super(key: key);

  @override
  State<ManualLabellingScreen> createState() => _ManualLabellingScreenState();
}

class _ManualLabellingScreenState extends State<ManualLabellingScreen> {
  String? selectedLabel;
  bool isConfirmEnabled = false;
  bool _isProcessing = false;
  bool _hasMetadata = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLabel();
  }

  Future<void> _loadCurrentLabel() async {
    final policyProvider = Provider.of<PolicyProvider>(context, listen: false);

    // Check if the file already has metadata
    final hasMetadata =
        await policyProvider.checkFileHasMetadata(widget.file.path);

    setState(() {
      selectedLabel = policyProvider.getLabelForFile(widget.file.path);
      isConfirmEnabled = selectedLabel != null;
      _hasMetadata = hasMetadata;
    });
  }

  @override
  Widget build(BuildContext context) {
    final policyProvider = Provider.of<PolicyProvider>(context);
    final availableLabels = policyProvider.getAvailableLabels();
    final hasManualLabelsAvailable = availableLabels.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Mind'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilePreview(),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Manual Labelling',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (_hasMetadata)
                  Chip(
                    label: const Text('Metadata Present'),
                    backgroundColor: Colors.green.withOpacity(0.2),
                    avatar: const Icon(Icons.check_circle,
                        color: Colors.green, size: 16),
                  )
                else
                  Chip(
                    label: const Text('No Metadata'),
                    backgroundColor: Colors.orange.withOpacity(0.2),
                    avatar:
                        const Icon(Icons.info, color: Colors.orange, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasManualLabelsAvailable)
              const Card(
                color: Colors.amber,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No manual labels are available in policies',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select a label to apply to this file:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Label',
                    ),
                    value: selectedLabel,
                    items: availableLabels.map((label) {
                      return DropdownMenuItem<String>(
                        value: label,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Color(
                                    LabelIconMapping.getColorForLabel(label)),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: hasManualLabelsAvailable && !_isProcessing
                        ? (value) {
                            setState(() {
                              selectedLabel = value;
                              isConfirmEnabled = value != null;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (_isProcessing)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Applying label to file...'),
                  ],
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isConfirmEnabled && !_isProcessing
                    ? () {
                        _confirmLabelSelection(context);
                      }
                    : null,
                child: const Text('Confirm Selection'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildFileInfo(),
            const SizedBox(height: 16),
            if (widget.file.type == 'image')
              SizedBox(
                height: 150,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(widget.file.path),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Name: ${widget.file.name}'),
        Text('Type: ${widget.file.type.toUpperCase()}'),
        Text('Size: ${widget.file.getFormattedSize()}'),
        Text('Path: ${widget.file.path}'),
        if (widget.file.mimeType != null)
          Text('MIME Type: ${widget.file.mimeType}'),
      ],
    );
  }

  void _confirmLabelSelection(BuildContext context) async {
    if (selectedLabel != null) {
      setState(() {
        _isProcessing = true;
      });

      final policyProvider =
          Provider.of<PolicyProvider>(context, listen: false);
      final success = await policyProvider.applyLabelToFile(
          widget.file.path, selectedLabel!);

      setState(() {
        _isProcessing = false;
        _hasMetadata = success;
      });

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Label "$selectedLabel" applied to file ${widget.file.name}'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Label applied to app database, but could not write metadata to the file itself.'),
              backgroundColor: Colors.orange,
            ),
          );

          // Still return true since we at least saved it in the app
          Navigator.pop(context, true);
        }
      }
    }
  }
}

// class ManualLabellingScreen extends StatefulWidget {
//   final FileModel file;
//
//   const ManualLabellingScreen({Key? key, required this.file}) : super(key: key);
//
//   @override
//   State<ManualLabellingScreen> createState() => _ManualLabellingScreenState();
// }
//
// class _ManualLabellingScreenState extends State<ManualLabellingScreen> {
//   String? selectedLabel;
//   bool isConfirmEnabled = false;
//
//   @override
//   void initState() {
//     super.initState();
//     // Get current label if exists
//     final policyProvider = Provider.of<PolicyProvider>(context, listen: false);
//     selectedLabel = policyProvider.getLabelForFile(widget.file.path);
//     isConfirmEnabled = selectedLabel != null;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final policyProvider = Provider.of<PolicyProvider>(context);
//     final availableLabels = policyProvider.getAvailableLabels();
//     final hasManualLabelsAvailable = availableLabels.isNotEmpty;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Data Mind'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildFilePreview(),
//             const SizedBox(height: 24),
//             Text(
//               'Manual Labelling',
//               style: Theme.of(context).textTheme.titleLarge,
//             ),
//             const SizedBox(height: 16),
//             if (!hasManualLabelsAvailable)
//               const Card(
//                 color: Colors.amber,
//                 child: Padding(
//                   padding: EdgeInsets.all(16.0),
//                   child: Text(
//                     'No manual labels are available in policies',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               )
//             else
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text('Select a label to apply to this file:'),
//                   const SizedBox(height: 8),
//                   DropdownButtonFormField<String>(
//                     decoration: const InputDecoration(
//                       border: OutlineInputBorder(),
//                       labelText: 'Label',
//                     ),
//                     value: selectedLabel,
//                     items: availableLabels.map((label) {
//                       return DropdownMenuItem<String>(
//                         value: label,
//                         child: Row(
//                           children: [
//                             Container(
//                               width: 16,
//                               height: 16,
//                               decoration: BoxDecoration(
//                                 color: Color(
//                                     LabelIconMapping.getColorForLabel(label)),
//                                 shape: BoxShape.circle,
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             Text(label),
//                           ],
//                         ),
//                       );
//                     }).toList(),
//                     onChanged: hasManualLabelsAvailable
//                         ? (value) {
//                             setState(() {
//                               selectedLabel = value;
//                               isConfirmEnabled = value != null;
//                             });
//                           }
//                         : null,
//                   ),
//                 ],
//               ),
//             const Spacer(),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: isConfirmEnabled
//                     ? () {
//                         _confirmLabelSelection(context);
//                       }
//                     : null,
//                 child: const Text('Confirm Selection'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildFilePreview() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'File Details',
//               style: Theme.of(context).textTheme.titleMedium,
//             ),
//             const SizedBox(height: 8),
//             _buildFileInfo(),
//             const SizedBox(height: 16),
//             if (widget.file.type == 'image')
//               SizedBox(
//                 height: 150,
//                 width: double.infinity,
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(8),
//                   child: Image.file(
//                     File(widget.file.path),
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildFileInfo() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text('Name: ${widget.file.name}'),
//         Text('Type: ${widget.file.type.toUpperCase()}'),
//         Text('Size: ${widget.file.getFormattedSize()}'),
//         Text('Path: ${widget.file.path}'),
//         if (widget.file.mimeType != null)
//           Text('MIME Type: ${widget.file.mimeType}'),
//       ],
//     );
//   }
//
//   void _confirmLabelSelection(BuildContext context) async {
//     if (selectedLabel != null) {
//       final policyProvider =
//           Provider.of<PolicyProvider>(context, listen: false);
//       final success = await policyProvider.applyLabelToFile(
//           widget.file.path, selectedLabel!);
//
//       if (success) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                   'Label "$selectedLabel" applied to file ${widget.file.name}'),
//               backgroundColor: Colors.green,
//             ),
//           );
//
//           Navigator.pop(context, true);
//         }
//       } else {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Failed to apply label'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     }
//   }
// }

// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import 'file_model.dart';
// import 'policy_provider.dart';
//
// class ManualLabellingScreen extends StatefulWidget {
//   final FileModel file;
//
//   const ManualLabellingScreen({Key? key, required this.file}) : super(key: key);
//
//   @override
//   State<ManualLabellingScreen> createState() => _ManualLabellingScreenState();
// }
//
// class _ManualLabellingScreenState extends State<ManualLabellingScreen> {
//   String? selectedLabel;
//   bool isConfirmEnabled = false;
//
//   @override
//   void initState() {
//     super.initState();
//     // Get current label if exists
//     final policyProvider = Provider.of<PolicyProvider>(context, listen: false);
//     selectedLabel = policyProvider.getLabelForFile(widget.file.id);
//     isConfirmEnabled = selectedLabel != null;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final policyProvider = Provider.of<PolicyProvider>(context);
//     final availableLabels = policyProvider.getAvailableLabels();
//     final hasManualLabelsAvailable = availableLabels.isNotEmpty;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Data Mind'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildFilePreview(),
//             const SizedBox(height: 24),
//             Text(
//               'Manual Labelling',
//               style: Theme.of(context).textTheme.titleLarge,
//             ),
//             const SizedBox(height: 16),
//             if (!hasManualLabelsAvailable)
//               const Card(
//                 color: Colors.amber,
//                 child: Padding(
//                   padding: EdgeInsets.all(16.0),
//                   child: Text(
//                     'No manual labels are available in policies',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               )
//             else
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text('Select a label to apply to this file:'),
//                   const SizedBox(height: 8),
//                   DropdownButtonFormField<String>(
//                     decoration: const InputDecoration(
//                       border: OutlineInputBorder(),
//                       labelText: 'Label',
//                     ),
//                     value: selectedLabel,
//                     items: availableLabels.map((label) {
//                       return DropdownMenuItem<String>(
//                         value: label,
//                         child: Text(label),
//                       );
//                     }).toList(),
//                     onChanged: hasManualLabelsAvailable
//                         ? (value) {
//                             setState(() {
//                               selectedLabel = value;
//                               isConfirmEnabled = value != null;
//                             });
//                           }
//                         : null,
//                   ),
//                 ],
//               ),
//             const Spacer(),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: isConfirmEnabled
//                     ? () {
//                         _confirmLabelSelection(context);
//                       }
//                     : null,
//                 child: const Text('Confirm Selection'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildFilePreview() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'File Details',
//               style: Theme.of(context).textTheme.titleMedium,
//             ),
//             const SizedBox(height: 8),
//             _buildFileInfo(),
//             const SizedBox(height: 16),
//             if (widget.file.type == 'image')
//               SizedBox(
//                 height: 150,
//                 width: double.infinity,
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(8),
//                   child: Image.file(
//                     File(widget.file.path),
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildFileInfo() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text('Name: ${widget.file.name}'),
//         Text('Type: ${widget.file.type.toUpperCase()}'),
//         Text('Size: ${widget.file.getFormattedSize()}'),
//         Text('Path: ${widget.file.path}'),
//         if (widget.file.mimeType != null)
//           Text('MIME Type: ${widget.file.mimeType}'),
//       ],
//     );
//   }
//
//   void _confirmLabelSelection(BuildContext context) async {
//     if (selectedLabel != null) {
//       final policyProvider =
//           Provider.of<PolicyProvider>(context, listen: false);
//       final success =
//           await policyProvider.applyLabelToFile(widget.file.id, selectedLabel!);
//
//       if (success) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                   'Label "$selectedLabel" applied to file ${widget.file.name}'),
//               backgroundColor: Colors.green,
//             ),
//           );
//
//           Navigator.pop(context, true);
//         }
//       } else {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Failed to apply label'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     }
//   }
// }
