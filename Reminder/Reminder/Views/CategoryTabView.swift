import SwiftUI

struct CategoryTabView: View {
    @Binding var selectedCategory: Category

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Category.allCases, id: \.self) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Text(category.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 26)
                        .background(selectedCategory == category ? Theme.accent : Theme.inactiveTab)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
