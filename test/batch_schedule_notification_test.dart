import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/features/prayer/adhan_launch.dart';

void main() {
  test('a batch reminder opens the timetable of its batch', () {
    expect(
      batchScheduleLocation({
        'type': 'batch_schedule',
        'batchId': 'abc_123',
        'draftId': 'schedule_x',
        'entryId': 'slot_1',
      }),
      '/batches/abc_123/schedules',
    );
  });

  test('another payload is not routed as a batch reminder', () {
    expect(batchScheduleLocation({'type': 'adhan'}), isNull);
    expect(batchScheduleLocation({'type': 'batch_schedule'}), isNull);
    expect(batchScheduleLocation(const {}), isNull);
  });

  test('a malformed batch id never reaches the route', () {
    expect(
      batchScheduleLocation({
        'type': 'batch_schedule',
        'batchId': '../../escape',
      }),
      isNull,
    );
    expect(
      batchScheduleLocation({'type': 'batch_schedule', 'batchId': ''}),
      isNull,
    );
    expect(
      batchScheduleLocation({
        'type': 'batch_schedule',
        'batchId': 'a' * 65,
      }),
      isNull,
    );
    expect(
      batchScheduleLocation({'type': 'batch_schedule', 'batchId': 42}),
      isNull,
    );
  });
}
