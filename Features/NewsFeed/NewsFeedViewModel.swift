import Foundation
import Combine

@MainActor
final class NewsFeedViewModel {
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoadingInitial = false
    @Published private(set) var isLoadingPage = false
    @Published private(set) var errorMessage: String?

    private let service: NewsAPIServiceProtocol
    private let pageSize: Int
    private var currentPage = 1
    private var totalCount = Int.max
    private var loadTask: Task<Void, Never>?

    init(service: NewsAPIServiceProtocol = NewsAPIService(), pageSize: Int = 15) {
        self.service = service
        self.pageSize = pageSize
    }

    private var hasMorePages: Bool { articles.count < totalCount }

    func loadInitialPageIfNeeded() {
        guard articles.isEmpty, loadTask == nil else { return }
        loadTask = Task { await loadPage(reset: true) }
    }

    func refresh() async {
        loadTask?.cancel()
        await loadPage(reset: true)
    }

    func loadNextPageIfNeeded(currentIndex: Int) {
        guard loadTask == nil, hasMorePages else { return }
        let prefetchThreshold = articles.count - 5
        guard currentIndex >= prefetchThreshold else { return }
        loadTask = Task { await loadPage(reset: false) }
    }

    private func loadPage(reset: Bool) async {
        if reset {
            isLoadingInitial = true
            currentPage = 1
        } else {
            isLoadingPage = true
        }
        errorMessage = nil

        defer {
            isLoadingInitial = false
            isLoadingPage = false
            loadTask = nil
        }

        do {
            let page = try await service.fetchNews(page: currentPage, pageSize: pageSize)
            if Task.isCancelled { return }

            totalCount = page.totalCount
            if reset {
                articles = page.news
            } else {
                let existingIDs = Set(articles.map(\.id))
                articles += page.news.filter { !existingIDs.contains($0.id) }
            }
            currentPage += 1
        } catch is CancellationError {
            // Ignored: superseded by a newer request.
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
