import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/strings.dart';
import 'app_design.dart';

/// One bubble of the first-run tour, anchored to a widget on screen.
class CoachStep {
  final GlobalKey target;
  final String title;
  final String body;
  const CoachStep(
      {required this.target, required this.title, required this.body});
}

/// A short, skippable tour: the screen dims, the current target is
/// highlighted and a bubble explains it. Steps whose target is not on screen
/// are skipped, so layout differences never leave the user stuck.
class CoachMarks {
  CoachMarks._();

  static OverlayEntry? _entry;

  static void show(BuildContext context, List<CoachStep> steps,
      {VoidCallback? onFinished}) {
    dismiss();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || steps.isEmpty) {
      onFinished?.call();
      return;
    }
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CoachOverlay(
        steps: steps,
        onClose: () {
          if (_entry == entry) _entry = null;
          entry.remove();
          onFinished?.call();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

class _CoachOverlay extends StatefulWidget {
  final List<CoachStep> steps;
  final VoidCallback onClose;
  const _CoachOverlay({required this.steps, required this.onClose});

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final Ticker _ticker;
  Rect? _lastRect;

  @override
  void initState() {
    super.initState();
    // Targets can still be moving when the tour starts (keyboard closing,
    // button animating in), so keep following them instead of measuring once.
    _ticker = createTicker((_) {
      final rect = _targetRect(widget.steps[_index]);
      if (rect != _lastRect && mounted) setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Rect? _targetRect(CoachStep step) {
    final box = step.target.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      widget.onClose();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final rect = _targetRect(step);
    _lastRect = rect;
    if (rect == null) {
      // Hidden target (e.g. a collapsed layout): move on without a flash.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _next();
      });
      return const SizedBox.shrink();
    }
    final size = MediaQuery.sizeOf(context);
    final hole = rect.inflate(8);
    final width = (size.width - 32).clamp(0.0, 340.0);
    final left =
        (hole.center.dx - width / 2).clamp(16.0, size.width - width - 16);
    final below = hole.center.dy < size.height / 2;
    final last = _index == widget.steps.length - 1;
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: CustomPaint(painter: _ScrimPainter(hole)),
            ),
          ),
          Positioned(
            left: left,
            width: width,
            top: below ? hole.bottom + 12 : null,
            bottom: below ? null : size.height - hole.top + 12,
            child: Semantics(
              liveRegion: true,
              child: Card(
                key: const Key('coachBubble'),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.group),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpace.control),
                      Text(step.body),
                      const SizedBox(height: AppSpace.group),
                      Text(
                        context.l10n.tourStep(_index + 1, widget.steps.length),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpace.control),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpace.control,
                        children: [
                          if (!last)
                            TextButton(
                              key: const Key('coachSkip'),
                              onPressed: widget.onClose,
                              child: Text(context.l10n.tourSkip),
                            ),
                          FilledButton(
                            key: const Key('coachNext'),
                            onPressed: _next,
                            child: Text(last
                                ? context.l10n.tourDone
                                : context.l10n.tourNext),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  final Rect hole;
  _ScrimPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(16)));
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}
