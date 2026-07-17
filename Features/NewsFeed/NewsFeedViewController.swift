import UIKit
import Combine

final class NewsFeedViewController: UIViewController {
    private enum Section {
        case main
    }

    private typealias DataSource = UICollectionViewDiffableDataSource<Section, Article>
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Article>

    private let viewModel: NewsFeedViewModel
    private var cancellables = Set<AnyCancellable>()
    private var dataSource: DataSource!
    private var showsFooterLoader = false

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { [weak self] _, environment in
            self?.makeSectionLayout(for: environment) ?? Self.fallbackSectionLayout()
        }
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private let refreshControl = UIRefreshControl()

    private let initialActivityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    init(viewModel: NewsFeedViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Новости"
        view.backgroundColor = .systemGroupedBackground

        setupCollectionView()
        setupDataSource()
        bindViewModel()

        viewModel.loadInitialPageIfNeeded()
    }

    // MARK: - Layout

    private func setupCollectionView() {
        view.addSubview(collectionView)
        view.addSubview(initialActivityIndicator)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            initialActivityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            initialActivityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        collectionView.delegate = self
        collectionView.register(NewsCell.self, forCellWithReuseIdentifier: NewsCell.reuseIdentifier)
        collectionView.register(
            LoadingFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: LoadingFooterView.reuseIdentifier
        )

        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    /// Adapts the number of grid columns to the available width, so the same
    /// layout works for iPhone (compact) and iPad (regular, split view, rotation).
    private func makeSectionLayout(for environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let width = environment.container.effectiveContentSize.width
        let columns: Int
        switch width {
        case ..<500: columns = 1
        case 500..<900: columns = 2
        default: columns = 3
        }

        let spacing: CGFloat = 16

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(320)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: spacing / 2, bottom: 0, trailing: spacing / 2)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(320)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitem: item,
            count: columns
        )
        group.contentInsets = NSDirectionalEdgeInsets(top: spacing / 2, leading: 0, bottom: spacing / 2, trailing: 0)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: spacing, leading: spacing, bottom: spacing, trailing: spacing
        )

        let footerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(showsFooterLoader ? 60 : 0.01)
        )
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: footerSize,
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom
        )
        section.boundarySupplementaryItems = [footer]

        return section
    }

    private static func fallbackSectionLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(320))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        return NSCollectionLayoutSection(group: group)
    }

    // MARK: - Data source

    private func setupDataSource() {
        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, article in
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: NewsCell.reuseIdentifier, for: indexPath
            ) as? NewsCell else {
                return UICollectionViewCell()
            }
            cell.configure(with: article)
            return cell
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self, kind == UICollectionView.elementKindSectionFooter else { return nil }
            guard let footer = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: LoadingFooterView.reuseIdentifier, for: indexPath
            ) as? LoadingFooterView else {
                return nil
            }
            if self.showsFooterLoader {
                footer.start()
            } else {
                footer.stop()
            }
            return footer
        }
    }

    private func applySnapshot(with articles: [Article]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(articles, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$articles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] articles in
                self?.applySnapshot(with: articles)
            }
            .store(in: &cancellables)

        viewModel.$isLoadingInitial
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self else { return }
                if isLoading, self.dataSource.snapshot().numberOfItems == 0 {
                    self.initialActivityIndicator.startAnimating()
                } else {
                    self.initialActivityIndicator.stopAnimating()
                }
                if !isLoading {
                    self.refreshControl.endRefreshing()
                }
            }
            .store(in: &cancellables)

        viewModel.$isLoadingPage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self, self.showsFooterLoader != isLoading else { return }
                self.showsFooterLoader = isLoading
                self.collectionView.collectionViewLayout.invalidateLayout()
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.presentError(message)
            }
            .store(in: &cancellables)
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }

    @objc private func handleRefresh() {
        Task { await viewModel.refresh() }
    }
}

// MARK: - UICollectionViewDelegate

extension NewsFeedViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        viewModel.loadNextPageIfNeeded(currentIndex: indexPath.item)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let article = dataSource.itemIdentifier(for: indexPath) else { return }
        let detailViewModel = NewsDetailViewModel(article: article)
        let detailViewController = NewsDetailViewController(viewModel: detailViewModel)
        navigationController?.pushViewController(detailViewController, animated: true)
    }
}
