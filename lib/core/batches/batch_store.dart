/// The per-batch documents: identity, updates, exams, schedules, audit, chat.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/batch.dart';
import '../../models/batch_chat.dart';
import '../../models/batch_exam.dart';
import '../../models/batch_resource.dart';
import '../../models/batch_schedule.dart';
import '../../models/batch_update.dart';
import 'document_store.dart';

/// Everything in `batch.json`: identity, members, settings, subjects, code and
/// the resource index.
class BatchSnapshot {
  const BatchSnapshot({
    required this.batch,
    required this.members,
    this.resources = const [],
  });

  final Batch batch;
  final List<Membership> members;
  final List<BatchResource> resources;

  BatchSnapshot copyWith({
    Batch? batch,
    List<Membership>? members,
    List<BatchResource>? resources,
  }) =>
      BatchSnapshot(
        batch: batch ?? this.batch,
        members: members ?? this.members,
        resources: resources ?? this.resources,
      );

  Map<String, dynamic> toJson() => {
        'batch': batch.toJson(),
        'members': [for (final member in members) member.toJson()],
        'resources': [for (final resource in resources) resource.toJson()],
      };

  factory BatchSnapshot.fromJson(Map<String, dynamic> json) => BatchSnapshot(
        batch: Batch.fromJson({
          if (json['batch'] is Map)
            ...Map<String, dynamic>.from(json['batch'] as Map),
        }),
        members: [
          for (final raw in (json['members'] as List? ?? const []))
            if (raw is Map) Membership.fromJson(Map<String, dynamic>.from(raw)),
        ],
        resources: [
          for (final raw in (json['resources'] as List? ?? const []))
            if (raw is Map)
              BatchResource.fromJson(Map<String, dynamic>.from(raw)),
        ],
      );
}

/// Opens the documents that live inside one batch directory.
class BatchStore {
  BatchStore({required this.directory});

  final Directory directory;

  static const int schema = 1;

  File get batchFile => File(p.join(directory.path, 'batch.json'));
  File get updatesFile => File(p.join(directory.path, 'updates.json'));
  File get examsFile => File(p.join(directory.path, 'exams.json'));
  File get schedulesFile => File(p.join(directory.path, 'schedules.json'));
  File get auditFile => File(p.join(directory.path, 'audit.json'));
  File get chatFile => File(p.join(directory.path, 'chat', 'main.json'));

  DocumentStore<BatchSnapshot> get batch => DocumentStore(
        file: batchFile,
        schema: schema,
        encode: (value) => value.toJson(),
        decode: BatchSnapshot.fromJson,
      );

  DocumentStore<List<BatchUpdate>> get updates => DocumentStore(
        file: updatesFile,
        schema: schema,
        encode: (value) => {
          'items': [for (final item in value) item.toJson()],
        },
        decode: (json) => [
          for (final raw in (json['items'] as List? ?? const []))
            if (raw is Map)
              BatchUpdate.fromJson(Map<String, dynamic>.from(raw)),
        ],
      );

  DocumentStore<List<BatchExam>> get exams => DocumentStore(
        file: examsFile,
        schema: schema,
        encode: (value) => {
          'items': [for (final item in value) item.toJson()],
        },
        decode: (json) => [
          for (final raw in (json['items'] as List? ?? const []))
            if (raw is Map) BatchExam.fromJson(Map<String, dynamic>.from(raw)),
        ],
      );

  DocumentStore<List<TimetableDraft>> get schedules => DocumentStore(
        file: schedulesFile,
        schema: schema,
        encode: (value) => {
          'items': [for (final item in value) item.toJson()],
        },
        decode: (json) => [
          for (final raw in (json['items'] as List? ?? const []))
            if (raw is Map)
              TimetableDraft.fromJson(Map<String, dynamic>.from(raw)),
        ],
      );

  DocumentStore<List<AuditEntry>> get audit => DocumentStore(
        file: auditFile,
        schema: schema,
        encode: (value) => {
          'items': [for (final item in value) item.toJson()],
        },
        decode: (json) => [
          for (final raw in (json['items'] as List? ?? const []))
            if (raw is Map) AuditEntry.fromJson(Map<String, dynamic>.from(raw)),
        ],
      );

  DocumentStore<List<ChatMessage>> get chat => DocumentStore(
        file: chatFile,
        schema: schema,
        encode: (value) => {
          'items': [for (final item in value) item.toJson()],
        },
        decode: (json) => [
          for (final raw in (json['items'] as List? ?? const []))
            if (raw is Map)
              ChatMessage.fromJson(Map<String, dynamic>.from(raw)),
        ],
      );

  Directory get attemptsDirectory =>
      Directory(p.join(directory.path, 'attempts'));

  File attemptFile({required String examId, required String attemptId}) {
    return File(p.join(attemptsDirectory.path, examId, '$attemptId.json'));
  }

  DocumentStore<ExamAttempt> attempt({
    required String examId,
    required String attemptId,
  }) =>
      DocumentStore(
        file: attemptFile(examId: examId, attemptId: attemptId),
        schema: schema,
        encode: (value) => value.toJson(),
        decode: ExamAttempt.fromJson,
      );

  File voiceFile(String messageId) =>
      File(p.join(directory.path, 'chat', 'voice', '$messageId.m4a'));
}
