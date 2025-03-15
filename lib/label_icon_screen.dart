import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'label_icon_mapping.dart';
import 'policy_provider.dart';

class LabelIconScreen extends StatefulWidget {
  const LabelIconScreen({Key? key}) : super(key: key);

  @override
  State<LabelIconScreen> createState() => _LabelIconScreenState();
}

class _LabelIconScreenState extends State<LabelIconScreen> {
  final TextEditingController _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final policyProvider = Provider.of<PolicyProvider>(context);
    final labels = policyProvider.getAvailableLabels();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Labels'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      labelText: 'New Label',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    final newLabel = _labelController.text.trim();
                    if (newLabel.isNotEmpty) {
                      policyProvider.addLabel(newLabel);
                      _labelController.clear();
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: labels.length,
              itemBuilder: (context, index) {
                final label = labels[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Color(LabelIconMapping.getColorForLabel(label))
                            .withOpacity(0.2),
                    child: Icon(
                      Icons.label,
                      color: Color(LabelIconMapping.getColorForLabel(label)),
                    ),
                  ),
                  title: Text(label),
                  subtitle: Text(
                      '${policyProvider.getFilesWithLabel(label).length} files'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.color_lens),
                        onPressed: () {
                          _showColorPicker(context, label);
                        },
                        tooltip: 'Change Color',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _confirmDeleteLabel(context, label);
                        },
                        tooltip: 'Delete Label',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, String label) {
    // In a real app, you would implement a color picker here
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Color for "$label"'),
        content: const Text('Color picker would be implemented here'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteLabel(BuildContext context, String label) {
    final policyProvider = Provider.of<PolicyProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Label "$label"?'),
        content: Text(
            'This will remove the label from all files. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              policyProvider.removeLabel(label);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
