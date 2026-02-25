import '../database/database_helper.dart';
import '../models/note.dart';
import 'auth_service.dart';
import 'drive_service.dart';

class NoteSyncException implements Exception {
  final String message;
  final String code;

  const NoteSyncException({required this.message, required this.code});

  @override
  String toString() => message;
}

class NoteSyncService {
  static final NoteSyncService instance = NoteSyncService._internal();
  NoteSyncService._internal();

  Future<void> syncAllNotes() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      await DriveService.instance.ensureNotesFolder();

      final localNotes = await DatabaseHelper.instance.getAllNotes();
      final driveNotes = await DriveService.instance.listNotes();

      final driveByFileId = <String, Note>{
        for (final note in driveNotes)
          if (note.cloudId != null && note.cloudId!.isNotEmpty)
            note.cloudId!: note,
      };
      final syncedFileIds = <String>{};

      for (final localNote in localNotes) {
        final cloudId = localNote.cloudId;
        if (cloudId == null || cloudId.isEmpty) {
          final createdFileId = await DriveService.instance.createNoteFile(
            localNote,
          );
          localNote.cloudId = createdFileId;
          await DatabaseHelper.instance.updateNote(localNote);
          syncedFileIds.add(createdFileId);
          continue;
        }

        final driveNote = driveByFileId[cloudId];
        if (driveNote == null) {
          final createdFileId = await DriveService.instance.createNoteFile(
            localNote,
          );
          if (createdFileId != cloudId) {
            localNote.cloudId = createdFileId;
            await DatabaseHelper.instance.updateNote(localNote);
          }
          syncedFileIds.add(createdFileId);
          continue;
        }

        syncedFileIds.add(cloudId);
        if (localNote.updatedAt.isAfter(driveNote.updatedAt)) {
          await DriveService.instance.updateNoteFile(
            fileId: cloudId,
            note: localNote,
          );
        } else if (driveNote.updatedAt.isAfter(localNote.updatedAt)) {
          driveNote.id = localNote.id;
          await DatabaseHelper.instance.updateNote(driveNote);
        }
      }

      for (final driveNote in driveNotes) {
        final cloudId = driveNote.cloudId;
        if (cloudId == null || syncedFileIds.contains(cloudId)) {
          continue;
        }

        await DatabaseHelper.instance.upsertByCloudId(driveNote);
      }
    } on DriveServiceException catch (e) {
      throw _toSyncException(e);
    } catch (_) {
      throw const NoteSyncException(
        message: 'Cloud sync failed unexpectedly. Please try again.',
        code: 'unknown',
      );
    }
  }

  Future<void> upsertNote(Note note) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    try {
      final hasCloudId = note.cloudId != null && note.cloudId!.isNotEmpty;
      if (!hasCloudId && note.id != null) {
        final latest = await DatabaseHelper.instance.getNote(note.id!);
        final latestCloudId = latest?.cloudId;
        if (latestCloudId != null && latestCloudId.isNotEmpty) {
          note.cloudId = latestCloudId;
        }
      }

      await DriveService.instance.ensureNotesFolder();

      final cloudId = note.cloudId;
      if (cloudId == null || cloudId.isEmpty) {
        final createdFileId = await DriveService.instance.createNoteFile(note);
        note.cloudId = createdFileId;
        await DatabaseHelper.instance.updateNote(note);
        return;
      }

      await DriveService.instance.updateNoteFile(fileId: cloudId, note: note);
    } on DriveServiceException catch (e) {
      if (e.code == 'not-found') {
        final createdFileId = await DriveService.instance.createNoteFile(note);
        note.cloudId = createdFileId;
        await DatabaseHelper.instance.updateNote(note);
        return;
      }

      throw _toSyncException(e);
    } catch (_) {
      throw const NoteSyncException(
        message: 'Unable to sync this note right now.',
        code: 'unknown',
      );
    }
  }

  Future<void> deleteNoteFromCloud(Note note) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final cloudId = note.cloudId;
    if (cloudId == null || cloudId.isEmpty) return;

    try {
      await DriveService.instance.deleteNoteFile(cloudId);
    } on DriveServiceException catch (e) {
      if (e.code == 'not-found') return;
      throw _toSyncException(e);
    } catch (_) {
      throw const NoteSyncException(
        message: 'Unable to remove note from cloud right now.',
        code: 'unknown',
      );
    }
  }

  NoteSyncException _toSyncException(DriveServiceException e) {
    switch (e.code) {
      case 'auth-required':
      case 'unauthorized':
      case 'drive-auth-failed':
        return const NoteSyncException(
          code: 'auth',
          message:
              'Google Drive access is required. Sign in again with Google to sync notes.',
        );
      case 'drive-access-required':
        return const NoteSyncException(
          code: 'drive-access-required',
          message:
              'Google Drive permission is required for cloud sync. Allow access and try again.',
        );
      case 'auth-config-error':
        return const NoteSyncException(
          code: 'auth-config-error',
          message:
              'Google Sign-In is not configured for Android yet. Add SHA-1/SHA-256 in Firebase and update google-services.json.',
        );
      case 'drive-api-disabled':
        return const NoteSyncException(
          code: 'drive-api-disabled',
          message:
              'Google Drive API is disabled for this project. Enable it in Google Cloud Console and try again.',
        );
      case 'network':
        return const NoteSyncException(
          code: 'network',
          message: 'Network error while connecting to Google Drive.',
        );
      case 'permission-denied':
        return NoteSyncException(code: 'permission-denied', message: e.message);
      case 'rate-limited':
        return const NoteSyncException(
          code: 'rate-limited',
          message:
              'Google Drive is busy. Please try syncing again in a moment.',
        );
      default:
        return NoteSyncException(
          code: e.code,
          message: 'Cloud sync failed (${e.code}). Using offline notes.',
        );
    }
  }
}
