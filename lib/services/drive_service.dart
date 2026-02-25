import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../models/note.dart';
import 'auth_service.dart';

class DriveServiceException implements Exception {
  final String message;
  final String code;

  const DriveServiceException({required this.message, required this.code});

  @override
  String toString() => message;
}

class DriveService {
  static final DriveService instance = DriveService._internal();
  static const String _folderName = 'MyNotesApp';
  static const String _folderMimeType = 'application/vnd.google-apps.folder';
  static const String _jsonMimeType = 'application/json';

  DriveService._internal();

  String? _folderId;
  String? _cachedAccountId;

  Future<String> ensureNotesFolder() {
    return _withDriveApi((api) => _ensureNotesFolder(api));
  }

  Future<String> createNoteFile(Note note) {
    return _withDriveApi((api) async {
      final folderId = await _ensureNotesFolder(api);
      final content = _encodeNote(note);
      final metadata = drive.File(
        name: _fileNameFor(note),
        mimeType: _jsonMimeType,
        parents: [folderId],
      );

      final created = await api.files.create(
        metadata,
        uploadMedia: drive.Media(Stream.value(content), content.length),
        $fields: 'id',
      );

      final fileId = created.id;
      if (fileId == null || fileId.isEmpty) {
        throw const DriveServiceException(
          code: 'missing-file-id',
          message: 'Google Drive did not return a file identifier.',
        );
      }

      return fileId;
    });
  }

  Future<void> updateNoteFile({required String fileId, required Note note}) {
    return _withDriveApi((api) async {
      final content = _encodeNote(note);
      final metadata = drive.File();

      await api.files.update(
        metadata,
        fileId,
        uploadMedia: drive.Media(Stream.value(content), content.length),
        $fields: 'id',
      );
    });
  }

  Future<void> deleteNoteFile(String fileId) {
    return _withDriveApi((api) async {
      await api.files.delete(fileId);
    });
  }

  Future<List<Note>> listNotes() {
    return _withDriveApi((api) async {
      final folderId = await _ensureNotesFolder(api);
      final files = await _listJsonFiles(api, folderId);
      final notes = <Note>[];

      for (final file in files) {
        final fileId = file.id;
        if (fileId == null || fileId.isEmpty) continue;

        final raw = await _downloadFileText(api, fileId);
        final note = _decodeNote(
          raw,
          fileId: fileId,
          fallbackCreatedAt: file.createdTime,
          fallbackUpdatedAt: file.modifiedTime,
        );
        if (note != null) {
          notes.add(note);
        }
      }

      notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return notes;
    });
  }

  Future<T> _withDriveApi<T>(
    Future<T> Function(drive.DriveApi api) task,
  ) async {
    final account = await AuthService.instance.getSignedInGoogleAccount();
    if (account == null) {
      throw const DriveServiceException(
        code: 'auth-required',
        message: 'Sign in with Google to sync notes to Drive.',
      );
    }

    try {
      await AuthService.instance.ensureDriveAccess();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }

    if (_cachedAccountId != account.id) {
      _cachedAccountId = account.id;
      _folderId = null;
    }

    final client = await AuthService.instance.googleSignIn
        .authenticatedClient();
    if (client == null) {
      throw const DriveServiceException(
        code: 'drive-auth-failed',
        message: 'Unable to authorize Google Drive access.',
      );
    }

    final api = drive.DriveApi(client);
    try {
      return await task(api);
    } catch (error) {
      throw _mapError(error);
    } finally {
      client.close();
    }
  }

  DriveServiceException _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'drive-access-required':
        return const DriveServiceException(
          code: 'drive-access-required',
          message: 'Google Drive access is required to sync notes.',
        );
      case 'google-signin-config-error':
        return const DriveServiceException(
          code: 'auth-config-error',
          message:
              'Google Sign-In is not configured correctly for Android (SHA fingerprints missing in Firebase).',
        );
      case 'network-request-failed':
        return const DriveServiceException(
          code: 'network',
          message: 'Network error while authorizing Google Drive access.',
        );
      default:
        return const DriveServiceException(
          code: 'auth-required',
          message: 'Sign in with Google to sync notes to Drive.',
        );
    }
  }

  Future<String> _ensureNotesFolder(drive.DriveApi api) async {
    final cached = _folderId;
    if (cached != null && cached.isNotEmpty) return cached;

    final response = await api.files.list(
      q: "mimeType = '$_folderMimeType' and trashed = false and name = '$_folderName' and 'root' in parents",
      spaces: 'drive',
      pageSize: 1,
      $fields: 'files(id)',
    );

    final existing = response.files;
    if (existing != null && existing.isNotEmpty) {
      final existingId = existing.first.id;
      if (existingId != null && existingId.isNotEmpty) {
        _folderId = existingId;
        return existingId;
      }
    }

    final created = await api.files.create(
      drive.File(
        name: _folderName,
        mimeType: _folderMimeType,
        parents: const ['root'],
      ),
      $fields: 'id',
    );

    final folderId = created.id;
    if (folderId == null || folderId.isEmpty) {
      throw const DriveServiceException(
        code: 'folder-create-failed',
        message: 'Could not create MyNotesApp folder in Google Drive.',
      );
    }

    _folderId = folderId;
    return folderId;
  }

  Future<List<drive.File>> _listJsonFiles(
    drive.DriveApi api,
    String folderId,
  ) async {
    final files = <drive.File>[];
    String? pageToken;

    do {
      final response = await api.files.list(
        q: "'$folderId' in parents and trashed = false and mimeType = '$_jsonMimeType' and name contains '.json'",
        spaces: 'drive',
        orderBy: 'modifiedTime desc',
        pageSize: 1000,
        pageToken: pageToken,
        $fields: 'nextPageToken, files(id,name,createdTime,modifiedTime)',
      );

      files.addAll(response.files ?? const <drive.File>[]);
      pageToken = response.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    return files;
  }

  Future<String> _downloadFileText(drive.DriveApi api, String fileId) async {
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    if (media is! drive.Media) {
      throw const DriveServiceException(
        code: 'invalid-download',
        message: 'Unexpected Google Drive download response.',
      );
    }

    final bytes = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  List<int> _encodeNote(Note note) {
    final payload = <String, dynamic>{
      'id': note.id?.toString() ?? note.cloudId ?? '',
      'title': note.title,
      'content': note.content,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
      'color': note.color,
      'isPinned': note.isPinned,
      'category': note.category,
    };

    return utf8.encode(jsonEncode(payload));
  }

  Note? _decodeNote(
    String raw, {
    required String fileId,
    DateTime? fallbackCreatedAt,
    DateTime? fallbackUpdatedAt,
  }) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final json = Map<String, dynamic>.from(decoded);
      final pinnedValue = _parsePinnedValue(
        json['isPinned'] ?? json['is_pinned'],
      );
      final categoryValue = _parseCategoryValue(json['category']);

      final cloudMap = <String, dynamic>{
        'title': (json['title'] ?? 'Untitled').toString(),
        'content': (json['content'] ?? '').toString(),
        'created_at':
            json['createdAt'] ??
            json['created_at'] ??
            fallbackCreatedAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'updated_at':
            json['updatedAt'] ??
            json['updated_at'] ??
            fallbackUpdatedAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'color': (json['color'] ?? '4280391411').toString(),
        'is_pinned': pinnedValue,
        'category': categoryValue,
      };

      return Note.fromCloudMap(cloudMap, cloudId: fileId);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  bool _parsePinnedValue(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final value = raw.trim().toLowerCase();
      return value == 'true' || value == '1';
    }
    return false;
  }

  String? _parseCategoryValue(dynamic raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  String _fileNameFor(Note note) {
    final source =
        (note.id?.toString() ??
                note.cloudId ??
                DateTime.now().millisecondsSinceEpoch.toString())
            .trim();
    final safe = source.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final fileId = safe.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : safe;
    return '$fileId.json';
  }

  DriveServiceException _mapError(Object error) {
    if (error is DriveServiceException) return error;

    final status = _extractStatusCode(error);
    final reason = _extractErrorReason(error)?.toLowerCase();
    final message = _extractErrorMessage(error)?.toLowerCase();
    switch (status) {
      case 401:
        return const DriveServiceException(
          code: 'unauthorized',
          message: 'Google authorization expired. Sign in again.',
        );
      case 403:
        if (reason == 'accessnotconfigured' ||
            (message != null &&
                (message.contains('drive api has not been used') ||
                    message.contains('api is disabled')))) {
          return const DriveServiceException(
            code: 'drive-api-disabled',
            message:
                'Google Drive API is disabled for this project. Enable it in Google Cloud Console, then try again.',
          );
        }

        if (reason == 'insufficientpermissions' ||
            reason == 'insufficientfilepermissions') {
          return const DriveServiceException(
            code: 'permission-denied',
            message:
                'Google account signed in, but Drive scope is not granted. Remove app access in Google Account permissions and sign in again.',
          );
        }

        return const DriveServiceException(
          code: 'permission-denied',
          message:
              'Google Drive request was denied by Google. Check Drive API enablement and OAuth consent settings.',
        );
      case 404:
        return const DriveServiceException(
          code: 'not-found',
          message: 'Requested note file was not found in Google Drive.',
        );
      case 429:
        return const DriveServiceException(
          code: 'rate-limited',
          message: 'Google Drive rate limit reached. Try again shortly.',
        );
      default:
        return DriveServiceException(
          code: 'drive-error',
          message: 'Google Drive request failed: $error',
        );
    }
  }

  int? _extractStatusCode(Object error) {
    try {
      final dynamic dynamicError = error;
      final status = dynamicError.status;
      if (status is int) return status;
    } catch (_) {}

    final text = error.toString();
    final match = RegExp(r'status:\s*(\d{3})').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  String? _extractErrorReason(Object error) {
    try {
      final dynamic dynamicError = error;
      final errors = dynamicError.errors;
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        final reason = first.reason;
        if (reason is String && reason.trim().isNotEmpty) {
          return reason.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  String? _extractErrorMessage(Object error) {
    try {
      final dynamic dynamicError = error;
      final message = dynamicError.message;
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    } catch (_) {}
    return null;
  }
}
