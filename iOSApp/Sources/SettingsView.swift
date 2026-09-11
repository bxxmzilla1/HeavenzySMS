import SwiftUI

/// Settings: SMS provider selection and all API keys / provider options.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    LogoHeader()

                    // Provider
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("SMS provider", systemImage: "antenna.radiowaves.left.and.right")
                            Picker("Provider", selection: $settings.provider) {
                                ForEach(SMSProvider.allCases) { p in
                                    Text(p.label).tag(p)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    // DiddySMS
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("DiddySMS", systemImage: "key.fill")
                            secureField("DiddySMS API key", text: $settings.diddyKey, placeholder: "Bearer key from diddysms.com")

                            fieldLabel("Carrier")
                            Picker("Carrier", selection: $settings.diddyCarrier) {
                                ForEach(DiddyCarrier.all) { c in
                                    Text(c.name).tag(c.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.purpleBright)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10).padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.25)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardStroke, lineWidth: 1))
                            Text("Pick AT&T or T-Mobile to force that network, or Any to let DiddySMS choose.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    // GrizzlySMS
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("GrizzlySMS", systemImage: "key.fill")
                            secureField("GrizzlySMS API key", text: $settings.grizzlyKey, placeholder: "API key from grizzlysms.com")

                            fieldLabel("Country")
                            Picker("Country", selection: $settings.grizzlyCountry) {
                                ForEach(GrizzlyCountry.all) { c in
                                    Text(c.name).tag(c.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.purpleBright)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10).padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.25)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardStroke, lineWidth: 1))

                            plainField("Max price (optional)", text: $settings.grizzlyMaxPrice, placeholder: "e.g. 0.07 — never buy above this (USD)", keyboard: .decimalPad)
                        }
                    }

                    // Service (fixed)
                    GlassCard {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Theme.accentGradient)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Service")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textSecondary)
                                Text("Instagram only (for now)")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            Spacer()
                        }
                    }

                    Text("Keys are stored only on this device.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                        .foregroundColor(Theme.purpleBright)
                }
            }
        }
    }

    // MARK: - Field builders

    private func sectionTitle(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundColor(Theme.textPrimary)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(Theme.textSecondary)
    }

    private func secureField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)
            SecureField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .padding(.vertical, 12).padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.25)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardStroke, lineWidth: 1))
        }
    }

    private func plainField(_ label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .padding(.vertical, 12).padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.25)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardStroke, lineWidth: 1))
        }
    }
}
