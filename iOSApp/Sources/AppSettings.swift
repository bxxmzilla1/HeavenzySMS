import Foundation
import Combine

enum SMSProvider: String, CaseIterable, Identifiable {
    case diddy
    case grizzly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .diddy: return "DiddySMS"
        case .grizzly: return "GrizzlySMS"
        }
    }
}

/// A DiddySMS carrier choice (value = the API `carrier` slug; "any" = let DiddySMS pick).
struct DiddyCarrier: Identifiable, Hashable {
    let id: String
    let name: String
    static let all: [DiddyCarrier] = [
        .init(id: "any", name: "Any — let DiddySMS pick"),
        .init(id: "att", name: "AT&T"),
        .init(id: "tmobile", name: "T-Mobile"),
        .init(id: "verizon", name: "Verizon"),
        .init(id: "metropcs", name: "Metro by T-Mobile"),
        .init(id: "boost", name: "Boost Mobile"),
        .init(id: "cricket", name: "Cricket"),
    ]
}

/// A GrizzlySMS country choice (value = sms-activate country id).
struct GrizzlyCountry: Identifiable, Hashable {
    let id: String
    let name: String
    static let all: [GrizzlyCountry] = [
        .init(id: "any", name: "Any — auto-pick best available"),
        .init(id: "33", name: "Colombia — ~$0.02 (Instagram)"),
        .init(id: "19", name: "Nigeria — ~$0.05 (Instagram)"),
        .init(id: "4", name: "Philippines — ~$0.06 (Instagram)"),
        .init(id: "12", name: "USA (virtual) — ~$0.03 (Instagram)"),
        .init(id: "187", name: "USA — ~$0.08 (Instagram)"),
        .init(id: "6", name: "Indonesia"),
        .init(id: "22", name: "India"),
        .init(id: "16", name: "England"),
        .init(id: "36", name: "Canada"),
        .init(id: "73", name: "Brazil"),
        .init(id: "54", name: "Mexico"),
    ]
}

/// Persistent app settings, mirroring the DiddySMS / GrizzlySMS options from the
/// Sessions X desktop controller. Stored in UserDefaults.
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var provider: SMSProvider { didSet { defaults.set(provider.rawValue, forKey: "smsProvider") } }
    @Published var diddyKey: String { didSet { defaults.set(diddyKey, forKey: "diddySmsKey") } }
    @Published var diddyCarrier: String { didSet { defaults.set(diddyCarrier, forKey: "diddyCarrier") } }
    @Published var grizzlyKey: String { didSet { defaults.set(grizzlyKey, forKey: "grizzlySmsKey") } }
    @Published var grizzlyCountry: String { didSet { defaults.set(grizzlyCountry, forKey: "grizzlyCountry") } }
    @Published var grizzlyMaxPrice: String { didSet { defaults.set(grizzlyMaxPrice, forKey: "grizzlyMaxPrice") } }
    @Published var defaultService: String { didSet { defaults.set(defaultService, forKey: "defaultService") } }

    init() {
        let p = defaults.string(forKey: "smsProvider") ?? SMSProvider.diddy.rawValue
        provider = SMSProvider(rawValue: p) ?? .diddy
        diddyKey = defaults.string(forKey: "diddySmsKey") ?? ""
        diddyCarrier = defaults.string(forKey: "diddyCarrier") ?? "any"
        grizzlyKey = defaults.string(forKey: "grizzlySmsKey") ?? ""
        grizzlyCountry = defaults.string(forKey: "grizzlyCountry") ?? "any"
        grizzlyMaxPrice = defaults.string(forKey: "grizzlyMaxPrice") ?? ""
        defaultService = defaults.string(forKey: "defaultService") ?? ""
    }

    /// Normalize a DiddySMS key, stripping any leading "Bearer ".
    var normalizedDiddyKey: String {
        var k = diddyKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = k.range(of: "^bearer\\s+", options: [.regularExpression, .caseInsensitive]) {
            k = String(k[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return k
    }
}
