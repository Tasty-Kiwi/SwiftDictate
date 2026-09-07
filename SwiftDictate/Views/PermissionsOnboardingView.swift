import SwiftUI

struct PermissionsOnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var requestingPermission: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "microphone.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Welcome to SwiftDictate")
                .font(.title)

            Text("SwiftDictate needs a few permissions to work. Everything runs locally on your device — your data never leaves your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Permission.allCases, id: \.self) { permission in
                    permissionRow(
                        permission: permission,
                        granted: appState.permissionsService.isGranted(permission)
                    )
                }
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            Button(action: requestPermissions) {
                if requestingPermission {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Grant Required Permissions")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(requestingPermission)
        }
        .padding(40)
        .frame(width: 440)
    }

    private func permissionRow(permission: Permission, granted: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(permission.displayName)
                    .font(.headline)
                Text(permission.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func requestPermissions() {
        requestingPermission = true
        Task {
            await appState.requestRequiredPermissions()
            requestingPermission = false
        }
    }
}
