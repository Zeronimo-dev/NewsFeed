import Foundation

struct NewsDetailViewModel {
    let article: Article

    var title: String { article.title }
    var articleDescription: String { article.description }
    var categoryType: String { article.categoryType }
    var imageURLString: String? { article.titleImageUrl }
    var fullURL: URL? { URL(string: article.fullUrl) }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: article.publishedDate)
    }
}
