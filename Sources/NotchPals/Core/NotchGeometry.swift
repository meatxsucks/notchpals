import AppKit

extension NSScreen {
    /// Tamaño del notch físico; en pantallas sin notch devuelve una píldora virtual.
    var notchSize: CGSize {
        guard safeAreaInsets.top > 0 else { return CGSize(width: 200, height: 32) }
        let left = auxiliaryTopLeftArea?.width ?? 0
        let right = auxiliaryTopRightArea?.width ?? 0
        return CGSize(width: frame.width - left - right, height: safeAreaInsets.top)
    }
}
