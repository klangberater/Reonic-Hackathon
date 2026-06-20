import SwiftUI

@MainActor
final class ChatVM: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input = ""
    @Published var sending = false
    let clock: DemoClock
    private let api = APIClient()

    init(clock: DemoClock) { self.clock = clock }

    func send(_ text: String? = nil) {
        let msg = (text ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty, !sending else { return }
        input = ""
        let history = messages
        messages.append(ChatMessage(role: "user", content: msg))
        sending = true
        Task {
            do {
                let r = try await api.chat(message: msg, history: history, clock: clock)
                messages.append(ChatMessage(role: "assistant", content: r.reply))
            } catch {
                messages.append(ChatMessage(role: "assistant", content: "I couldn’t reach the assistant just now. (\(error.localizedDescription))"))
            }
            sending = false
        }
    }
}

struct ChatView: View {
    @StateObject private var vm: ChatVM
    @Environment(\.dismiss) private var dismiss

    private let suggestions = [
        "Should I run the dishwasher now?",
        "Am I saving money this month?",
        "Why might my bill be high?",
    ]

    init(clock: DemoClock) { _vm = StateObject(wrappedValue: ChatVM(clock: clock)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if vm.messages.isEmpty { emptyState }
                            ForEach(vm.messages) { bubble($0) }
                            if vm.sending { typing.id("typing") }
                        }
                        .padding(16)
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        withAnimation { proxy.scrollTo(vm.messages.last?.id, anchor: .bottom) }
                    }
                }
                inputBar
            }
            .navigationTitle("Ask Lumen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask me anything about your energy.").font(.headline).foregroundStyle(Theme.subtle)
            ForEach(suggestions, id: \.self) { s in
                Button { vm.send(s) } label: {
                    Text(s).font(.subheadline)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }.padding(.top, 8)
    }

    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.role == "user" { Spacer(minLength: 40) }
            Text(m.content)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(m.role == "user" ? Theme.green : Theme.card,
                            in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(m.role == "user" ? .white : Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if m.role == "assistant" { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: m.role == "user" ? .trailing : .leading)
    }

    private var typing: some View {
        HStack(spacing: 6) {
            ProgressView()
            Text("thinking…").font(.footnote).foregroundStyle(Theme.subtle)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask anything…", text: $vm.input, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.card, in: Capsule())
                .lineLimit(1...4)
                .onSubmit { vm.send() }
            Button { vm.send() } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 30))
                    .foregroundStyle(vm.input.isEmpty || vm.sending ? Theme.subtle : Theme.green)
            }
            .disabled(vm.input.isEmpty || vm.sending)
        }
        .padding(12)
        .background(.bar)
    }
}
