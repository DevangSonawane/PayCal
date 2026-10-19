import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';

/// Themed pop-up dialog: scales in with a springy "pop" instead of sliding
/// from the bottom like a sheet.
Future<T?> showPopCard<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  Widget? footer,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: AppPalette.current.scrim,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        PopCard(title: title, footer: footer, child: builder(dialogContext)),
    transitionBuilder: popTransitionBuilder,
  );
}

Widget popTransitionBuilder(
  BuildContext dialogContext,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
  return FadeTransition(
    opacity: CurvedAnimation(
      parent: animation,
      curve: const Interval(0, .6, curve: Curves.easeOut),
    ),
    child: ScaleTransition(
      scale: Tween<double>(begin: .78, end: 1).animate(curved),
      child: child,
    ),
  );
}

class PopCard extends StatelessWidget {
  const PopCard({
    super.key,
    required this.title,
    required this.child,
    this.footer,
  });
  final String title;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      // Sized against the keyboard so fields stay reachable while typing.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .82,
          ),
          decoration: BoxDecoration(
            color: AppPalette.current.page,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppPalette.current.ink, width: 2),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppPalette.current.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.title.copyWith(
                        color: AppPalette.current.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppPalette.current.ink, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppPalette.current.ink,
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Flexible(child: SingleChildScrollView(child: child)),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: footer!,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
