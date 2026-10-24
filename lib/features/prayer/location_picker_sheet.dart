/// The offline city picker and the manual-coordinates dialog.
///
/// Both return a [PrayerLocation] to the caller; neither saves anything on its
/// own, so the same widgets can be used from the first-run flow, the prayer
/// screen and the home card.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/egypt_cities.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'prayer_models.dart';
import 'prayer_service.dart';

/// Opens the searchable list of Egyptian governorates and cities.
Future<PrayerLocation?> showCityPicker(
  BuildContext context, {
  PrayerLocation? current,
}) {
  return showModalBottomSheet<PrayerLocation>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _CityPickerSheet(current: current),
  );
}

/// Opens the two-field manual coordinate dialog.
Future<PrayerLocation?> showManualCoordinatesDialog(
  BuildContext context, {
  PrayerLocation? initial,
}) {
  return showDialog<PrayerLocation>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ManualCoordinatesDialog(initial: initial),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({this.current});

  final PrayerLocation? current;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final maxHeight = media.size.height * 0.92;
    // Never let the lower bound exceed the upper one on very short screens.
    final height = math.min(
      math.max(
        (media.size.height - keyboard) * 0.90,
        math.min(320.0, maxHeight),
      ),
      maxHeight,
    );
    final rows = _rowsFor(_search.text);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboard),
      child: Material(
        color: theme.scaffoldBackgroundColor,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.25,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [ZakerColors.primary, Color(0xFF0D9488)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: ZakerColors.primary.withValues(alpha: 0.30),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedMosqueLocation,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrText(
                            'اختار مدينتك',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 1),
                          TrText(
                            'كل محافظات مصر — من غير إنترنت',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 22),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المدينة أو المحافظة',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 21),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                    filled: true,
                    fillColor: theme.cardTheme.color,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.dividerTheme.color ?? Colors.black12,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.dividerTheme.color ?? Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? _NoCityFound(onManual: () => _openManual(context))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          if (row.title != null) {
                            return _GovernorateHeader(title: row.title!);
                          }
                          return _CityTile(
                            city: row.city!,
                            selected: _isCurrent(row.city!),
                            onTap: () =>
                                Navigator.of(context)
                                    .pop(locationFromCity(row.city!)),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  border: Border(
                    top: BorderSide(
                      color: theme.dividerTheme.color ?? Colors.black12,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrText(
                            'مش لاقي مدينتك؟',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TrText(
                            'أدخل خط العرض والطول يدويًا',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openManual(context),
                      icon: const Icon(
                        Icons.edit_location_alt_outlined,
                        size: 17,
                      ),
                      label: const TrText(
                        'إحداثيات يدوية',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isCurrent(EgyptCity city) {
    final current = widget.current;
    if (current == null) return false;
    if (current.city.trim() == city.name) return true;
    return (current.latitude - city.latitude).abs() < 0.01 &&
        (current.longitude - city.longitude).abs() < 0.01;
  }

  Future<void> _openManual(BuildContext context) async {
    final location = await showManualCoordinatesDialog(
      context,
      initial: widget.current,
    );
    if (!context.mounted || location == null) return;
    Navigator.of(context).pop(location);
  }

  List<_CityRow> _rowsFor(String query) {
    final groups = groupEgyptCities(searchEgyptCities(query));
    return [
      for (final group in groups) ...[
        _CityRow.header(group.key),
        for (final city in group.value) _CityRow.city(city),
      ],
    ];
  }
}

class _CityRow {
  const _CityRow.header(this.title) : city = null;

  const _CityRow.city(this.city) : title = null;

  final String? title;
  final EgyptCity? city;
}

class _GovernorateHeader extends StatelessWidget {
  const _GovernorateHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          TrText(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({
    required this.city,
    required this.selected,
    required this.onTap,
  });

  final EgyptCity city;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.20 : 0.09)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.18 : 0.08,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedLocation01,
                      size: 17,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrText(
                        city.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      TrText(
                        city.governorate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  city.coordinates,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.8,
                    ),
                    fontSize: 9.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoCityFound extends StatelessWidget {
  const _NoCityFound({required this.onManual});

  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.travel_explore_rounded,
                size: 30,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            TrText(
              'مفيش مدينة بالاسم ده',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            TrText(
              'جرّب اسم تاني، أو أدخل الإحداثيات بنفسك.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onManual,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: const TrText('إدخال الإحداثيات'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualCoordinatesDialog extends StatefulWidget {
  const _ManualCoordinatesDialog({this.initial});

  final PrayerLocation? initial;

  @override
  State<_ManualCoordinatesDialog> createState() =>
      _ManualCoordinatesDialogState();
}

class _ManualCoordinatesDialogState extends State<_ManualCoordinatesDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _latitude = TextEditingController(
    text: widget.initial?.latitude.toStringAsFixed(4) ?? '',
  );
  late final TextEditingController _longitude = TextEditingController(
    text: widget.initial?.longitude.toStringAsFixed(4) ?? '',
  );

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 6),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.my_location_rounded,
              size: 21,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: TrText(
              'إحداثيات يدوية',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              'اكتب خط العرض وخط الطول لموقعك. تقدر تجيبهم من تطبيق الخرائط '
              'بالضغط مطولًا على المكان.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _latitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫\-+]')),
              ],
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'خط العرض (Latitude)',
                hintText: '30.0444',
                helperText: 'من -90 إلى 90',
                prefixIcon: Icon(Icons.north_rounded, size: 19),
                border: OutlineInputBorder(),
              ),
              validator: (value) => _validate(value, latitude: true),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _longitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫\-+]')),
              ],
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'خط الطول (Longitude)',
                hintText: '31.2357',
                helperText: 'من -180 إلى 180',
                prefixIcon: Icon(Icons.east_rounded, size: 19),
                border: OutlineInputBorder(),
              ),
              validator: (value) => _validate(value, latitude: false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const TrText('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const TrText('حفظ الموقع'),
        ),
      ],
    );
  }

  String? _validate(String? raw, {required bool latitude}) {
    final text = _normalizeNumber(raw ?? '');
    if (text.isEmpty) return 'مطلوب';
    final value = double.tryParse(text);
    if (value == null || !value.isFinite) return 'رقم غير صحيح';
    final limit = latitude ? 90.0 : 180.0;
    if (value < -limit || value > limit) {
      return latitude ? 'من -90 إلى 90' : 'من -180 إلى 180';
    }
    return null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final latitude = double.parse(_normalizeNumber(_latitude.text));
    final longitude = double.parse(_normalizeNumber(_longitude.text));
    Navigator.of(context).pop(
      PrayerLocation(
        latitude: latitude,
        longitude: longitude,
        city: 'موقع مخصص',
        region: 'إحداثيات يدوية',
      ),
    );
  }
}

String _normalizeNumber(String value) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  var text = value;
  for (var i = 0; i < eastern.length; i++) {
    text = text.replaceAll(eastern[i], '$i');
  }
  return text
      .replaceAll('٫', '.')
      .replaceAll(',', '.')
      .replaceAll(' ', '')
      .trim();
}
