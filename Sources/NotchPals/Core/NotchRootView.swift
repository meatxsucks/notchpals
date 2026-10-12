import SwiftUI

struct NotchRootView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject private var mascot = MascotModel.shared
    @State private var dropTargeted = false

    var body: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22)
                .fill(.black)
            if viewModel.isExpanded {
                VStack(spacing: 8) {
                    HStack(spacing: 14) {
                        MascotView(mood: mascot.mood, size: 22)
                        Spacer()
                        ForEach(viewModel.modules, id: \.id) { module in
                            Button { viewModel.selectedID = module.id } label: {
                                Image(systemName: module.systemImage)
                                    .foregroundStyle(viewModel.selectedID == module.id ? .white : .gray)
                            }
                            .buttonStyle(.plain)
                            .help(module.title)
                        }
                        Spacer()
                        Color.clear.frame(width: 22, height: 22) // equilibra a Dot para centrar las pestañas
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
        .onHover { viewModel.setHovering($0) }
        .notchFileDrop(isTargeted: $dropTargeted)
        .onChange(of: dropTargeted) { targeted in
            mascot.isDraggingFile = targeted
            // Abre el notch (en el Chat) mientras arrastras un archivo encima.
            viewModel.setNeedsAttention(targeted, focusing: targeted ? "claude" : nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: NotchDrop.didDrop)) { _ in
            viewModel.selectedID = "claude"
        }
    }
}
