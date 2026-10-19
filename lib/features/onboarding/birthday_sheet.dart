import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_bottom_sheet.dart';
import 'package:paycal/core/widgets/primary_button.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

/// Bottom three-column wheel picker (day / month / year) per guide S3.
Future<DateTime?> showBirthdaySheet({
  required BuildContext context,
  required DateTime initial,
  required DateTime maxDate,
}) {
  var day = initial.day;
  var month = initial.month;
  var year = initial.year;

  return showAppBottomSheet<DateTime>(
    context: context,
    title: 'Your birthday',
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) {
        final maxDay = _daysIn(year, month);
        if (day > maxDay) day = maxDay;
        return Column(
          children: [
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  _wheel(
                    count: maxDay,
                    initial: day - 1,
                    label: (i) => '${i + 1}',
                    onSelect: (i) => setState(() => day = i + 1),
                  ),
                  _wheel(
                    count: 12,
                    initial: month - 1,
                    label: (i) => _months[i],
                    onSelect: (i) => setState(() => month = i + 1),
                  ),
                  _wheel(
                    count: maxDate.year - 1900 + 1,
                    initial: (year - 1900).clamp(0, maxDate.year - 1900),
                    label: (i) => '${1900 + i}',
                    onSelect: (i) => setState(() => year = 1900 + i),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Done',
              onPressed: () {
                var picked = DateTime(year, month, day);
                if (picked.isAfter(maxDate)) {
                  picked = DateTime(maxDate.year, maxDate.month, maxDate.day);
                }
                Navigator.of(sheetContext).pop(picked);
              },
            ),
          ],
        );
      },
    ),
  );
}

Widget _wheel({
  required int count,
  required int initial,
  required String Function(int) label,
  required ValueChanged<int> onSelect,
}) {
  return Expanded(
    child: ListWheelScrollView.useDelegate(
      itemExtent: 44,
      diameterRatio: 1.4,
      physics: const FixedExtentScrollPhysics(),
      controller: FixedExtentScrollController(
        initialItem: initial.clamp(0, count - 1),
      ),
      onSelectedItemChanged: onSelect,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, i) => Center(
          child: Text(
            label(i),
            style: AppTypography.titleSmall.copyWith(
              color: AppPalette.current.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}
