//
//  SetupRequiredController.swift
//  RunTracker
//
//  Shown only when GoogleService-Info.plist is missing. Built in code on
//  purpose: it has to work before anything else is configured, and it is not
//  part of the app's real navigation flow.
//

import UIKit

class SetupRequiredController: UIViewController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "Firebase setup needed"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let bodyLabel = UILabel()
        bodyLabel.text = """
            GoogleService-Info.plist is missing from the app bundle.

            Download it from the Firebase console and drag it into the \
            RunTracker target in Xcode, then run again.

            Full steps are in README.md.
            """
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0

        let stackView = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor)
        ])
    }
}
