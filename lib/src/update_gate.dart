import 'package:flutter/material.dart';

import 'app_update_service.dart';
import 'update_decision.dart';

/// Controls how [UpdateGate] behaves while the update policy is being
/// evaluated.
enum UpdateGateMode {
  /// The app renders immediately and the policy is evaluated in the
  /// background. If the result is [UpdateRequirement.forced], the gate swaps
  /// to [UpdateGate.forcedBuilder] once evaluation completes.
  ///
  /// Use this when you want the user to see the app as fast as possible.
  nonBlocking,

  /// The app is hidden behind [UpdateGate.loadingBuilder] until evaluation
  /// completes, then either [UpdateGate.child] or [UpdateGate.forcedBuilder]
  /// is shown.
  ///
  /// Use this when you need the decision before any UI is visible (e.g. to
  /// avoid a flash of the main screen before a forced update).
  blocking,
}

/// Wraps the app and blocks it with [forcedBuilder] when a forced update is
/// required. The policy check runs exactly once per mount.
///
/// In [UpdateGateMode.nonBlocking] mode (the default) the app renders
/// immediately and the policy is evaluated in the background. If the result is
/// forced, the gate swaps to [forcedBuilder] after evaluation completes.
///
/// In [UpdateGateMode.blocking] mode the app is hidden behind [loadingBuilder]
/// until the decision is resolved.
///
/// Optional updates never block: they are surfaced via [onDecision] so the
/// host app can show its own soft prompt if desired.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.service,
    required this.child,
    required this.forcedBuilder,
    this.mode = UpdateGateMode.nonBlocking,
    this.loadingBuilder,
    this.onDecision,
  });

  final AppUpdateService service;

  /// The app to show when no forced update is required.
  final Widget child;

  /// Blocking screen shown when a forced update is required.
  final Widget Function(BuildContext context, UpdateDecision decision)
  forcedBuilder;

  /// How the gate behaves while the policy is being evaluated.
  ///
  /// Defaults to [UpdateGateMode.nonBlocking].
  final UpdateGateMode mode;

  /// Shown while the policy is being evaluated in [UpdateGateMode.blocking]
  /// mode. Ignored in [UpdateGateMode.nonBlocking] mode.
  ///
  /// Defaults to a centered spinner.
  final WidgetBuilder? loadingBuilder;

  /// Called once with the resolved decision (useful for optional prompts,
  /// analytics, etc.).
  final void Function(UpdateDecision decision)? onDecision;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  UpdateDecision? _decision;
  bool _evaluating = true;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  Future<void> _evaluate() async {
    final decision = await widget.service.evaluate();
    if (!mounted) return;
    widget.onDecision?.call(decision);
    setState(() {
      _decision = decision;
      _evaluating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;

    switch (widget.mode) {
      case UpdateGateMode.nonBlocking:
        // Show the app immediately. Only swap to forcedBuilder once we know
        // for certain that a forced update is required.
        if (decision != null && decision.isForced) {
          return widget.forcedBuilder(context, decision);
        }
        return widget.child;

      case UpdateGateMode.blocking:
        // Hide the app behind loadingBuilder until the decision is resolved.
        if (_evaluating) {
          return widget.loadingBuilder?.call(context) ?? const _Loading();
        }
        if (decision != null && decision.isForced) {
          return widget.forcedBuilder(context, decision);
        }
        return widget.child;
    }
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
