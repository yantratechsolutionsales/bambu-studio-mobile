import 'package:go_router/go_router.dart';
import 'ui/core/app_shell.dart';
import 'ui/features/calibration/view_models/calibration_view_model.dart';
import 'ui/features/calibration/views/calibration_view.dart';
import 'ui/features/device/view_models/device_view_model.dart';
import 'ui/features/device/views/device_view.dart';
import 'ui/features/home/views/home_view.dart';
import 'ui/features/multi_device/views/multi_device_view.dart';
import 'ui/features/prepare/view_models/studio_workspace_view_model.dart';
import 'ui/features/prepare/views/prepare_view.dart';
import 'ui/features/preview/views/preview_view.dart';
import 'ui/features/project/views/project_view.dart';

GoRouter createBambuRouter({
  required StudioWorkspaceViewModel workspaceVm,
  required DeviceViewModel deviceVm,
  required CalibrationViewModel calibVm,
}) {
  return GoRouter(
    initialLocation: '/prepare',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return BambuAppShell(
            navigationShell: navigationShell,
            workspaceVm: workspaceVm,
            deviceVm: deviceVm,
          );
        },
        branches: [
          // 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => HomeView(
                  workspaceVm: workspaceVm,
                  onNavigateToPrepare: () => context.go('/prepare'),
                ),
              ),
            ],
          ),
          // 1: Prepare
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/prepare',
                builder: (context, state) => PrepareView(
                  workspaceVm: workspaceVm,
                  deviceVm: deviceVm,
                  onNavigateToPreview: () => context.go('/preview'),
                ),
              ),
            ],
          ),
          // 2: Preview
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/preview',
                builder: (context, state) => PreviewView(
                  workspaceVm: workspaceVm,
                  deviceVm: deviceVm,
                  onNavigateToDevice: () => context.go('/device'),
                ),
              ),
            ],
          ),
          // 3: Device
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/device',
                builder: (context, state) => DeviceView(deviceVm: deviceVm),
              ),
            ],
          ),
          // 4: Multi-Device Fleet
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/multi-device',
                builder: (context, state) => MultiDeviceView(
                  deviceVm: deviceVm,
                  onInspectDevice: () => context.go('/device'),
                ),
              ),
            ],
          ),
          // 5: Project
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/project',
                builder: (context, state) => ProjectView(workspaceVm: workspaceVm),
              ),
            ],
          ),
          // 6: Calibration
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calibration',
                builder: (context, state) => CalibrationView(
                  calibVm: calibVm,
                  workspaceVm: workspaceVm,
                  onLoadModelToPrepare: () => context.go('/prepare'),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
