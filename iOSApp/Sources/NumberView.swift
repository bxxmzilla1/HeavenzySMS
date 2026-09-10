import SwiftUI

/// Main screen: request a phone number from the configured provider and watch for
/// the incoming SMS code.
struct NumberView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var vm: SMSViewModel
    @State private var copied: String? = nil

    init() {
        // Placeholder; replaced in onAppear via the environment settings.
        _vm = StateObject(wrappedValue: SMSViewModel(settings: AppSettings()))
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    LogoHeader(provider: settings.provider)

                    serviceCard
                    actionButtons
                    if vm.hasOrder { resultCard }
                    if let err = vm.errorMessage { errorCard(err) }
                    statusFooter
                }
                .padding(20)
            }
        }
        .onAppear { vm.attach(settings) }
    }

    private var serviceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Service", systemImage: "app.badge")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                TextField(providerHint, text: $vm.service)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.25)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardStroke, lineWidth: 1))
                Text(providerNote)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                vm.requestNumber()
            } label: {
                HStack {
                    if vm.isBusy { ProgressView().tint(.white) }
                    Text(vm.isBusy ? "Ordering…" : (vm.hasOrder ? "Get Another Number" : "Get Number"))
                }
            }
            .buttonStyle(PrimaryButtonStyle(enabled: !vm.isBusy))
            .disabled(vm.isBusy)

            if vm.hasOrder {
                Button(role: .destructive) {
                    vm.release()
                } label: {
                    Label("Release number", systemImage: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .foregroundColor(Color.red.opacity(0.9))
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.25), lineWidth: 1))
            }
        }
    }

    private var resultCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                valueRow(title: "Phone number", value: vm.phone.isEmpty ? "—" : formattedPhone(vm.phone), copyKey: "phone", rawValue: vm.phone, systemImage: "phone.fill")
                Divider().overlay(Theme.cardStroke)
                if vm.phase == .received {
                    valueRow(title: "SMS code", value: vm.code, copyKey: "code", rawValue: vm.code, systemImage: "checkmark.seal.fill", highlight: true)
                } else {
                    HStack(spacing: 12) {
                        ProgressView().tint(Theme.purpleBright)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Waiting for SMS code")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text("Auto-checking every 5s")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Button { vm.pollNow() } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.purpleBright)
                                .padding(10)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                        }
                    }
                }
                HStack(spacing: 6) {
                    Text("Provider").foregroundColor(Theme.textSecondary)
                    Text(vm.activeProvider.label).foregroundColor(Theme.purpleBright)
                    if !vm.service.isEmpty {
                        Text("· \(vm.service)").foregroundColor(Theme.textSecondary)
                    }
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        }
    }

    private func valueRow(title: String, value: String, copyKey: String, rawValue: String, systemImage: String, highlight: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(highlight ? Theme.purpleBright : Theme.textSecondary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                Text(value)
                    .font(.system(size: highlight ? 30 : 22, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .textSelection(.enabled)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = rawValue
                copied = copyKey
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    if copied == copyKey { copied = nil }
                }
            } label: {
                Image(systemName: copied == copyKey ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accentGradient))
            }
            .disabled(rawValue.isEmpty)
            .opacity(rawValue.isEmpty ? 0.4 : 1)
        }
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }

    private var statusFooter: some View {
        Text(vm.statusText)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    private var providerHint: String {
        settings.provider == .grizzly ? "e.g. instagram or a code like ig" : "e.g. instagram"
    }

    private var providerNote: String {
        if !settings.defaultService.isEmpty && vm.service.isEmpty {
            return "Using default service from Settings: \(settings.defaultService)"
        }
        return settings.provider == .grizzly
            ? "GrizzlySMS maps a brand to a code (instagram → ig), or type a raw code."
            : "DiddySMS resolves the closest matching service automatically."
    }

    private func formattedPhone(_ digits: String) -> String {
        digits.isEmpty ? "—" : "+\(digits)"
    }
}
