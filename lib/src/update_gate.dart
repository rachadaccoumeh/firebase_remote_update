import 'package:app_update_gate/app_update_gate.dart' as core;
import 'package:app_update_gate/app_update_gate.dart'
    show UpdateDecision, UpdateGateMode;
import 'package:flutter/material.dart';

import 'app_update_service.dart';

/// Wraps the app and blocks it with [forcedBuilder] when a forced update is
/// required. The policy check runs exactly once per mount.
///
/// A thin wrapper over the `app_update_gate` core gate: it owns an internal
/// single-check controller so the pre-0.3 service-based API keeps working.
/// For background re-checks, observable status, or navigation-deferred
/// presentation, use the core `AppUpdateController` + `UpdateGate` directly.
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

/// Adapts this package's [AppUpdateService] to the core service interface so
/// the core controller/gate can drive it.
class _CoreServiceBridge implements core.AppUpdateService {
  _CoreServiceBridge(this._service);

  final AppUpdateService _service;

  @override
  core.AppUpdateConfig get config => core.AppUpdateConfig(
    androidPackageId: _service.config.androidPackageId,
    iosAppStoreId: _service.config.iosAppStoreId,
    storeCountry: _service.config.storeCountry,
    fetchTimeout: _service.config.fetchTimeout,
  );

  @override
  Future<UpdateDecision> evaluate() => _service.evaluate();

  @override
  Future<void> startUpdate() => _service.startUpdate();
}

class _UpdateGateState extends State<UpdateGate> {
  late core.AppUpdateController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController();
  }

  @override
  void didUpdateWidget(UpdateGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _controller.dispose();
      _controller = _createController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  core.AppUpdateController _createController() {
    // One check per mount, no background re-checks: pre-0.3 behavior.
    return core.AppUpdateController(service: _CoreServiceBridge(widget.service));
  }

  @override
  Widget build(BuildContext context) {
    return core.UpdateGate(
      controller: _controller,
      mode: widget.mode,
      forcedBuilder: widget.forcedBuilder,
      loadingBuilder: widget.loadingBuilder,
      onDecision: widget.onDecision,
      child: widget.child,
    );
  }
}
