import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';

class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.amount,
    this.currency = 'INR',
    this.style,
    this.direction,
  });

  final int amount;
  final String currency;
  final TextStyle? style;
  final MoneyDirection? direction;

  @override
  Widget build(BuildContext context) {
    final base = style ?? AppTypography.amount;
    Color color = AppPalette.current.text;
    if (direction == MoneyDirection.owed) color = AppPalette.current.owedText;
    if (direction == MoneyDirection.owe) color = AppPalette.current.oweText;
    return Text(
      Money.format(amount, currency),
      style: base.copyWith(color: color),
    );
  }
}
