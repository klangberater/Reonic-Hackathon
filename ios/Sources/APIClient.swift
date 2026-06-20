import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct APIClient: Sendable {
    var baseURL: String = Config.baseURL

    func state(household: String = Config.defaultHousehold, clock: DemoClock) async throws -> EnergyState {
        guard var comps = URLComponents(string: baseURL + "/state") else {
            throw APIError(message: "bad base URL")
        }
        comps.queryItems = [
            .init(name: "household", value: household),
            .init(name: "clock", value: clock.rawValue),
        ]
        guard let url = comps.url else { throw APIError(message: "bad URL") }

        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(message: "server returned \(code)")
        }
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try dec.decode(EnergyState.self, from: data)
    }
}
