/// Providers that wire the bag to the app's grade, catalog and lesson state.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/my_bag/my_bag_controller.dart';
import '../core/my_bag/my_bag_models.dart';
import '../core/my_bag/my_bag_store.dart';
import '../core/official_subject_index.dart';
import '../core/study_library.dart';
import '../models/manhaji.dart';
import 'app_providers.dart';

final myBagRootDirProvider = Provider<Directory>(
  (ref) => throw StateError('myBagRootDirProvider must be overridden'),
);

final myBagStoreProvider = Provider<MyBagStore>(
  (ref) => MyBagStore(
    kv: ref.watch(localStoreProvider),
    rootDir: ref.watch(myBagRootDirProvider),
  ),
);

final bagSeedSubjectsProvider = Provider<List<MyBagSubjectSeed>>((ref) {
  final gradeId = ref.watch(selectedGradeProvider);
  final grades = ref.watch(gradesProvider).valueOrNull ?? const <Grade>[];
  Grade? grade;
  for (final item in grades) {
    if (item.id == gradeId) {
      grade = item;
      break;
    }
  }
  if (grade == null) return const [];
  final catalog = ref.watch(officialBooksProvider).valueOrNull;
  return [
    for (final subject in studySubjects(
      grade,
      const <String>{},
      officialCatalog: catalog,
    ))
      MyBagSubjectSeed(
        gradeId: gradeId,
        subjectKey: officialSubjectKey(subject.name),
        name: subject.name,
        colorValue: studySubjectVisual(subject.name).color.toARGB32(),
      ),
  ];
});

final myBagControllerProvider =
    StateNotifierProvider<MyBagController, MyBagState>((ref) {
  final controller = MyBagController(store: ref.watch(myBagStoreProvider));
  unawaited(controller.syncSeeds(ref.watch(bagSeedSubjectsProvider)));
  return controller;
});

final bagSubjectProgressProvider = Provider<Map<String, double>>((ref) {
  final grades = ref.watch(gradesProvider).valueOrNull ?? const <Grade>[];
  final read = ref.watch(readLessonsProvider);
  final catalog = ref.watch(officialBooksProvider).valueOrNull;
  final result = <String, double>{};
  for (final grade in grades) {
    for (final subject in studySubjects(
      grade,
      read,
      officialCatalog: catalog,
    )) {
      result[bagProgressKey(grade.id, officialSubjectKey(subject.name))] =
          subject.lessons == 0 ? 0 : subject.readLessons / subject.lessons;
    }
  }
  return result;
});
