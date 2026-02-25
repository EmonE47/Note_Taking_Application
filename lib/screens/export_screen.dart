import 'package:flutter/material.dart';
import '../services/export_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ExportService _exportService = ExportService.instance;
  bool _isExporting = false;
  String _exportStatus = '';
  bool _hasStoragePermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermission();
    });
  }

  Future<void> _checkPermission() async {
    final granted = await _exportService.ensureExportPermission();
    if (mounted) {
      setState(() => _hasStoragePermission = granted);
    }
  }

  Future<void> _requestPermission() async {
    final granted = await _exportService.ensureExportPermission(
      openSettingsIfDenied: true,
    );
    if (mounted) {
      setState(() => _hasStoragePermission = granted);
    }

    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enable "All files access" for MyDiary in Settings.',
          ),
        ),
      );
    }
  }

  Future<void> _exportNotesAsFiles() async {
    if (!_hasStoragePermission) {
      await _requestPermission();
      if (!_hasStoragePermission) return;
    }

    setState(() {
      _isExporting = true;
      _exportStatus = 'Preparing export...';
    });

    try {
      final path = await _exportService.exportAllNotes();
      setState(() => _exportStatus = 'Exported to: $path');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes exported successfully!')),
        );
      }
    } catch (e) {
      setState(() => _exportStatus = 'Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportAsZip() async {
    if (!_hasStoragePermission) {
      await _requestPermission();
      if (!_hasStoragePermission) return;
    }

    setState(() {
      _isExporting = true;
      _exportStatus = 'Creating ZIP archive...';
    });

    try {
      final path = await _exportService.exportAsZip();
      setState(() => _exportStatus = 'ZIP created: $path');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Backup ZIP created!')));
      }
    } catch (e) {
      setState(() => _exportStatus = 'Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export & Backup')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_hasStoragePermission)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Storage access needed',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Grant access so MyDiary can save .md files to Internal Storage.',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _requestPermission,
                        child: const Text('Grant Access'),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_hasStoragePermission) const SizedBox(height: 16),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export Notes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Export your notes as Markdown files that can be accessed from any file manager.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.folder, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Files will be saved to:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Internal Storage/MyDiary/',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportNotesAsFiles,
                    icon: const Icon(Icons.file_copy),
                    label: const Text('Export as Markdown Files'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportAsZip,
                    icon: const Icon(Icons.archive),
                    label: const Text('Export as ZIP Archive'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (_exportStatus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(_exportStatus, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to access files:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('1. Open any file manager app'),
                  Text('2. Go to Internal Storage'),
                  Text('3. Find "MyDiary" folder'),
                  Text('4. Open your exported .md notes'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
