import SwiftUI

struct NotchRootView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22)
                .fill(.black)
            if viewModel.isExpanded {
                VStack(spacing: 8) {
                    HStack(spacing: 14) {
                        ForEach(viewModel.modules, id: \.id) { module in
                            Button { viewModel.selectedID = module.id } label: {
                                Image(systemName: module.systemImage)
                                    .foregroundStyle(viewModel.selectedID == module.id ? .white : .gray)
                            }
                            .buttonStyle(.plain)
                            .help(module.title)
                        }
                    }
                    .padding(.top, 10)
                    viewModel.selected?.makeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { viewModel.isExpanded = hovering }
        }
    }
}
