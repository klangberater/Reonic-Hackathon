import Foundation
import SwiftUI

/// The demo clock shared by Home and Plan-my-day. Changing it resets the household
/// ledger and is observed by both screens.
@MainActor final class ClockStore: ObservableObject {
    @Published var clock: DemoClock = .summer
    private let api = APIClient()

    func setClock(_ c: DemoClock) {
        guard c != clock else { return }
        clock = c
        Task { try? await api.reset() }   // fresh ledger per clock for clean demos
    }
}
