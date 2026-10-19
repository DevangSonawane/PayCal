import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/sticker_pill.dart';
import 'package:paycal/data/models.dart';

/// Equal / exact / percentage split editor. Listens to the expense amount
/// field and emits the finished shares map through [onChanged] whenever the
/// user tunes anything, so the parent form can submit whatever the editor
/// produced.
class SplitShareEditor extends StatefulWidget {
  const SplitShareEditor({
    super.key,
    required this.members,
    required this.amountController,
    required this.currency,
    required this.initialShares,
    required this.onChanged,
    this.initialMode = SplitMode.equal,
  });

  final List<Member> members;
  final TextEditingController amountController;
  final String currency;
  final Map<String, int> initialShares;
  final SplitMode initialMode;
  final void Function(Map<String, int> shares, bool complete) onChanged;

  @override
  State<SplitShareEditor> createState() => _SplitShareEditorState();
}

enum SplitMode { equal, exact, percent }

extension SplitModeLabel on SplitMode {
  String get label => switch (this) {
    SplitMode.equal => 'Equal',
    SplitMode.exact => 'Exact',
    SplitMode.percent => '%',
  };
}

class _SplitShareEditorState extends State<SplitShareEditor> {
  late SplitMode _mode = widget.initialMode;
  Map<String, TextEditingController>? _exact;
  Map<String, TextEditingController>? _percent;

  Map<String, TextEditingController> _exactControllers() => _exact ??= {
    for (final m in widget.members)
      m.id: TextEditingController(
        text: widget.initialShares[m.id] == null
            ? ''
            : Money.format(widget.initialShares[m.id]!, widget.currency),
      ),
  };

  Map<String, TextEditingController> _percentControllers() => _percent ??= {
    for (final m in widget.members)
      m.id: TextEditingController(
        text: widget.initialShares[m.id] == null
            ? ''
            : _percentOf(widget.initialShares[m.id]!),
      ),
  };

  String _percentOf(int minor) {
    final total = _total;
    if (total <= 0) return '0';
    return (minor / total * 100).toStringAsFixed(1);
  }

  int get _total => Money.tryParseToMinor(widget.amountController.text) ?? 0;

  /// Computes the current shares for the active mode and whether they add up
  /// cleanly (no remainder in exact mode, percentages sum to ~100 in % mode).
  (Map<String, int>, bool) _compute() {
    final total = _total;
    if (total <= 0) return const ({}, false);
    switch (_mode) {
      case SplitMode.equal:
        final n = widget.members.length;
        final per = total ~/ n;
        var remainder = total - per * n;
        return (
          {
            for (final m in widget.members)
              m.id: per + ((remainder-- > 0) ? 1 : 0),
          },
          true,
        );
      case SplitMode.exact:
        final shares = <String, int>{};
        var sum = 0;
        var complete = true;
        for (final m in widget.members) {
          final v = Money.tryParseToMinor(_exactControllers()[m.id]!.text);
          if (v == null || v < 0) {
            complete = false;
            continue;
          }
          shares[m.id] = v;
          sum += v;
        }
        return (shares, complete && sum == total);
      case SplitMode.percent:
        final shares = <String, int>{};
        var pctSum = 0.0;
        for (final m in widget.members) {
          final raw = _percentControllers()[m.id]!.text.replaceAll('%', '');
          final p = double.tryParse(raw) ?? -1;
          if (p < 0) return const ({}, false);
          pctSum += p;
          shares[m.id] = (total * p / 100).round();
        }
        return (shares, (pctSum - 100).abs() < 0.5);
    }
  }

  void _emit() {
    final (shares, ok) = _compute();
    widget.onChanged(shares, ok);
  }

  @override
  void initState() {
    super.initState();
    widget.amountController.addListener(_emit);
    _emit();
  }

  @override
  void dispose() {
    widget.amountController.removeListener(_emit);
    for (final c in _exact?.values ?? const <TextEditingController>[]) {
      c.dispose();
    }
    for (final c in _percent?.values ?? const <TextEditingController>[]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final mode in SplitMode.values)
            StickerPill(
              label: mode.label,
              selected: _mode == mode,
              showCheck: true,
              onTap: () => setState(() {
                _mode = mode;
                _emit();
              }),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      if (_mode == SplitMode.equal)
        Text(
          'Split equally between ${widget.members.length} people.',
          style: AppTypography.caption.copyWith(color: AppPalette.current.grey),
        )
      else
        for (final m in widget.members)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: m.name,
                    controller: _mode == SplitMode.exact
                        ? _exactControllers()[m.id]
                        : _percentControllers()[m.id],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    suffix: _mode == SplitMode.exact
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xs,
                            ),
                            child: Text(
                              '%',
                              style: AppTypography.label.copyWith(
                                color: AppPalette.current.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                    onChanged: (_) => _emit(),
                  ),
                ),
              ],
            ),
          ),
      if (_mode != SplitMode.equal) ...[
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                _total == 0
                    ? 'Enter an amount to tune the split'
                    : _compute().$2
                    ? '${Money.format(_total, widget.currency)} fully accounted for'
                    : 'Tune so everyone adds up to the total',
                style: AppTypography.caption.copyWith(
                  color: _compute().$2 ? AppPalette.current.teal : AppPalette.current.grey,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}
