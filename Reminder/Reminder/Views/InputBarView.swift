import SwiftUI

struct InputBarView: View {
    @Binding var text: String
    let canSave: Bool
    let focus: FocusState<Bool>.Binding
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            TextField(
                "",
                text: $text,
                prompt: Text("请输入...")
                    .foregroundStyle(Theme.placeholder)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Theme.bg)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.accent, lineWidth: 1)
            )
                .focused(focus)
                .onSubmit(onSave)

            Button("保存", action: onSave)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 105, height: 44)
                .background(Theme.accent.opacity(canSave ? 1 : 0.45))
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!canSave)
        }
    }
}
