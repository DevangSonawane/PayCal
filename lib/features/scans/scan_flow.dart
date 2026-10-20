import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/option_tile.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/features/expenses/quick_add_sheet.dart';

/// Scan flow: reads another member's PayCal QR code with the camera, then
/// offers to pay an expense or split it with them.
Future<void> showScanFlow(BuildContext context) {
  return showPopCard<void>(
    context: context,
    title: 'Scan',
    builder: (dialogContext) => _ScanFlowBody(),
  );
}

class _ScanFlowBody extends StatefulWidget {
  const _ScanFlowBody();

  @override
  State<_ScanFlowBody> createState() => _ScanFlowBodyState();
}

class _ScanFlowBodyState extends State<_ScanFlowBody> {
  MobileScannerController? _camera;
  Member? _peer;
  DateTime _lastHint = DateTime(0);
  var _startAttempts = 0;
  var manualEntry = false;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  /// Explicit single start instead of autoStart: the camera is exclusive on
  /// Android, and a double-start race inside a dialog transition renders the
  /// preview as a black card. Starting exactly once outside the widget tree
  /// keeps the TextureLayer out of opacity/transform wrappers.
  void _startCamera() {
    final previous = _camera;
    _camera = null;
    if (previous != null) {
      unawaited(previous.stop().then((_) => previous.dispose()));
    }
    final controller = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      autoStart: false,
    );
    _camera = controller;
    unawaited(
      controller.start().then<void>((_) => _startAttempts = 0).catchError((
        Object _,
      ) {
        // Let the error card in the viewfinder take over eventually so a
        // broken camera never leaves a black card behind.
        if (mounted && ++_startAttempts <= 2) {
          setState(_startCamera);
        }
      }),
    );
  }

  @override
  void dispose() {
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      unawaited(camera.stop().then((_) => camera.dispose()));
    }
    super.dispose();
  }

  /// The signed-in member.
  String get _meId => PayCalRepositories.instance.currentUserId;

  Member? _memberFromPayload(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'paycal' || uri.host != 'user') {
      return null;
    }
    final id = uri.path.replaceAll('/', '');
    for (final crib in PayCalRepositories.instance.cribs.cachedCribs) {
      final member = crib.memberById(id);
      if (member != null) return member;
    }
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      if (raw.startsWith('paycal://user/') &&
          raw.replaceAll('paycal://user/', '') == _meId) {
        _hint('That is your own code, cheeky!');
        continue;
      }
      final member = _memberFromPayload(raw);
      if (member == null) {
        _hint('Not a PayCal code - keep scanning');
        continue;
      }
      _camera?.stop();
      HapticFeedback.mediumImpact();
      setState(() => _peer = member);
      return;
    }
  }

  void _hint(String message) {
    final now = DateTime.now();
    if (now.difference(_lastHint) < Duration(seconds: 2)) return;
    _lastHint = now;
    showAppToast(context, message);
  }

  List<Crib> get _cribs =>
      PayCalRepositories.instance.cribs.cachedCribs;

  List<Crib> _sharedCribs(Member member) => [
    for (final b in _cribs)
      if (b.members.any((m) => m.id == _meId) &&
          b.members.any((m) => m.id == member.id))
        b,
  ];

  /// Landing plan for the found card caption.
  String _landingLine() {
    final shared = _sharedCribs(_peer!);
    return switch (shared.length) {
      1 => 'Lands in ${shared.first.name}',
      0 => 'Pick a crib to add them to',
      _ => 'Pick where it lands (${shared.length} shared)',
    };
  }

  /// Guarantees a landing crib: picks the only shared crib, asks which one
  /// when several are shared, or offers to add the person to a crib first
  /// when none is shared.
  Future<Crib?> _pickLandingCrib(Member member) async {
    final shared = _sharedCribs(member);
    if (shared.length == 1) return shared.first;
    final banner = shared.isEmpty ? 'first' : 'pick';
    final picked = await showPopCard<Crib>(
      context: context,
      title: 'Which crib?',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shared.isEmpty
                ? '${member.name} is not in any of your cribs. Add them to one to record this.'
                : 'You share more than one crib with ${member.name}. Where should this land?',
            style: AppTypography.caption.copyWith(
              color: AppPalette.current.grey,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          for (final b in _cribs)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: OptionTile(
                title: shared.any((s) => s.id == b.id)
                    ? b.name
                    : '${b.name} (adds ${member.name})',
                support: shared.any((s) => s.id == b.id)
                    ? 'You both are members'
                    : 'Only the crib owner can add them',
                selected: banner == 'first' && b == _cribs.first,
                onTap: () => Navigator.of(context).pop(b),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return null;
    final alreadyMember = picked.members.any(
      (m) => m.id == member.id && m.isActive,
    );
    if (!alreadyMember) {
      // Membership only ever changes through the crib repository.
      try {
        await PayCalRepositories.instance.cribs.addMember(
          cribId: picked.id,
          member: member,
        );
      } on RepositoryException catch (error) {
        if (mounted) showAppToast(context, error.message);
        return null;
      }
    }
    return picked;
  }

  Future<void> _choose(BuildContext dialogContext, bool split) async {
    final member = _peer!;
    final landing = await _pickLandingCrib(member);
    if (landing == null) return;
    if (!dialogContext.mounted || !mounted) return;
    Navigator.of(dialogContext).pop();
    showAppToast(
      context,
      split
          ? 'Splitting with ${member.name} in ${landing.name}'
          : 'Expense for ${member.name} in ${landing.name}',
    );
    showQuickAdd(
      context,
      cribId: landing.id,
      payeeId: split ? null : member.id,
      splitWithIds: split ? [_meId, member.id] : null,
      onSaved: () {},
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // No fade transitions over the live camera: on Android a TextureLayer
      // inside opacity/transform wrappers can composite as a black card.
      _peer != null
          ? _buildFound(context)
          : (manualEntry ? _buildManualEntry() : _buildScanning()),
      if (_peer == null) ...[
        SizedBox(height: AppSpacing.md),
        Text(
          manualEntry
              ? 'Paste a paycal:// code to find your friend.'
              : 'Point your camera at their PayCal code.',
          style: AppTypography.caption.copyWith(color: AppPalette.current.grey),
        ),
        if (!manualEntry)
          Center(
            child: GestureDetector(
              onTap: () => setState(() {
                manualEntry = true;
                _camera?.stop();
              }),
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.current.card,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppPalette.current.ink, width: 1.5),
                ),
                child: Text(
                  'Type a code instead',
                  style: AppTypography.caption.copyWith(
                    color: AppPalette.current.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    ],
  );

  Widget _buildManualEntry() {
    final codeController = TextEditingController();
    return Column(
      key: ValueKey('manual'),
      children: [
        AppTextField(
          label: 'PayCal code',
          hint: 'paycal://user/friend-id',
          controller: codeController,
          keyboardType: TextInputType.url,
        ),
        SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: 'Find them',
          onPressed: () {
            final member = _memberFromPayload(codeController.text.trim());
            if (member == null) {
              showAppToast(context, 'That code matched nobody');
              return;
            }
            if (member.id == _meId) {
              showAppToast(context, 'That is your own code, cheeky!');
              return;
            }
            HapticFeedback.mediumImpact();
            setState(() => _peer = member);
          },
        ),
        SizedBox(height: AppSpacing.sm),
        Center(
          child: GestureDetector(
            onTap: () => setState(() {
              manualEntry = false;
              _startCamera();
            }),
            child: Text(
              'Scan with camera instead',
              style: AppTypography.caption.copyWith(
                color: AppPalette.current.ink,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Live viewfinder with a scanning beam sweeping over the camera feed.
  Widget _buildScanning() => Center(
    key: ValueKey('scanning'),
    child: Container(
      width: 220,
      height: 220,
      margin: EdgeInsets.only(top: AppSpacing.xs),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppPalette.current.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppPalette.current.ink, width: 1.5),
      ),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            fit: BoxFit.cover,
            errorBuilder: (context, error) => _CameraError(
              detail: error.errorCode.name,
              onRetry: () => setState(_startCamera),
            ),
          ),
          // Animated scan beam sweeping vertically.
          Positioned(
            left: 10,
            right: 10,
            child:
                Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: AppPalette.current.ink,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .moveY(
                      begin: -95,
                      end: 95,
                      duration: 1200.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
          Positioned(
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppPalette.current.card,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppPalette.current.ink, width: 1.5),
              ),
              child: Text(
                'Searching',
                style: AppTypography.caption.copyWith(
                  color: AppPalette.current.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildFound(BuildContext dialogContext) => Column(
    key: ValueKey('found'),
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppPalette.current.lime,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppPalette.current.ink, width: 1.5),
        ),
        child: Row(
          children: [
            Avatar(initials: _peer!.initials, size: 44),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _peer!.name,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppPalette.current.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _landingLine(),
                    style: AppTypography.caption.copyWith(
                      color: AppPalette.current.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: AppSpacing.lg),
      _ScanOption(
        icon: Icons.payments_outlined,
        title: 'Pay an expense',
        subtitle: 'Something you paid for them',
        onTap: () => _choose(dialogContext, false),
      ),
      SizedBox(height: AppSpacing.sm),
      _ScanOption(
        icon: Icons.call_split_outlined,
        title: 'Split it with them',
        subtitle: 'Share a bill between the two of you',
        onTap: () => _choose(dialogContext, true),
      ),
    ],
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.detail, required this.onRetry});
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    color: AppPalette.current.card,
    padding: EdgeInsets.all(AppSpacing.lg),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.videocam_off_outlined, color: AppPalette.current.grey),
        SizedBox(height: AppSpacing.sm),
        Text(
          detail == 'permissionDenied'
              ? 'Camera permission needed to scan.'
              : 'Camera is not available right now.',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: AppPalette.current.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppPalette.current.lime,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppPalette.current.ink, width: 1.5),
            ),
            child: Text(
              'Try again',
              style: AppTypography.caption.copyWith(
                color: AppPalette.current.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScanOption extends StatelessWidget {
  const _ScanOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppPalette.current.card,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppPalette.current.ink, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 32,
              decoration: BoxDecoration(
                color: AppPalette.current.ink,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppPalette.current.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppPalette.current.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppPalette.current.ink),
          ],
        ),
      ),
    ),
  );
}
