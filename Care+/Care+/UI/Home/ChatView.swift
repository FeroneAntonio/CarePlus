import SwiftUI

struct ChatView: View {
    @Bindable var state: AppState

    /// Binding to the current tab (used to go back)
    @Binding var selectedTab: AppTab

    /// Last non-chat tab visited
    let lastNonChatTab: AppTab

    @StateObject private var vm = ChatViewModel()
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var composerHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            VStack(spacing: 12) {

                // ✅ Custom top bar (no system navigation bar)
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = lastNonChatTab
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .frame(width: 40, height: 40)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.stroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    VStack(spacing: 1) {
                        Text("Chat")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(vm.partnerName)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Color.clear
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                // Info banner (UPDATED TEXT)
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Private conversation with \(vm.partnerName).")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)

                ZStack {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(vm.messages) { msg in
                                    ChatBubble(message: msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .padding(.bottom, composerHeight + 20)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onAppear {
                            scrollProxy = proxy
                            scrollToBottom(animated: false)
                        }
                        .onChange(of: vm.messages) { _ in
                            scrollToBottom(animated: true)
                        }
                    }

                    if vm.isLoading {
                        ProgressView("Loading conversation…")
                            .foregroundStyle(AppTheme.textSecondary)
                    } else if let error = vm.errorMessage, vm.messages.isEmpty {
                        ContentUnavailableView {
                            Label("Chat unavailable", systemImage: "exclamationmark.bubble")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Try again") {
                                Task { await vm.retry(state: state) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else if vm.messages.isEmpty {
                        ContentUnavailableView(
                            "No messages yet",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("Send the first message to \(vm.partnerName).")
                        )
                    }
                }
            }
            .padding(.top, 6)
            .onTapGesture { dismissKeyboard() }

            // Composer
            HStack(spacing: 10) {
                TextField("Write a message...", text: $vm.draftText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    Task { await vm.send() }
                } label: {
                    Group {
                        if vm.isSending {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.headline.weight(.bold))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(AppTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!vm.canSend)
                .opacity(vm.canSend ? 1 : 0.45)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ComposerHeightKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(ComposerHeightKey.self) { composerHeight = $0 }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
        .task {
            await vm.start(state: state)
        }
        .onDisappear {
            vm.stop()
        }
    }

    private func scrollToBottom(animated: Bool) {
        guard let lastId = vm.messages.last?.id else { return }
        withAnimation(animated ? .easeOut(duration: 0.25) : nil) {
            scrollProxy?.scrollTo(lastId, anchor: .bottom)
        }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil,
                                        from: nil,
                                        for: nil)
        #endif
    }
}

private struct ComposerHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    ChatView(state: AppState(), selectedTab: .constant(.home), lastNonChatTab: .home)
}
