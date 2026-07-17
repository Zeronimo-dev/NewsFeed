import UIKit

private var loadTaskKey: UInt8 = 0
private var loadTokenKey: UInt8 = 0

extension UIImageView {
    private var loadTask: Task<Void, Never>? {
        get { objc_getAssociatedObject(self, &loadTaskKey) as? Task<Void, Never> }
        set { objc_setAssociatedObject(self, &loadTaskKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    private var loadToken: UUID? {
        get { objc_getAssociatedObject(self, &loadTokenKey) as? UUID }
        set { objc_setAssociatedObject(self, &loadTokenKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    func setRemoteImage(urlString: String?, placeholder: UIImage? = nil) {
        loadTask?.cancel()
        image = placeholder

        guard let urlString, let url = URL(string: urlString) else {
            loadToken = nil
            return
        }

        let token = UUID()
        loadToken = token

        loadTask = Task { [weak self] in
            do {
                let image = try await ImageLoader.shared.loadImage(from: url)
                if Task.isCancelled { return }
                await MainActor.run {
                    guard let self, self.loadToken == token else { return }
                    self.image = image
                }
            } catch {
                // Keep placeholder on failure.
            }
        }
    }

    func cancelRemoteImageLoad() {
        loadTask?.cancel()
        loadTask = nil
        loadToken = nil
    }
}
