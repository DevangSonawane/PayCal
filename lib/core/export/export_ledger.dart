import 'package:flutter/foundation.dart';
import 'package:paycal/core/export/ledger_pdf.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/member_directory.dart';
import 'package:paycal/data/models.dart';
import 'package:share_plus/share_plus.dart';

/// Builds the PDF of a crib and hands it to the share sheet.
///
/// The member can save it, send it to a roommate or open it in any app that
/// reads a PDF. The file never leaves the device before the member picked
/// where it goes.
Future<void> shareCribHistory(Crib crib) async {
  final repositories = PayCalRepositories.instance;
  final memberId = repositories.currentUserId;
  final bytes = await LedgerPdf.build(
    crib: crib,
    expenses: repositories.expenses.cachedExpenses
        .where((expense) => expense.cribId == crib.id)
        .toList(growable: false),
    settlements: repositories.settlements.cachedSettlements
        .where((settlement) => settlement.cribId == crib.id)
        .toList(growable: false),
    memberId: memberId,
    memberName: MemberDirectory.nameFor(memberId),
  );
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          bytes,
          mimeType: 'application/pdf',
          name: 'paycal-${_fileName(crib.name)}.pdf',
        ),
      ],
      title: '${crib.name} · PayCal',
      subject: '${crib.name} · PayCal history',
    ),
  );
}

/// A file name that survives every file system.
String _fileName(String name) {
  final clean = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return clean.isEmpty ? 'crib' : clean;
}

/// Reports a failed export without taking the member out of the crib.
void logExportFailure(Object error) =>
    debugPrint('Could not export the history: $error');
