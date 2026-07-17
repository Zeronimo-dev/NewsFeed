import UIKit
import SafariServices

final class NewsDetailViewController: UIViewController {
    private let viewModel: NewsDetailViewModel

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let newsImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .tertiarySystemFill
        imageView.tintColor = .quaternaryLabel
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = 16
        return imageView
    }()

    private let categoryLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .title1)
        label.numberOfLines = 0
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .tertiaryLabel
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.numberOfLines = 0
        return label
    }()

    private lazy var openFullArticleButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Читать полностью на autodoc.ru"
        configuration.cornerStyle = .large
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(openFullArticle), for: .touchUpInside)
        return button
    }()

    init(viewModel: NewsDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        setupLayout()
        configureContent()
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),

            newsImageView.heightAnchor.constraint(equalTo: newsImageView.widthAnchor, multiplier: 9.0 / 16.0)
        ])

        contentStack.addArrangedSubview(newsImageView)
        contentStack.addArrangedSubview(categoryLabel)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(dateLabel)
        contentStack.addArrangedSubview(descriptionLabel)
        contentStack.setCustomSpacing(4, after: categoryLabel)
        contentStack.setCustomSpacing(8, after: titleLabel)
        contentStack.setCustomSpacing(20, after: dateLabel)
        contentStack.addArrangedSubview(openFullArticleButton)
    }

    private func configureContent() {
        title = viewModel.categoryType
        categoryLabel.text = viewModel.categoryType.uppercased()
        titleLabel.text = viewModel.title
        dateLabel.text = viewModel.formattedDate
        descriptionLabel.text = viewModel.articleDescription
        newsImageView.setRemoteImage(
            urlString: viewModel.imageURLString,
            placeholder: UIImage(systemName: "photo")
        )
        openFullArticleButton.isHidden = viewModel.fullURL == nil
    }

    @objc private func openFullArticle() {
        guard let url = viewModel.fullURL else { return }
        let safariViewController = SFSafariViewController(url: url)
        present(safariViewController, animated: true)
    }
}
