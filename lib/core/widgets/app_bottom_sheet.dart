import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext sheetContext) builder,
  Widget? footer,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: AppPalette.current.scrim,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _DraggableSheet(title: title, footer: footer, builder: builder),
    ),
  );
}

/// Sheet with a grab-zone header: drag the title area down to fling it away,
/// release early and it springs back with a rubber-band wobble.
class _DraggableSheet extends StatefulWidget {
  const _DraggableSheet({
    required this.title,
    required this.footer,
    required this.builder,
  });

  final String title;
  final Widget? footer;
  final Widget Function(BuildContext sheetContext) builder;

  @override
  State<_DraggableSheet> createState() => _DraggableSheetState();
}

class _DraggableSheetState extends State<_DraggableSheet> {
  double _offset = 0;
  bool _dragging = false;

  void _onUpdate(DragUpdateDetails d) {
    setState(() {
      _dragging = true;
      _offset = (_offset + d.delta.dy).clamp(0.0, double.infinity);
    });
  }

  void _onEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    if (_offset > 110 || velocity > 800) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _dragging = false;
      _offset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _offset),
      duration: _dragging
          ? Duration(milliseconds: 50)
          : Duration(milliseconds: 360),
      curve: _dragging ? Curves.linear : Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.translate(offset: Offset(0, value), child: child),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppPalette.current.page,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        // showModalBottomSheet's SafeArea only pads the top/left/right — the
        // sheet always runs to the screen edge, so keep the white background
        // down there but lift the content above the Android nav bar.
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: _onUpdate,
              onVerticalDragEnd: _onEnd,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(top: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppPalette.current.ink,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.xl,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: AppTypography.titleLg.copyWith(
                              color: AppPalette.current.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.drag_indicator_rounded,
                          color: AppPalette.current.grey,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppPalette.current.hairline),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: widget.builder(context),
              ),
            ),
            if (widget.footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: widget.footer,
              ),
          ],
        ),
      ),
    );
  }
}
