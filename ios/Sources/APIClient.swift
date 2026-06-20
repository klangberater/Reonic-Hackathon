import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct APIClient: Sendable {
    var baseURL: String = Config.baseURL

    // MARK: reads
    func state(household: String = Config.defaultHousehold, clock: DemoClock) async throws -> EnergyState {
        try await get("/now", household: household, clock: clock)
    }
    func money(household: String = Config.defaultHousehold, clock: DemoClock) async throws -> Money {
        try await get("/money", household: household, clock: clock)
    }
    func devices(household: String = Config.defaultHousehold, clock: DemoClock) async throws -> [Device] {
        try await get("/devices", household: household, clock: clock)
    }
    func insights(household: String = Config.defaultHousehold, clock: DemoClock) async throws -> Insights {
        try await get("/insights", household: household, clock: clock)
    }
    func optimize(device: String, household: String = Config.defaultHousehold, clock: DemoClock) async throws -> OptimizeResult {
        try await get("/optimize_load", household: household, clock: clock, extra: [.init(name: "device", value: device)])
    }

    // MARK: writes
    func commit(device: String, household: String = Config.defaultHousehold, clock: DemoClock) async throws -> CommitResponse {
        try await post("/commit_load", body: ["household": household, "device": device, "clock": clock.rawValue])
    }
    func reset(household: String = Config.defaultHousehold) async throws {
        let _: ResetResp = try await post("/reset", body: ["household": household])
    }
    private struct ResetResp: Decodable { let ok: Bool }

    func chat(message: String, history: [ChatMessage], household: String = Config.defaultHousehold, clock: DemoClock) async throws -> ChatResponse {
        let body: [String: Any] = [
            "household": household, "clock": clock.rawValue, "message": message,
            "history": history.map { ["role": $0.role, "content": $0.content] },
        ]
        return try await postJSON("/chat", body: body)
    }

    private func postJSON<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError(message: "bad URL") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !Config.chatToken.isEmpty { req.setValue(Config.chatToken, forHTTPHeaderField: "x-lumen-token") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 40
        let (data, resp) = try await URLSession.shared.data(for: req)
        try check(resp)
        return try decoder().decode(T.self, from: data)
    }

    // MARK: plumbing
    private func get<T: Decodable>(_ path: String, household: String, clock: DemoClock, extra: [URLQueryItem] = []) async throws -> T {
        guard var c = URLComponents(string: baseURL + path) else { throw APIError(message: "bad URL") }
        c.queryItems = [.init(name: "household", value: household), .init(name: "clock", value: clock.rawValue)] + extra
        guard let url = c.url else { throw APIError(message: "bad URL") }
        let (data, resp) = try await URLSession.shared.data(from: url)
        try check(resp)
        return try decoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: String]) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError(message: "bad URL") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try check(resp)
        return try decoder().decode(T.self, from: data)
    }

    private func check(_ resp: URLResponse) throws {
        guard let h = resp as? HTTPURLResponse, (200..<300).contains(h.statusCode) else {
            throw APIError(message: "server returned \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
        }
    }
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }
}
