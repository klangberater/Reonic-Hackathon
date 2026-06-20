import Foundation

enum Config {
    /// Public API base (nginx strips /api/ → backend routes /state, /health, /chat).
    /// Override for local dev by pointing at http://localhost:8090 (needs an ATS exception).
    static let baseURL = "https://getfletcher.ai/api"
    static let defaultHousehold = "HH-1001"
    /// Optional shared token for /chat (matches the server's CHAT_TOKEN). Empty = not sent.
    static let chatToken = ""
}
