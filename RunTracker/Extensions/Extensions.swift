//
//  Extensions.swift
//  RunTracker
//
//  Small shared helpers used across the app.
//

import UIKit

// MARK: - Int (Time Formatting)

extension Int {

    /// Seconds rendered as a clock string: "32:15", or "1:02:15" past an hour.
    /// Used for both run duration and pace, so the two always read the same way.
    var asClockString: String {
        let safeValue = max(0, self)
        let hours = safeValue / 3600
        let minutes = (safeValue % 3600) / 60
        let seconds = safeValue % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - String (Validation)

extension String {

    /// The string with leading/trailing whitespace and newlines removed.
    var trimmed: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when the string is empty or only whitespace.
    var isBlank: Bool {
        return trimmed.isEmpty
    }

    /// Trimmed value, or nil when there is nothing meaningful in it.
    /// Keeps blank notes from being stored as " " in Firestore.
    var nilIfBlank: String? {
        return isBlank ? nil : trimmed
    }
}

// MARK: - UIViewController (Toast)

extension UIViewController {

    /// Shows a short confirmation message that fades away on its own.
    ///
    /// The colours are deliberately inverted semantic ones (`.label` background
    /// with `.systemBackground` text), so the toast stays readable in both light
    /// and dark mode without any conditional code.
    func showToast(message: String, duration: TimeInterval = 2.0) {
        let container = UIView()
        container.backgroundColor = UIColor.label.withAlphaComponent(0.9)
        container.layer.cornerRadius = 14
        container.clipsToBounds = true
        container.alpha = 0
        container.translatesAutoresizingMaskIntoConstraints = false

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = .systemBackground
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(messageLabel)
        view.addSubview(container)

        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                              constant: -24),
            // Keeps the toast from running off the edge in landscape.
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor,
                                               constant: 24),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor,
                                                constant: -24)
        ])

        UIView.animate(withDuration: 0.25, animations: {
            container.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.35, delay: duration, options: [], animations: {
                container.alpha = 0
            }, completion: { _ in
                container.removeFromSuperview()
            })
        })
    }

    /// Standard single-button alert, used for permission and error messages.
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
