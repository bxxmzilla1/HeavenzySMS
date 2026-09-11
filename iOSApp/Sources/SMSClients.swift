import Foundation

/// Shared helpers ported from the Sessions X desktop controller.
enum SMSHelpers {
    /// Keep only digits — used for phone numbers and codes.
    static func digits(_ s: String?) -> String {
        (s ?? "").filter { $0.isNumber }
    }

    /// Reduce a host/brand string to its core label (e.g. "www.instagram.com" -> "instagram").
    static func brandLabel(_ host: String) -> String {
        let raw = host.replacingOccurrences(of: "^www\\.", with: "", options: [.regularExpression, .caseInsensitive])
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return "" }
        let parts = raw.split(separator: ".").map(String.init).filter { !$0.isEmpty }
        if parts.count >= 3 {
            let tld = parts[parts.count - 1]
            let sld = parts[parts.count - 2]
            if sld == "co" && tld.count == 2 { return parts.count >= 3 ? parts[parts.count - 3] : parts[0] }
        }
        if parts.count >= 2 { return parts[parts.count - 2] }
        return raw
    }
}

enum SMSError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let m): return m }
    }
}

struct SMSOrder {
    let provider: SMSProvider
    let orderId: String
    let phone: String
    let service: String
}

// MARK: - DiddySMS

/// DiddySMS client — REST API, bearer auth. Ports the ordering + polling flow and
/// the service-resolution search/scoring from the desktop app.
struct DiddySMSClient {
    static let base = "https://api.diddysms.com/v1"
    static let carriers = ["tmobile", "att", "verizon", "metropcs", "boost", "cricket"]

    let key: String

    private func request(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> (ok: Bool, status: Int, json: [String: Any], errorMessage: String?) {
        let rel = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: Self.base + rel) else { throw SMSError.message("Bad URL") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let http = resp as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let ok = (200...299).contains(status)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        var errMsg: String? = nil
        if !ok {
            let detail = json["detail"]
            if let d = detail as? [String: Any] {
                if let e = d["error"] as? [String: Any] {
                    errMsg = (e["message"] as? String) ?? (e["code"] as? String)
                } else if let m = d["message"] as? String {
                    errMsg = m
                }
            } else if let d = detail as? String {
                errMsg = d
            } else if let arr = detail as? [[String: Any]] {
                // FastAPI request-validation errors: [{ "loc": [...], "msg": "...", "type": "..." }]
                let msgs = arr.compactMap { $0["msg"] as? String }
                if !msgs.isEmpty { errMsg = msgs.joined(separator: "; ") }
            }
            if errMsg == nil, let e = json["error"] as? [String: Any] {
                errMsg = (e["message"] as? String) ?? (e["code"] as? String)
            }
            if errMsg == nil { errMsg = (json["message"] as? String) ?? "Request failed (HTTP \(status))" }
        }
        return (ok, status, json, errMsg)
    }

    /// Resolve a search term to a ranked list of candidate DiddySMS service names
    /// (highest score first). The catalog is the source of truth for valid slugs, so
    /// ordering tries these in order until one is accepted.
    func resolveCandidates(term: String) async -> [String] {
        let hNorm = term.replacingOccurrences(of: "^www\\.", with: "", options: [.regularExpression, .caseInsensitive]).lowercased()
        guard !hNorm.isEmpty else { return [] }
        var merged: [String: [String: Any]] = [:]
        func services(_ path: String) async -> [[String: Any]] {
            guard let r = try? await request("GET", path), r.ok else { return [] }
            return (r.json["services"] as? [[String: Any]]) ?? []
        }
        // Search first (cheap), then page through the catalog if needed.
        let encoded = hNorm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? hNorm
        for svc in await services("/services?search=\(encoded)&per_page=100") {
            if let name = svc["name"] as? String, merged[name] == nil { merged[name] = svc }
        }
        if merged.isEmpty {
            var page = 1
            var totalPages = 1
            repeat {
                guard let r = try? await request("GET", "/services?page=\(page)&per_page=100"), r.ok,
                      let list = r.json["services"] as? [[String: Any]] else { break }
                for svc in list {
                    if let name = svc["name"] as? String, merged[name] == nil { merged[name] = svc }
                }
                totalPages = ((r.json["pagination"] as? [String: Any])?["total_pages"] as? Int) ?? 1
                page += 1
            } while page <= totalPages && page <= 15
        }
        let ranked = merged.values
            .map { (name: ($0["name"] as? String) ?? "", score: score(term: hNorm, svc: $0)) }
            .filter { !$0.name.isEmpty && $0.score > 0 }
            .sorted { $0.score > $1.score }
            .map { $0.name }
        return ranked
    }

    private func score(term: String, svc: [String: Any]) -> Int {
        let primary = SMSHelpers.brandLabel(term)
        guard !primary.isEmpty else { return 0 }
        let name = (svc["name"] as? String ?? "").lowercased()
        let disp = (svc["display_name"] as? String ?? "").lowercased()
        let blob = "\(name) \(disp)"
        let pr = primary.lowercased()
        let hBare = term.replacingOccurrences(of: "^www\\.", with: "", options: [.regularExpression, .caseInsensitive]).lowercased()
        var sc = 0
        if name == pr { sc += 150 }
        else if name.hasPrefix("\(pr)_") { sc += 85 }
        else if name.contains(pr) && pr.count >= 4 { sc += 62 }
        else if name.contains(pr) && pr.count >= 2 { sc += 38 }
        if disp.contains(pr) { sc += 42 }
        let firstSeg = hBare.split(separator: ".").first.map(String.init) ?? ""
        if !firstSeg.isEmpty && firstSeg != pr && disp.contains(firstSeg) { sc += 28 }
        if blob.contains(hBare.replacingOccurrences(of: ".", with: "")) { sc += 12 }
        return sc
    }

    /// Order a number. Builds a candidate slug list from the live catalog (plus the
    /// raw term as a fallback), tries each until one is accepted. If `preferredCarrier`
    /// is set (e.g. "att", "tmobile"), that carrier is requested first; otherwise
    /// DiddySMS picks, then we fall back to per-carrier ordering.
    func order(serviceTerm: String, preferredCarrier: String = "") async throws -> SMSOrder {
        let term = serviceTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { throw SMSError.message("No service configured.") }

        // Catalog matches rank first; the raw term is a last resort.
        var candidates = await resolveCandidates(term: term)
        if !candidates.contains(term) { candidates.append(term) }

        var lastError: String? = nil
        var chosen: String = term
        var order: [String: Any]? = nil

        let carrier = preferredCarrier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let carrierSet = !carrier.isEmpty && carrier != "any"

        for service in candidates {
            var body: [String: Any] = ["service": service]
            if carrierSet { body["carrier"] = carrier }
            let r = try await request("POST", "/orders", body: body)
            if let o = r.json["order"] as? [String: Any], o["id"] != nil {
                order = o; chosen = service; break
            }
            if let e = r.errorMessage { lastError = e }
        }

        // Carrier fallback on the top candidate. When the user pinned a carrier we
        // respect it and don't silently switch to a different one.
        if order == nil {
            let service = candidates.first ?? term
            let fallbackCarriers = carrierSet ? [carrier] : Self.carriers
            for c in fallbackCarriers {
                let r = try await request("POST", "/orders", body: ["service": service, "carrier": c])
                if let o = r.json["order"] as? [String: Any], o["id"] != nil {
                    order = o; chosen = service; break
                }
                if let e = r.errorMessage { lastError = e }
            }
        }

        guard let o = order, let idVal = o["id"] else {
            throw SMSError.message(lastError ?? "no number available")
        }
        let id = "\(idVal)"
        let phone = SMSHelpers.digits(o["phone_number"] as? String ?? "\(o["phone_number"] ?? "")")
        return SMSOrder(provider: .diddy, orderId: id, phone: phone, service: chosen)
    }

    /// Poll an order for its SMS code (empty string = not yet arrived).
    func poll(orderId: String) async throws -> String {
        let r = try await request("GET", "/orders/\(orderId)")
        guard r.ok else { throw SMSError.message(r.errorMessage ?? "poll failed") }
        guard let o = r.json["order"] as? [String: Any] else { return "" }
        if let c = o["sms_code"] as? String { return SMSHelpers.digits(c) }
        if let c = o["sms_code"], "\(c)" != "<null>" { return SMSHelpers.digits("\(c)") }
        return ""
    }
}

// MARK: - GrizzlySMS

/// GrizzlySMS client — sms-activate compatible single-endpoint protocol returning
/// plain-text responses. Ports the service map, ordering, polling and cancel flow.
struct GrizzlySMSClient {
    static let base = "https://api.grizzlysms.com/stubs/handler_api.php"

    static let serviceMap: [String: String] = [
        "instagram": "ig", "threads": "ig", "facebook": "fb", "fb": "fb",
        "google": "go", "gmail": "go", "youtube": "go", "go": "go",
        "tiktok": "lf", "discord": "ds", "telegram": "tg", "whatsapp": "wa",
        "twitter": "tw", "x": "tw", "snapchat": "fu", "reddit": "re",
        "microsoft": "mm", "outlook": "mm", "hotmail": "mm", "yahoo": "mb",
        "amazon": "am", "apple": "wx", "tinder": "oi", "bumble": "mo", "signal": "bw",
        "linkedin": "tn", "pinterest": "mj", "twitch": "ze", "paypal": "ts", "netflix": "nf",
    ]

    static let errors: [String: String] = [
        "BAD_KEY": "Invalid GrizzlySMS API key — check it in Settings.",
        "NO_BALANCE": "GrizzlySMS balance is empty — top up your account.",
        "NO_NUMBERS": "No numbers available right now — try again or another country.",
        "BAD_SERVICE": "Unknown service code — set a valid one in Settings.",
        "SERVICE_UNAVAILABLE_REGION": "GrizzlySMS is blocked from this IP/region.",
        "BAD_ACTION": "GrizzlySMS request rejected (bad action).",
    ]

    let key: String

    static func message(_ resp: String) -> String {
        let t = resp.trimmingCharacters(in: .whitespacesAndNewlines)
        return errors[t] ?? (t.isEmpty ? "request failed" : t)
    }

    /// Map a user-entered service term to an sms-activate short code.
    static func serviceCode(for term: String) -> String {
        let brand = SMSHelpers.brandLabel(term)
        let hNorm = term.replacingOccurrences(of: "^www\\.", with: "", options: [.regularExpression, .caseInsensitive]).lowercased()
        if let c = serviceMap[brand] ?? serviceMap[hNorm] { return c }
        let def = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !def.isEmpty {
            if let c = serviceMap[def] { return c }
            if def.count <= 4 { return def } // assume a raw service code
        }
        return ""
    }

    private func call(_ params: [String: String]) async throws -> String {
        var comps = URLComponents(string: Self.base)!
        var items = [URLQueryItem(name: "api_key", value: key)]
        for (k, v) in params where !v.isEmpty { items.append(URLQueryItem(name: k, value: v)) }
        comps.queryItems = items
        guard let url = comps.url else { throw SMSError.message("Bad URL") }
        let (data, _) = try await URLSession.shared.data(from: url)
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func order(serviceTerm: String, country: String, maxPrice: String) async throws -> SMSOrder {
        let service = Self.serviceCode(for: serviceTerm)
        guard !service.isEmpty else {
            throw SMSError.message("No GrizzlySMS service code for \"\(serviceTerm)\". Enter a code like \"ig\" in Settings.")
        }
        var params: [String: String] = [
            "action": "getNumber",
            "service": service,
            "country": country.isEmpty ? "any" : country,
        ]
        let mp = maxPrice.trimmingCharacters(in: .whitespacesAndNewlines)
        if !mp.isEmpty, Double(mp) != nil { params["maxPrice"] = mp }

        let text = try await call(params)
        if text.hasPrefix("ACCESS_NUMBER:") {
            let parts = text.components(separatedBy: ":")
            let activationId = parts.count > 1 ? parts[1] : ""
            let phone = SMSHelpers.digits(parts.count > 2 ? parts[2] : "")
            return SMSOrder(provider: .grizzly, orderId: activationId, phone: phone, service: service)
        }
        throw SMSError.message(Self.message(text))
    }

    /// Poll for a code. Returns "" while waiting. On success, tells Grizzly the code
    /// was used (status 6) so the activation completes cleanly.
    func poll(orderId: String) async throws -> String {
        let text = try await call(["action": "getStatus", "id": orderId])
        if text.hasPrefix("STATUS_OK:") {
            let code = SMSHelpers.digits(String(text.dropFirst("STATUS_OK:".count)))
            Task { _ = try? await call(["action": "setStatus", "id": orderId, "status": "6"]) }
            return code
        }
        if text.hasPrefix("STATUS_") { return "" }
        throw SMSError.message(Self.message(text))
    }

    /// Cancel an unfinished activation (status 8) so the number is released/refunded.
    func cancel(orderId: String) async {
        _ = try? await call(["action": "setStatus", "id": orderId, "status": "8"])
    }
}
