import Foundation
import Combine

@MainActor
final class SMSViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case ordering
        case waiting          // have a number, polling for code
        case received         // code arrived
    }

    /// The only supported service for now.
    static let fixedService = "instagram"

    @Published var phase: Phase = .idle
    @Published var service: String = fixedService
    @Published var phone: String = ""
    @Published var code: String = ""
    @Published var activeProvider: SMSProvider = .diddy
    @Published var orderId: String = ""
    @Published var errorMessage: String? = nil
    @Published var statusText: String = "Ready"

    private var settings: AppSettings
    private var pollTask: Task<Void, Never>? = nil

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// Rebind to the real environment settings object (the view creates the model
    /// with a placeholder because @StateObject cannot read @EnvironmentObject at init).
    func attach(_ settings: AppSettings) {
        self.settings = settings
    }

    var isBusy: Bool { phase == .ordering }
    var hasOrder: Bool { phase == .waiting || phase == .received }

    func requestNumber() {
        guard phase == .idle || phase == .received else { return }
        errorMessage = nil
        code = ""
        phone = ""
        orderId = ""
        phase = .ordering
        statusText = "Ordering an Instagram number…"
        let provider = settings.provider
        activeProvider = provider
        let term = Self.fixedService

        Task {
            do {
                let order: SMSOrder
                switch provider {
                case .diddy:
                    let key = settings.normalizedDiddyKey
                    guard !key.isEmpty else { throw SMSError.message("Add your DiddySMS API key in Settings first.") }
                    order = try await DiddySMSClient(key: key).order(serviceTerm: term, preferredCarrier: settings.diddyCarrier)
                case .grizzly:
                    let key = settings.grizzlyKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !key.isEmpty else { throw SMSError.message("Add your GrizzlySMS API key in Settings first.") }
                    order = try await GrizzlySMSClient(key: key).order(
                        serviceTerm: term,
                        country: settings.grizzlyCountry,
                        maxPrice: settings.grizzlyMaxPrice
                    )
                }
                self.orderId = order.orderId
                self.phone = order.phone
                self.phase = .waiting
                self.statusText = "Number ready — waiting for SMS code…"
                self.startPolling()
            } catch {
                self.phase = .idle
                self.statusText = "Ready"
                self.errorMessage = (error as? SMSError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        let provider = activeProvider
        let id = orderId
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                if Task.isCancelled { break }
                do {
                    let c: String
                    switch provider {
                    case .diddy:
                        c = try await DiddySMSClient(key: settings.normalizedDiddyKey).poll(orderId: id)
                    case .grizzly:
                        c = try await GrizzlySMSClient(key: settings.grizzlyKey.trimmingCharacters(in: .whitespacesAndNewlines)).poll(orderId: id)
                    }
                    if !c.isEmpty {
                        self.code = c
                        self.phase = .received
                        self.statusText = "SMS code received"
                        break
                    }
                } catch {
                    self.errorMessage = (error as? SMSError)?.errorDescription ?? error.localizedDescription
                    // Keep waiting on transient errors; the user can release manually.
                }
            }
        }
    }

    /// Poll immediately (manual refresh).
    func pollNow() {
        guard phase == .waiting, !orderId.isEmpty else { return }
        let provider = activeProvider
        let id = orderId
        Task {
            do {
                let c: String
                switch provider {
                case .diddy:
                    c = try await DiddySMSClient(key: settings.normalizedDiddyKey).poll(orderId: id)
                case .grizzly:
                    c = try await GrizzlySMSClient(key: settings.grizzlyKey.trimmingCharacters(in: .whitespacesAndNewlines)).poll(orderId: id)
                }
                if !c.isEmpty {
                    self.code = c
                    self.phase = .received
                    self.statusText = "SMS code received"
                }
            } catch {
                self.errorMessage = (error as? SMSError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// Release the current number (cancels a still-open GrizzlySMS activation) and reset.
    func release() {
        pollTask?.cancel()
        pollTask = nil
        if activeProvider == .grizzly, !orderId.isEmpty, code.isEmpty {
            let key = settings.grizzlyKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = orderId
            if !key.isEmpty {
                Task { await GrizzlySMSClient(key: key).cancel(orderId: id) }
            }
        }
        phase = .idle
        phone = ""
        code = ""
        orderId = ""
        statusText = "Ready"
        errorMessage = nil
    }
}
