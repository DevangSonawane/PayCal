import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';

/// Tinted category glyph used as list leading. Colors stay stable per category.
class ExpenseIcon extends StatelessWidget {
  const ExpenseIcon({super.key, required this.category, this.size = 40});

  final String category;
  final double size;

  static IconData iconFor(String category) {
    switch (category.toLowerCase()) {
      case 'rent':
      case 'home':
        return Icons.home_outlined;
      case 'groceries':
        return Icons.shopping_basket_outlined;
      case 'food':
      case 'dining':
        return Icons.restaurant_outlined;
      case 'electricity':
      case 'utilities':
        return Icons.bolt_outlined;
      case 'internet':
        return Icons.wifi_outlined;
      case 'cleaning':
      case 'supplies':
        return Icons.cleaning_services_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      case 'travel':
        return Icons.flight_outlined;
      case 'stay':
        return Icons.hotel_outlined;
      case 'subscriptions':
        return Icons.repeat_outlined;
      case 'activities':
      case 'events':
        return Icons.local_activity_outlined;
      case 'gifts':
        return Icons.card_giftcard_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'health':
        return Icons.local_hospital_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.tintBgFor(category),
        borderRadius: BorderRadius.circular(AppRadii.avatar),
      ),
      child: Icon(
        iconFor(category),
        color: AppColors.tintFgFor(category),
        size: size * 0.5,
      ),
    );
  }
}
