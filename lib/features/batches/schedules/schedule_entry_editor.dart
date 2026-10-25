/// The form for one timetable row.
///
/// The sheet returns the edited [TimetableEntry]; the draft screen owns the
/// save so the repository stays the only validation authority. Fields the
/// reader corrects lose their OCR "not sure" label.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/batch.dart';
import '../../../models/batch_schedule.dart';
import '../../../widgets/tr_text.dart';
import '../widgets/batch_labels.dart';

class ScheduleEntryEditor extends StatefulWidget {
  const ScheduleEntryEditor({
    super.key,
    required this.original,
    required this.subjects,
  });

  final TimetableEntry original;
  final List<BatchSubject> subjects;

  @override
  State<ScheduleEntryEditor> createState() => _ScheduleEntryEditorState();
}

class _ScheduleEntryEditorState extends State<ScheduleEntryEditor> {
  late final TextEditingController _title;
  late final TextEditingController _room;
  late final TextEditingController _teacher;
  late int _day;
  late int _start;
  late int _end;
  late String _subjectId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.original.title);
    _room = TextEditingController(text: widget.original.room);
    _teacher = TextEditingController(text: widget.original.teacher);
    _day = widget.original.dayOfWeek;
    _start = widget.original.startMinutes;
    _end = widget.original.endMinutes;
    _subjectId = widget.original.subjectId ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _room.dispose();
    _teacher.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool start}) async {
    final minutes = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: start ? 'وقت البداية' : 'وقت النهاية',
      cancelText: 'إلغاء',
      confirmText: 'تمام',
    );
    if (picked == null || !mounted) return;
    setState(() {
      final value = picked.hour * 60 + picked.minute;
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
      _error = null;
    });
  }

  void _save() {
    final title = _title.text.trim();
    final room = _room.text.trim();
    final teacher = _teacher.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'العنوان مطلوب.');
      return;
    }
    if (title.runes.length > 120 ||
        room.runes.length > 120 ||
        teacher.runes.length > 120) {
      setState(() => _error = 'الحد ١٢٠ حرف للعنوان والقاعة والمدرس.');
      return;
    }
    if (_end < _start) {
      setState(() => _error = 'وقت النهاية لازم يكون بعد البداية.');
      return;
    }

    final uncertain = [...widget.original.uncertainFields];
    if (title != widget.original.title.trim()) uncertain.remove('title');
    if (_day != widget.original.dayOfWeek) uncertain.remove('dayOfWeek');
    if (_start != widget.original.startMinutes)
      uncertain.remove('startMinutes');
    if (_end != widget.original.endMinutes) uncertain.remove('endMinutes');

    Navigator.of(context).pop(
      TimetableEntry(
        id: widget.original.id,
        dayOfWeek: _day,
        startMinutes: _start,
        endMinutes: _end,
        title: title,
        subjectId: _subjectId.isEmpty ? null : _subjectId,
        room: room,
        teacher: teacher,
        confidence: widget.original.confidence,
        uncertainFields: uncertain,
        recurrence: widget.original.recurrence,
        weekAnchorDate: widget.original.weekAnchorDate,
        timeZoneId: widget.original.timeZoneId,
        reminderEnabled: widget.original.reminderEnabled,
        allDay: widget.original.allDay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          ZakerSpacing.sm,
          ZakerSpacing.lg,
          ZakerSpacing.lg + bottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              'الحصة',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: ZakerSpacing.md),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                hintText: 'مثال: رياضيات',
              ),
            ),
            const SizedBox(height: ZakerSpacing.md),
            const _FieldLabel('اليوم'),
            Wrap(
              spacing: ZakerSpacing.sm,
              runSpacing: ZakerSpacing.xs,
              children: [
                for (final day in scheduleWeekOrder)
                  ChoiceChip(
                    label: TrText(weekdayName(day)),
                    selected: _day == day,
                    onSelected: (_) => setState(() => _day = day),
                  ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(start: true),
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: TrText('من ${formatScheduleTime(_start)}'),
                  ),
                ),
                const SizedBox(width: ZakerSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(start: false),
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: TrText('لـ ${formatScheduleTime(_end)}'),
                  ),
                ),
              ],
            ),
            if (_end == _start) ...[
              const SizedBox(height: ZakerSpacing.xs),
              TrText(
                'وقت النهاية لسه مش محدد. الحصة دي مش هتتنشر غير لما تكمّلها.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: ZakerSpacing.md),
            const _FieldLabel('المادة'),
            Wrap(
              spacing: ZakerSpacing.sm,
              runSpacing: ZakerSpacing.xs,
              children: [
                ChoiceChip(
                  label: const TrText('من غير مادة'),
                  selected: _subjectId.isEmpty,
                  onSelected: (_) => setState(() => _subjectId = ''),
                ),
                for (final subject in widget.subjects)
                  ChoiceChip(
                    label: TrText(subject.name),
                    selected: _subjectId == subject.id,
                    onSelected: (_) => setState(() => _subjectId = subject.id),
                  ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _room,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'القاعة'),
                  ),
                ),
                const SizedBox(width: ZakerSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _teacher,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'المدرس'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.sm),
            TrText(
              'الوقت بتوقيت جهازك. مفيش منطقة زمنية أو تاريخ محفوظ من الصورة.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: ZakerSpacing.sm),
              TrText(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: ZakerSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const TrText('حفظ الحصة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.xs),
      child: TrText(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
