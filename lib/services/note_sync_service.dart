import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import 'auth_service.dart';

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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('notes');
  }

  Future<void> syncAllNotes() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      final notesRef = _notesRef(user.uid);
      final localNotes = await DatabaseHelper.instance.getAllNotes();
      final cloudSnapshot = await notesRef.get();
      final cloudNotes = cloudSnapshot.docs
          .map((doc) => Note.fromCloudMap(doc.data(), cloudId: doc.id))
          .toList();

      final cloudById = <String, Note>{
        for (final note in cloudNotes)
          if (note.cloudId != null) note.cloudId!: note,
      };
      final syncedCloudIds = <String>{};

      for (final localNote in localNotes) {
        final cloudId = localNote.cloudId;
        if (cloudId == null || cloudId.isEmpty) {
          final docRef = notesRef.doc();
          await docRef.set(localNote.toCloudMap());
          localNote.cloudId = docRef.id;
          await DatabaseHelper.instance.updateNote(localNote);
          syncedCloudIds.add(docRef.id);
          continue;
        }

        final cloudNote = cloudById[cloudId];
        if (cloudNote == null) {
          await notesRef.doc(cloudId).set(localNote.toCloudMap());
          syncedCloudIds.add(cloudId);
          continue;
        }

        syncedCloudIds.add(cloudId);
        if (localNote.updatedAt.isAfter(cloudNote.updatedAt)) {
          await notesRef.doc(cloudId).set(localNote.toCloudMap());
        } else if (cloudNote.updatedAt.isAfter(localNote.updatedAt)) {
          cloudNote.id = localNote.id;
          await DatabaseHelper.instance.updateNote(cloudNote);
        }
      }

      for (final cloudNote in cloudNotes) {
        final cloudId = cloudNote.cloudId;
        if (cloudId == null || syncedCloudIds.contains(cloudId)) {
          continue;
        }

        await DatabaseHelper.instance.upsertByCloudId(cloudNote);
      }
    } on FirebaseException catch (e) {
      throw _toSyncException(e);
    } catch (e) {
      throw NoteSyncException(
        message: 'Cloud sync failed unexpectedly. Please try again.',
        code: 'unknown',
      );
    }
  }

  Future<void> upsertNote(Note note) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      final notesRef = _notesRef(user.uid);
      final cloudId = note.cloudId;

      if (cloudId == null || cloudId.isEmpty) {
        final docRef = notesRef.doc();
        await docRef.set(note.toCloudMap());
        note.cloudId = docRef.id;
        await DatabaseHelper.instance.updateNote(note);
        return;
      }

      await notesRef.doc(cloudId).set(note.toCloudMap());
    } on FirebaseException catch (e) {
      throw _toSyncException(e);
    } catch (_) {
      throw const NoteSyncException(
        message: 'Unable to sync this note right now.',
        code: 'unknown',
      );
    }
  }

  Future<void> deleteNoteFromCloud(Note note) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      final cloudId = note.cloudId;
      if (cloudId == null || cloudId.isEmpty) return;

      await _notesRef(user.uid).doc(cloudId).delete();
    } on FirebaseException catch (e) {
      throw _toSyncException(e);
    } catch (_) {
      throw const NoteSyncException(
        message: 'Unable to remove note from cloud right now.',
        code: 'unknown',
      );
    }
  }

  NoteSyncException _toSyncException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const NoteSyncException(
          code: 'permission-denied',
          message:
              'Cloud sync blocked by Firestore rules. Update rules for this user.',
        );
      case 'failed-precondition':
        return const NoteSyncException(
          code: 'failed-precondition',
          message:
              'Cloud Firestore is not ready for this project. Enable Firestore in Firebase Console.',
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return const NoteSyncException(
          code: 'network',
          message: 'No internet or Firestore unavailable. Using offline notes.',
        );
      default:
        return NoteSyncException(
          code: e.code,
          message: 'Cloud sync failed (${e.code}). Using offline notes.',
        );
    }
  }
}
