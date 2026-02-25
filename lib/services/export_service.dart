import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../database/database_helper.dart';
import '../models/note.dart';

class ExportService {
  static final ExportService instance = ExportService._internal();
  ExportService._internal();

  static const String _primaryFolderName = 'MyDiary';
  static const String _legacyFolderName = 'Notepad Pro';

  Directory? _exportDir;
  String? _androidRootPath;

  Future<bool> ensureExportPermission({
    bool openSettingsIfDenied = false,
  }) async {
    if (!Platform.isAndroid) return true;

    if (await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted) {
      return true;
    }

    final manageResult = await Permission.manageExternalStorage.request();
    if (manageResult.isGranted) return true;

    final storageResult = await Permission.storage.request();
    if (storageResult.isGranted) return true;

    if (openSettingsIfDenied &&
        (manageResult.isPermanentlyDenied ||
            storageResult.isPermanentlyDenied)) {
      await openAppSettings();
    }

    return false;
  }

  Future<Directory> get exportDirectory async {
    if (_exportDir != null) return _exportDir!;

    if (Platform.isAndroid) {
      final granted = await ensureExportPermission();
      if (!granted) {
        throw FileSystemException('Storage permission denied');
      }

      final possiblePaths = [
        '/storage/emulated/0',
        '/sdcard',
        '/storage/sdcard0',
      ];

      for (final root in possiblePaths) {
        final dir = Directory(root);
        if (await dir.exists()) {
          _androidRootPath = root;
          _exportDir = Directory(path.join(root, _primaryFolderName));
          if (!await _exportDir!.exists()) {
            await _exportDir!.create(recursive: true);
          }
          return _exportDir!;
        }
      }
    }

    final fallback =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    _exportDir = Directory(path.join(fallback.path, _primaryFolderName));
    if (!await _exportDir!.exists()) await _exportDir!.create(recursive: true);
    return _exportDir!;
  }

  Future<Directory?> _legacyDirectory() async {
    if (!Platform.isAndroid) return null;
    if (_androidRootPath == null) {
      await exportDirectory;
    }
    if (_androidRootPath == null) return null;

    final legacy = Directory(path.join(_androidRootPath!, _legacyFolderName));
    if (await legacy.exists()) return legacy;
    return null;
  }

  Future<String> exportSingleNote(Note note) async {
    final exportDir = await exportDirectory;
    final exportFile = File(path.join(exportDir.path, note.safeFileName));
    await exportFile.writeAsString(note.fileContent);
    return exportFile.path;
  }

  Future<List<Note>> readNotesFromFolder() async {
    final exportDir = await exportDirectory;
    final legacyDir = await _legacyDirectory();
    final dirs = <Directory>[exportDir];
    if (legacyDir != null && legacyDir.path != exportDir.path) {
      dirs.add(legacyDir);
    }

    final notes = <Note>[];
    final seenNames = <String>{};

    for (final dir in dirs) {
      final files = await dir.list().toList();
      for (final entity in files) {
        if (entity is! File) continue;
        if (path.extension(entity.path).toLowerCase() != '.md') continue;

        try {
          final fileKey = path.basename(entity.path).toLowerCase();
          if (seenNames.contains(fileKey)) {
            continue;
          }
          seenNames.add(fileKey);

          final content = await entity.readAsString();
          final fileName = path.basenameWithoutExtension(entity.path);
          final title = fileName.replaceAll('_', ' ').trim();
          final stat = await entity.stat();
          final timestamp = stat.modified;

          notes.add(
            Note(
              title: title.isEmpty ? 'Untitled' : title,
              content: content,
              createdAt: timestamp,
              updatedAt: timestamp,
              color: '4280391411',
              isPinned: false,
            ),
          );
        } catch (_) {
          // Skip unreadable files
        }
      }
    }

    return notes;
  }

  Future<String> syncNoteFile(Note note, {String? previousFileName}) async {
    final exportDir = await exportDirectory;

    if (previousFileName != null && previousFileName != note.safeFileName) {
      final oldFile = File(path.join(exportDir.path, previousFileName));
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
      final legacyDir = await _legacyDirectory();
      if (legacyDir != null) {
        final legacyFile = File(path.join(legacyDir.path, previousFileName));
        if (await legacyFile.exists()) {
          await legacyFile.delete();
        }
      }
    }

    final exportFile = File(path.join(exportDir.path, note.safeFileName));
    await exportFile.writeAsString(note.fileContent);
    return exportFile.path;
  }

  Future<void> deleteNoteFile(Note note) async {
    try {
      final exportDir = await exportDirectory;
      final exportFile = File(path.join(exportDir.path, note.safeFileName));
      if (await exportFile.exists()) {
        await exportFile.delete();
      }
      final legacyDir = await _legacyDirectory();
      if (legacyDir != null) {
        final legacyFile = File(path.join(legacyDir.path, note.safeFileName));
        if (await legacyFile.exists()) {
          await legacyFile.delete();
        }
      }
    } catch (_) {
      // Ignore file delete errors
    }
  }

  Future<String> exportAllNotes() async {
    final notes = await DatabaseHelper.instance.getAllNotes();
    final exportDir = await exportDirectory;
    final exportFolder = Directory(
      path.join(
        exportDir.path,
        'Backup_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    if (!await exportFolder.exists()) {
      await exportFolder.create(recursive: true);
    }

    for (final note in notes) {
      final noteFile = File(path.join(exportFolder.path, note.safeFileName));
      await noteFile.writeAsString(note.fileContent);
    }

    final metaFile = File(path.join(exportFolder.path, '_backup_info.json'));
    await metaFile.writeAsString(
      jsonEncode({
        'export_date': DateTime.now().toIso8601String(),
        'note_count': notes.length,
        'app_version': '1.0.0',
      }),
    );

    return exportFolder.path;
  }

  Future<String> exportAsZip() async {
    final notes = await DatabaseHelper.instance.getAllNotes();
    final exportDir = await exportDirectory;
    final zipFile = File(
      path.join(
        exportDir.path,
        'MyDiary_Backup_${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );

    final archive = Archive();
    for (final note in notes) {
      final data = utf8.encode(note.fileContent);
      archive.addFile(ArchiveFile(note.safeFileName, data.length, data));
    }

    final zipData = ZipEncoder().encode(archive);
    await zipFile.writeAsBytes(zipData!);

    return zipFile.path;
  }
}
