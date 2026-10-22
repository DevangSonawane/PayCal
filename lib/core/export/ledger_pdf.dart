import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/domain/financial_ledger.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds the PDF of a crib: what was spent, who paid for it, what is owed
/// and what was already settled.
///
/// The document is the offline copy of the crib. It carries the same numbers
/// as the app, because both come from the same ledger.
class LedgerPdf {
  const LedgerPdf._();

  static const _ink = PdfColor.fromInt(0xFF0A0A0A);
  static const _grey = PdfColor.fromInt(0xFF6B6B6B);
  static const _lime = PdfColor.fromInt(0xFFD7F75B);
  static const _hairline = PdfColor.fromInt(0xFFE3E3E3);

  /// The bytes of the document.
  static Future<Uint8List> build({
    required Crib crib,
    required List<Expense> expenses,
    required List<Settlement> settlements,
    required String memberId,
    String memberName = 'You',
  }) async {
    final regular = pw.Font.ttf(await _font('assets/fonts/SpaceGrotesk-400.ttf'));
    final bold = pw.Font.ttf(await _font('assets/fonts/SpaceGrotesk-700.ttf'));

    final ledgerExpenses = expenses.toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));
    final balances = FinancialLedger.balances(
      crib: crib,
      expenses: ledgerExpenses,
      settlements: settlements,
    );

    final totalSpent = ledgerExpenses.fold<int>(
      0,
      (sum, expense) => sum + expense.totalMinor,
    );
    final yourShare = ledgerExpenses.fold<int>(
      0,
      (sum, expense) => sum + (expense.shares[memberId] ?? 0),
    );
    final yourBalance = balances[memberId] ?? 0;

    final document = pw.Document(
      title: '${crib.name} · Tabbb',
      author: 'Tabbb',
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _hairline)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Tabbb · ${crib.name} · generated ${DateFormat('d MMM yyyy').format(DateTime.now())}',
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
          _header(crib, regular, bold),
          pw.SizedBox(height: 22),
          _summary(
            crib: crib,
            totalSpent: totalSpent,
            yourShare: yourShare,
            yourBalance: yourBalance,
            memberName: memberName,
            expenseCount: ledgerExpenses.length,
            regular: regular,
            bold: bold,
          ),
          pw.SizedBox(height: 22),
          _balances(crib, balances, regular, bold),
          pw.SizedBox(height: 22),
          _expenses(ledgerExpenses, crib, memberId, memberName, regular, bold),
          if (settlements.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            _settlements(settlements, crib, regular, bold),
          ],
        ],
      ),
    );

    return document.save();
  }

  static Future<ByteData> _font(String path) => rootBundle.load(path);

  static pw.Widget _header(Crib crib, pw.Font regular, pw.Font bold) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Tabbb',
            style: pw.TextStyle(font: bold, fontSize: 11, color: _grey),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            crib.name,
            style: pw.TextStyle(font: bold, fontSize: 24, color: _ink),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${crib.members.length} members · ${crib.currency}',
            style: pw.TextStyle(font: regular, fontSize: 10, color: _grey),
          ),
        ],
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: _lime,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          'History',
          style: pw.TextStyle(font: bold, fontSize: 10, color: _ink),
        ),
      ),
    ],
  );

  static pw.Widget _summary({
    required Crib crib,
    required int totalSpent,
    required int yourShare,
    required int yourBalance,
    required String memberName,
    required int expenseCount,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final balanceLabel = yourBalance >= 0 ? 'you get back' : 'you owe';
    final balanceAmount = Money.format(yourBalance.abs(), crib.currency);
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _ink, width: 1.2),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _stat('Total spent', Money.format(totalSpent, crib.currency), regular, bold),
          _stat('Your share', Money.format(yourShare, crib.currency), regular, bold),
          _stat(balanceLabel, balanceAmount, regular, bold),
          _stat('Expenses', '$expenseCount', regular, bold),
        ],
      ),
    );
  }

  static pw.Widget _stat(
    String label,
    String value,
    pw.Font regular,
    pw.Font bold,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(font: regular, fontSize: 8, color: _grey),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        value,
        style: pw.TextStyle(font: bold, fontSize: 13, color: _ink),
      ),
    ],
  );

  static pw.Widget _balances(
    Crib crib,
    Map<String, int> balances,
    pw.Font regular,
    pw.Font bold,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Who is owed what',
        style: pw.TextStyle(font: bold, fontSize: 13, color: _ink),
      ),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: _hairline, width: 0.6),
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6F6F4)),
            children: [
              _cell('Member', regular, bold, header: true),
              _cell('Net', regular, bold, header: true, align: pw.TextAlign.right),
            ],
          ),
          for (final member in crib.members)
            pw.TableRow(
              children: [
                _cell(member.name, regular, bold),
                _cell(
                  Money.format(balances[member.id] ?? 0, crib.currency),
                  regular,
                  bold,
                  align: pw.TextAlign.right,
                ),
              ],
            ),
        ],
      ),
    ],
  );

  static pw.Widget _expenses(
    List<Expense> expenses,
    Crib crib,
    String memberId,
    String memberName,
    pw.Font regular,
    pw.Font bold,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Expenses',
        style: pw.TextStyle(font: bold, fontSize: 13, color: _ink),
      ),
      pw.SizedBox(height: 8),
      if (expenses.isEmpty)
        pw.Text(
          'No expenses yet.',
          style: pw.TextStyle(font: regular, fontSize: 10, color: _grey),
        )
      else
        pw.Table(
          border: pw.TableBorder.symmetric(
            inside: const pw.BorderSide(color: _hairline, width: 0.6),
          ),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.4),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(1.6),
            4: pw.FlexColumnWidth(1.6),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6F6F4)),
              children: [
                _cell('Date', regular, bold, header: true),
                _cell('What', regular, bold, header: true),
                _cell('Paid by', regular, bold, header: true),
                _cell('Amount', regular, bold, header: true, align: pw.TextAlign.right),
                _cell('Your share', regular, bold, header: true, align: pw.TextAlign.right),
              ],
            ),
            for (final expense in expenses)
              pw.TableRow(
                children: [
                  _cell(
                    DateFormat('d MMM').format(expense.date),
                    regular,
                    bold,
                  ),
                  _cell(expense.description, regular, bold),
                  _cell(_name(crib, expense.payerId), regular, bold),
                  _cell(
                    Money.format(expense.totalMinor, expense.currency),
                    regular,
                    bold,
                    align: pw.TextAlign.right,
                  ),
                  _cell(
                    Money.format(expense.shares[memberId] ?? 0, expense.currency),
                    regular,
                    bold,
                    align: pw.TextAlign.right,
                  ),
                ],
              ),
          ],
        ),
    ],
  );

  static pw.Widget _settlements(
    List<Settlement> settlements,
    Crib crib,
    pw.Font regular,
    pw.Font bold,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Settlements',
        style: pw.TextStyle(font: bold, fontSize: 13, color: _ink),
      ),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: _hairline, width: 0.6),
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.4),
          1: pw.FlexColumnWidth(3.5),
          2: pw.FlexColumnWidth(1.6),
          3: pw.FlexColumnWidth(1.6),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6F6F4)),
            children: [
              _cell('Date', regular, bold, header: true),
              _cell('Payment', regular, bold, header: true),
              _cell('Amount', regular, bold, header: true, align: pw.TextAlign.right),
              _cell('Status', regular, bold, header: true, align: pw.TextAlign.right),
            ],
          ),
          for (final settlement in settlements)
            pw.TableRow(
              children: [
                _cell(
                  DateFormat('d MMM yyyy').format(settlement.createdAt),
                  regular,
                  bold,
                ),
                _cell(
                  '${_name(crib, settlement.fromMemberId)} → '
                  '${_name(crib, settlement.toMemberId)}',
                  regular,
                  bold,
                ),
                _cell(
                  Money.format(settlement.amountMinor, settlement.currency),
                  regular,
                  bold,
                  align: pw.TextAlign.right,
                ),
                _cell(
                  _statusLabel(settlement.status),
                  regular,
                  bold,
                  align: pw.TextAlign.right,
                ),
              ],
            ),
        ],
      ),
    ],
  );

  static pw.Widget _cell(
    String text,
    pw.Font regular,
    pw.Font bold, {
    bool header = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        font: header ? bold : regular,
        fontSize: header ? 9 : 9.5,
        color: header ? _ink : _ink,
      ),
    ),
  );

  static String _statusLabel(SettlementStatus status) => switch (status) {
    SettlementStatus.pending => 'Requested',
    SettlementStatus.confirmed => 'Confirmed',
    SettlementStatus.selfManaged => 'Recorded',
    SettlementStatus.cancelled => 'Cancelled',
  };

  static String _name(Crib crib, String memberId) {
    final member = crib.memberById(memberId);
    return member?.name ?? 'Someone';
  }
}
