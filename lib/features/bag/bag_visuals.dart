/// The bag's icons and folder palette.
library;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';

const Map<String, List<List<dynamic>>> _bagIcons = {
  'Math': HugeIcons.strokeRoundedMath,
  'Atom01': HugeIcons.strokeRoundedAtom01,
  'Chemistry01': HugeIcons.strokeRoundedChemistry01,
  'Microscope': HugeIcons.strokeRoundedMicroscope,
  'BookOpen01': HugeIcons.strokeRoundedBookOpen01,
  'Translate': HugeIcons.strokeRoundedTranslate,
  'Languages': HugeIcons.strokeRoundedLanguages,
  'History': HugeIcons.strokeRoundedHistory,
  'Earth': HugeIcons.strokeRoundedEarth,
  'Brain01': HugeIcons.strokeRoundedBrain01,
  'Quran01': HugeIcons.strokeRoundedQuran01,
  'Computer': HugeIcons.strokeRoundedComputer,
  'Palette': HugeIcons.strokeRoundedPalette,
  'SportShoe': HugeIcons.strokeRoundedSportShoe,
  'Folder01': HugeIcons.strokeRoundedFolder01,
};

/// The icon a folder name maps to, falling back to a plain folder.
List<List<dynamic>> bagIcon(String name) =>
    _bagIcons[name] ?? HugeIcons.strokeRoundedFolder01;

/// The colours a folder can take; all are real theme tokens.
final List<Color> kBagFolderColors = [
  ZakerColors.navy,
  ZakerColors.backpack,
  ZakerColors.goldDeep,
  ZakerColors.success,
  ZakerColors.navyLight,
  ZakerColors.danger,
];
