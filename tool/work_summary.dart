// Builds the PDF summary of the work that was delivered.
//
// Run it from the project root:
//
//   dart run tool/work_summary.dart
//
// The document lands in docs/PAY_CAL_WORK_SUMMARY.pdf.
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _ink = PdfColor.fromInt(0xFF0A0A0A);
const _grey = PdfColor.fromInt(0xFF6B6B6B);
const _lime = PdfColor.fromInt(0xFFD7F75B);
const _pink = PdfColor.fromInt(0xFFF0477F);
const _hairline = PdfColor.fromInt(0xFFE3E3E3);

final _today = DateTime.now();
final _date = '${_today.day} ${_month(_today.month)} ${_today.year}';

String _month(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

Future<pw.Font> _font(String path) async {
  final bytes = await File(path).readAsBytes();
  return pw.Font.ttf(ByteData.sublistView(bytes));
}

pw.Widget _tag(String label, PdfColor color) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: pw.BoxDecoration(
    color: color,
    borderRadius: pw.BorderRadius.circular(6),
  ),
  child: pw.Text(
    label,
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: _ink),
  ),
);

pw.Widget _sectionTitle(String title, pw.Font bold) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.center,
  children: [
    pw.Container(width: 10, height: 10, decoration: const pw.BoxDecoration(color: _pink)),
    pw.SizedBox(width: 8),
    pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 14, color: _ink)),
  ],
);

pw.Widget _card({
  required String title,
  required String body,
  required List<String> facts,
  required pw.Font regular,
  required pw.Font bold,
  PdfColor accent = _lime,
}) => pw.Container(
  padding: const pw.EdgeInsets.all(14),
  decoration: pw.BoxDecoration(
    border: pw.Border.all(color: _ink, width: 1.1),
    borderRadius: pw.BorderRadius.circular(12),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              title,
              style: pw.TextStyle(font: bold, fontSize: 12, color: _ink),
            ),
          ),
          pw.SizedBox(width: 8),
          _tag('done', accent),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Text(body, style: pw.TextStyle(font: regular, fontSize: 9.5, color: _ink)),
      pw.SizedBox(height: 10),
      pw.Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final fact in facts)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _hairline),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Text(
                fact,
                style: pw.TextStyle(font: regular, fontSize: 7.5, color: _grey),
              ),
            ),
        ],
      ),
    ],
  ),
);

Future<void> main() async {
  final regular = await _font('assets/fonts/SpaceGrotesk-400.ttf');
  final bold = await _font('assets/fonts/SpaceGrotesk-700.ttf');

  final document = pw.Document(title: 'PayCal · work summary', author: 'PayCal');

  document.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _hairline)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'PayCal · work summary · $_date',
              style: pw.TextStyle(font: regular, fontSize: 8, color: _grey),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(font: regular, fontSize: 8, color: _grey),
            ),
          ],
        ),
      ),
      build: (context) => [
        // Header
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PayCal', style: pw.TextStyle(font: bold, fontSize: 11, color: _grey)),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Work summary',
                  style: pw.TextStyle(font: bold, fontSize: 26, color: _ink),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Invitations, membership, exports and the split between '
                  'instant notifications and scheduled reminders.',
                  style: pw.TextStyle(font: regular, fontSize: 10, color: _grey),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(color: _lime, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Text(_date, style: pw.TextStyle(font: bold, fontSize: 9, color: _ink)),
            ),
          ],
        ),
        pw.SizedBox(height: 20),

        // The request
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _ink, width: 1.2),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('The request', style: pw.TextStyle(font: bold, fontSize: 12, color: _ink)),
              pw.SizedBox(height: 6),
              pw.Text(
                'Three gaps in the product were picked out of the audit list and '
                'delivered end to end, together with a split of the push '
                'notifications into the ones that have to arrive at once and '
                'the ones that belong on the fifteen minute schedule.',
                style: pw.TextStyle(font: regular, fontSize: 9.5, color: _ink),
              ),
              pw.SizedBox(height: 8),
              pw.Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in const [
                    '1 · an invitation link that works while signed out',
                    '2 · leaving a crib and handing it over',
                    '6 · exporting the history as a PDF',
                    'plus · instant transactional push, scheduled reminders',
                  ])
                    pw.Text(
                      item,
                      style: pw.TextStyle(font: regular, fontSize: 9, color: _ink),
                    ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        _sectionTitle('What was built', bold),
        pw.SizedBox(height: 10),

        _card(
          title: 'An invitation link that survives a signed out phone',
          body:
              'Opening an invitation while signed out used to fail and the link '
              'was lost. The token is now kept on the device, the app shows an '
              '"You are invited" card, and the moment the person has an account '
              'the crib joins itself. A dead invitation now explains itself '
              'instead of showing a network error.',
          facts: const [
            'lib/core/utils/deep_link.dart',
            'lib/data/pending_invitation.dart',
            'lib/app/paycal_app.dart',
            'lib/features/shell/main_shell.dart',
          ],
          regular: regular,
          bold: bold,
        ),
        pw.SizedBox(height: 12),

        _card(
          title: 'Leaving a crib and handing it over',
          body:
              'A member can leave a crib on their own; the membership keeps its '
              'history, so the expenses of somebody who left keep validating, '
              'and the recurring payments they paid for pause instead of running '
              'without a payer. The owner hands the crib over to another member; '
              'the owner cannot leave a crib that still belongs to them, so a '
              'crib never ends up without an owner.',
          facts: const [
            'public.leave_crib',
            'public.transfer_crib_ownership',
            'lib/data/supabase_crib_repository.dart',
            'lib/features/cribs/crib_detail_screen.dart',
          ],
          regular: regular,
          bold: bold,
          accent: PdfColor.fromInt(0xFFBFE9FF),
        ),
        pw.SizedBox(height: 12),

        _card(
          title: 'The history as a PDF',
          body:
              'The crib sheet gained an export. The document carries the same '
              'numbers as the app, because both come from the same ledger: what '
              'was spent, what every member owes, the expenses and the '
              'settlements. It is shared through the system sheet and is built '
              'on the phone, with the fonts of the app.',
          facts: const [
            'lib/core/export/ledger_pdf.dart',
            'lib/core/export/export_ledger.dart',
            'package:pdf 3.13.1',
          ],
          regular: regular,
          bold: bold,
          accent: PdfColor.fromInt(0xFFFFE0A3),
        ),
        pw.SizedBox(height: 12),

        _card(
          title: 'Notifications that arrive at once, reminders that do not',
          body:
              'Transactional notifications used to wait for the sweep of the '
              'scheduler. The device of the member who did something now asks '
              'for the transactional notifications to go out right away, and '
              'only those: a recurring reminder keeps the pace of the fifteen '
              'minute schedule and is never delivered early by a device.',
          facts: const [
            'lib/core/notifications/notification_dispatcher.dart',
            'public.claim_push_transactional_jobs',
            'supabase/functions/dispatch-notifications',
            'cron · every 15 minutes',
          ],
          regular: regular,
          bold: bold,
          accent: PdfColor.fromInt(0xFFD7F75B),
        ),
        pw.SizedBox(height: 20),

        _sectionTitle('Two problems found on the phone', bold),
        pw.SizedBox(height: 10),
        _card(
          title: 'The channel of the reminders was created too late',
          body:
              'A push that reaches a closed app is handled before any activity '
              'starts, so a channel that only the activity created did not exist '
              'yet and the reminder landed in a silent fallback channel that '
              'never showed up. The channel is now created by the application, '
              'before anything else runs.',
          facts: const [
            'android/app/src/main/kotlin/.../PayCalApplication.kt',
            'android/app/src/main/AndroidManifest.xml',
          ],
          regular: regular,
          bold: bold,
          accent: PdfColor.fromInt(0xFFFFC9C9),
        ),
        pw.SizedBox(height: 12),
        _card(
          title: 'The device was registered without the permission to show anything',
          body:
              'Notifications are on by default, but the system permission was '
              'only asked for in a settings sheet that nobody had to open. The '
              'device was registered with the backend and the system dropped '
              'every notification before it was shown. The permission is now '
              'asked the first time the device talks to the backend.',
          facts: const ['lib/core/notifications/push_notification_service.dart'],
          regular: regular,
          bold: bold,
          accent: PdfColor.fromInt(0xFFFFC9C9),
        ),
        pw.SizedBox(height: 20),

        _sectionTitle('How it was verified', bold),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _hairline),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final line in const [
                'The database: the new functions were called against the live '
                    'database with real accounts. Leaving twice, leaving as the '
                    'owner and handing over to somebody who is not a member are '
                    'all refused with the right message, the handover moves the '
                    'ownership, and the claim of the transactional rows is '
                    'closed for anybody who is not signed in.',
                'The function: the member path, the scheduler path and the '
                    'operations path were each called with the header they use. '
                    'A member claims the transactional rows only, the scheduler '
                    'claims everything, and a request without a token is '
                    'answered with 401.',
                'The phone: an expense added by another member reached the device '
                    'within seconds, on the channel paycal_reminders, with the '
                    'title "PayCal update" and the body of the expense.',
                'The build: flutter analyze is clean and the whole suite of 292 '
                    'tests passes, including ten new ones about leaving, '
                    'handing over, the signed out invitation and the PDF.',
              ]) ...[
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 5,
                      height: 5,
                      margin: const pw.EdgeInsets.only(top: 4, right: 8),
                      decoration: const pw.BoxDecoration(color: _lime),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        line,
                        style: pw.TextStyle(font: regular, fontSize: 9.5, color: _ink),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        _sectionTitle('What is still open', bold),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _hairline),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final line in const [
                'iOS: the app needs an APNs authentication key in Firebase and a '
                    'real device before a push can be verified there. The '
                    'Android path is done.',
                'Mail: there is no custom SMTP yet, so the confirmation mail is '
                    'limited to two an hour and the address is confirmed '
                    'without a link. That is a stop gap, not a decision.',
                'The cadence of the recurring reminders is fifteen minutes. A '
                    'reminder can therefore arrive up to fifteen minutes late; '
                    'a shorter cadence is a change of the schedule, not of the '
                    'code.',
              ]) ...[
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 5,
                      height: 5,
                      margin: const pw.EdgeInsets.only(top: 4, right: 8),
                      decoration: const pw.BoxDecoration(color: _pink),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        line,
                        style: pw.TextStyle(font: regular, fontSize: 9.5, color: _ink),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  final file = File('docs/PAY_CAL_WORK_SUMMARY.pdf');
  await file.writeAsBytes(await document.save());
  stdout.writeln('Wrote ${file.path}');
}
