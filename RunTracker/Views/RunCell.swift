//
//  RunCell.swift
//  RunTracker
//
//  Custom table view cell for one run in the history list.
//

import UIKit

// MARK: - RunCellDelegate

/// Lets the cell report a tap on its note button back to the controller that
/// owns it. The cell stays dumb: it does not know what a run detail screen is,
/// or how to push one - it only announces that the button was pressed.
///
/// AnyObject so the reference can be weak and avoid a retain cycle.
protocol RunCellDelegate: AnyObject {
    func runCellDidTapNote(_ cell: RunCell)
}

// MARK: - RunCell

class RunCell: UITableViewCell {

    // MARK: - Constants

    static let reuseIdentifier = "RunCell"

    // MARK: - Outlets

    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var paceLabel: UILabel!
    @IBOutlet weak var noteButton: UIButton!

    // MARK: - Properties

    weak var delegate: RunCellDelegate?

    // MARK: - Configuration

    func configure(with run: Run) {
        dateLabel.text = run.formattedDate
        distanceLabel.text = run.formattedDistance
        durationLabel.text = run.formattedDuration
        paceLabel.text = run.formattedPace

        // The icon fills in when the run already has a note, so the list shows
        // at a glance which runs have been annotated.
        let hasNote = run.note != nil
        let symbolName = hasNote ? "text.bubble.fill" : "square.and.pencil"
        noteButton.setImage(UIImage(systemName: symbolName), for: .normal)
        noteButton.accessibilityLabel = hasNote ? "Edit note" : "Add note"
    }

    // MARK: - Actions

    @IBAction func noteButtonTapped(_ sender: UIButton) {
        delegate?.runCellDidTapNote(self)
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        // A reused cell must not keep pointing at whoever configured it last.
        delegate = nil
    }
}
