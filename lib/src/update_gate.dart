import 'dart:async';

import 'package:app_update_gate/app_update_gate.dart' as core;
import 'package:app_update_gate/app_update_gate.dart'
    show UpdateDecision, UpdateGateMode;
import 'package:flutter/material.dart';

import 'app_update_service.dart';

/// Wraps the app and blocks it with [forcedBuilder] when a forced update is
/// required. The policy is checked once per mount, plus these optional
/// triggers:
/// - [recheckInterval]: periodic re-check while the app stays open;
/// - [resumeRecheckAfter]: re-check when the app returns to the foreground and
///   the last check is older than this;
/// - [listenForRealtimeUpdates]: re-check as soon as a Remote Config change
///   is published (Firebase real-time Remote Config).
///
/// A thin wrapper over the `app_update_gate` core gate: it owns an internal
/// controller so the service-based API keeps working. For observable status
/// or navigation-deferred presentation, use the core `AppUpdateController` +
/// `UpdateGate` directly.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.service,
    required this.child,
    required this.forcedBuilder,
    this.mode = UpdateGateMode.nonBlocking,
    this.loadingBuilder,
    this.onDecision,
    this.recheckInterval,
    this.resumeRecheckAfter,
    this.listenForRealtimeUpdates = false,
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

  /// Re-checks the policy on this interval while the gate is mounted.
  /// `null` (default) = no periodic re-check.
  final Duration? recheckInterval;

  /// When the app returns to the foreground, re-checks if the last check is
  /// older than this. `null` (default) = no re-check on resume.
  ///
  /// Remote Config still caches values for
  /// [AppUpdateConfig.minimumFetchInterval], so keep both values aligned.
  final Duration? resumeRecheckAfter;

  /// Re-checks at once when a Remote Config change is published, through
  /// Firebase real-time Remote Config (no console setup needed). Defaults to
  /// `false`.
  final bool listenForRealtimeUpdates;

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
  StreamSubscription<void>? _configUpdates;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(UpdateGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.recheckInterval != widget.recheckInterval ||
        oldWidget.listenForRealtimeUpdates != widget.listenForRealtimeUpdates) {
      _stop();
      _start();
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _start() {
    _controller = core.AppUpdateController(
      service: _CoreServiceBridge(widget.service),
      recheckInterval: widget.recheckInterval,
    );
    if (widget.listenForRealtimeUpdates) {
      _configUpdates = widget.service.configUpdates().listen(
        (_) => unawaited(_controller.checkForUpdate()),
      );
    }
  }

  void _stop() {
    _configUpdates?.cancel();
    _configUpdates = null;
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return core.UpdateGate(
      controller: _controller,
      mode: widget.mode,
      forcedBuilder: widget.forcedBuilder,
      loadingBuilder: widget.loadingBuilder,
      onDecision: widget.onDecision,
      resumeRecheckAfter: widget.resumeRecheckAfter,
      child: widget.child,
    );
  }
}
