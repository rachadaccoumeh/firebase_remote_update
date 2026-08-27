/// A reusable force/optional update gate backed by Firebase Remote Config.
///
/// Public API surface. Consumers only need this single import.
///
/// Built on `app_update_gate`; the core types (decisions, versions, store
/// checkers, controller, policy sources) are re-exported here. This package
/// adds the Firebase Remote Config policy source and keeps the pre-0.3
/// service/gate API.
library;

export 'package:app_update_gate/app_update_gate.dart'
    hide AppUpdateConfig, AppUpdateService, UpdateGate;

export 'src/app_update_config.dart';
export 'src/app_update_service.dart';
export 'src/firebase_remote_config_policy_source.dart';
export 'src/update_gate.dart';
