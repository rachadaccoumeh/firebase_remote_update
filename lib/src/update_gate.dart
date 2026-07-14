import 'package:flutter/material.dart';

import 'app_update_service.dart';
import 'update_decision.dart';

/// Wraps the app and blocks it with [forcedBuilder] when a forced update is
/// required. The policy check runs exactly once per mount (not on every
/// rebuild), and while it is in flight [loadingBuilder] is shown.
///
/// Optional updates do not block: they are surfaced via [onDecision] so the
/// host app can show its own soft prompt if desired.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.service,
    required this.child,
    required this.forcedBuilder,
    this.loadingBuilder,
    this.onDecision,
  });

  final AppUpdateService service;

  /// The app to show when no forced update is required.
  final Widget child;

  /// Blocking screen shown when a forced update is required.
  final Widget Function(BuildContext context, UpdateDecision decision)
      forcedBuilder;

  /// Shown while the policy is being evaluated. Defaults to a centered spinner.
  final WidgetBuilder? loadingBuilder;

  /// Called once with the resolved decision (useful for optional prompts,
  /// analytics, etc.).
  final void Function(UpdateDecision decision)? onDecision;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  late final Future<UpdateDecision> _decision = _evaluate();

  Future<UpdateDecision> _evaluate() async {
    final decision = await widget.service.evaluate();
    widget.onDecision?.call(decision);
    return decision;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UpdateDecision>(
      future: _decision,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loadingBuilder?.call(context) ?? const _Loading();
        }
        final decision = snapshot.data ?? const UpdateDecision.none();
        if (decision.isForced) {
          return widget.forcedBuilder(context, decision);
        }
        return widget.child;
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
