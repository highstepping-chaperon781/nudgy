import Foundation
import SwiftUI

struct UsageQuota: Sendable {
    let usagePercent: Double    // 0-100
    let tier: String            // "free", "pro", "team"
    let lastFetched: Date

    var remaining: Double { max(0, 100 - usagePercent) }
    var isLow: Bool { remaining < 20 }
    var isCritical: Bool { remaining < 5 }

    var color: Color {
        if isCritical { return Color(red: 1.0, green: 0.35, blue: 0.25) }
        if isLow { return Color(red: 1.0, green: 0.6, blue: 0.15) }
        return Color(red: 0.3, green: 0.8, blue: 0.65)
    }
}

@MainActor
@Observable
final class UsageQuotaManager {
    var quota: UsageQuota?
    var isLoading = false
    var error: String?

    private static let keychainService = "com.nudgy.claude"
    private static let keychainAccount = "sessionKey"

    var isConfigured: Bool {
        guard let key = sessionKey else { return false }
        return !key.isEmpty
    }

    var sessionKey: String? {
        get { KeychainHelper.load(service: Self.keychainService, account: Self.keychainAccount) }
        set {
            if let v = newValue, !v.isEmpty {
                _ = KeychainHelper.save(service: Self.keychainService, account: Self.keychainAccount, value: v)
            } else {
                KeychainHelper.delete(service: Self.keychainService, account: Self.keychainAccount)
            }
        }
    }

    private var refreshTask: Task<Void, Never>?

    /// UUID format regex for validating org IDs before URL interpolation.
    private static let uuidPattern = try! NSRegularExpression(
        pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
        options: .caseInsensitive
    )

    /// URLSession that does not follow redirects (prevents cookie leakage via redirects).
    private static let noRedirectSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        let delegate = NoRedirectDelegate()
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()

    func fetchQuota() async {
        guard let key = sessionKey, !key.isEmpty else {
            error = "No session key configured"
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Step 1: Get organization ID
            guard let orgsURL = URL(string: "https://claude.ai/api/organizations") else {
                error = "Invalid organizations URL"
                return
            }
            var orgsReq = URLRequest(url: orgsURL)
            orgsReq.setValue("sessionKey=\(key)", forHTTPHeaderField: "Cookie")
            orgsReq.setValue("application/json", forHTTPHeaderField: "Accept")

            let (orgsData, orgsResponse) = try await Self.noRedirectSession.data(for: orgsReq)

            guard let httpResp = orgsResponse as? HTTPURLResponse, httpResp.statusCode == 200 else {
                error = "Authentication failed — check your session key"
                return
            }

            guard let orgs = try JSONSerialization.jsonObject(with: orgsData) as? [[String: Any]],
                  let firstOrg = orgs.first,
                  let orgId = firstOrg["uuid"] as? String else {
                error = "Could not parse organizations"
                return
            }

            // Validate orgId is a proper UUID to prevent SSRF via URL interpolation
            let orgIdRange = NSRange(orgId.startIndex..., in: orgId)
            guard Self.uuidPattern.firstMatch(in: orgId, range: orgIdRange) != nil else {
                error = "Invalid organization ID format"
                return
            }

            let tier = (firstOrg["billing_type"] as? String) ?? "unknown"

            // Step 2: Get usage for this org
            guard let usageURL = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage") else {
                error = "Invalid usage URL"
                return
            }
            var usageReq = URLRequest(url: usageURL)
            usageReq.setValue("sessionKey=\(key)", forHTTPHeaderField: "Cookie")
            usageReq.setValue("application/json", forHTTPHeaderField: "Accept")

            let (usageData, usageResponse) = try await Self.noRedirectSession.data(for: usageReq)

            guard let usageHttpResp = usageResponse as? HTTPURLResponse, usageHttpResp.statusCode == 200 else {
                error = "Failed to fetch usage data"
                return
            }

            // Try to parse usage - format may vary
            if let usageDict = try JSONSerialization.jsonObject(with: usageData) as? [String: Any] {
                // Look for percentage or calculate from limits
                var percent: Double = 0

                if let pct = usageDict["usage_percent"] as? Double {
                    percent = pct
                } else if let daily = usageDict["daily_usage"] as? [String: Any],
                          let used = daily["used"] as? Double,
                          let limit = daily["limit"] as? Double,
                          limit > 0 {
                    percent = (used / limit) * 100
                } else if let tokens = usageDict["tokens_used"] as? Int,
                          let limit = usageDict["tokens_limit"] as? Int,
                          limit > 0 {
                    percent = Double(tokens) / Double(limit) * 100
                }

                quota = UsageQuota(
                    usagePercent: percent,
                    tier: tier,
                    lastFetched: Date()
                )
            } else {
                // If we can't parse usage details, just report we're connected
                quota = UsageQuota(usagePercent: 0, tier: tier, lastFetched: Date())
                error = "Connected but could not parse usage details"
            }

        } catch {
            self.error = error.localizedDescription
        }
    }

    func startAutoRefresh(interval: TimeInterval = 300) {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                await fetchQuota()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

/// URLSession delegate that rejects all redirects to prevent credential leakage.
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Return nil to reject the redirect — do not follow it
        completionHandler(nil)
    }
}
