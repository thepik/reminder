import SwiftUI

struct TaskRowView: View {
    let task: ReminderTask
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(task.content)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 12)

            Button("删除", action: onDelete)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.danger)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
