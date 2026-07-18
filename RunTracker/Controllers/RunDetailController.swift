//
//  RunDetailController.swift
//  RunTracker
//
//  One run, in full, with an editable note.
//

import UIKit
import MapKit

class RunDetailController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var distanceValueLabel: UILabel!
    @IBOutlet weak var durationValueLabel: UILabel!
    @IBOutlet weak var paceValueLabel: UILabel!
    /// A plain UIView placeholder. The map is added into it in code - see
    /// configureMap() for why it is not in the storyboard.
    @IBOutlet weak var mapContainerView: UIView!
    @IBOutlet weak var noteTextView: UITextView!
    @IBOutlet weak var saveNoteButton: UIButton!

    // MARK: - Properties

    /// Handed over by RunsListController in prepare(for:). Always set before
    /// the view loads.
    var run: Run!

    /// True when the user arrived by tapping the note button on the cell, in
    /// which case the keyboard should already be up.
    var shouldFocusNote = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        populate()
        configureMap()
        configureNoteEditing()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if shouldFocusNote {
            shouldFocusNote = false   // only on the first appearance
            noteTextView.becomeFirstResponder()
        }
    }

    // MARK: - UI Setup

    private func populate() {
        dateLabel.text = run.formattedDate
        distanceValueLabel.text = run.formattedDistance
        durationValueLabel.text = run.formattedDuration
        paceValueLabel.text = run.formattedPace
        noteTextView.text = run.note ?? ""
    }

    private func configureNoteEditing() {
        noteTextView.layer.cornerRadius = 8
        noteTextView.layer.borderWidth = 1
        // A resolved CGColor does not follow light/dark on its own - see
        // traitCollectionDidChange below.
        noteTextView.layer.borderColor = UIColor.separator.cgColor

        let tapToDismiss = UITapGestureRecognizer(target: self,
                                                  action: #selector(dismissKeyboard))
        tapToDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(tapToDismiss)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    /// UIColor is dynamic, but the CGColor pulled out of it is a fixed value
    /// resolved at the moment it was read. Switching to dark mode has to
    /// re-resolve it, or the border keeps its old colour.
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            noteTextView.layer.borderColor = UIColor.separator.cgColor
        }
    }

    // MARK: - Map

    /// The map is built here rather than dropped into the storyboard on purpose.
    /// An MKMapView in a storyboard makes the whole file depend on Interface
    /// Builder's MapKit plug-in, and this screen's map is a bonus - it should
    /// not be able to take the other two screens down with it.
    ///
    /// The container lives in the storyboard's vertical stack view, so hiding it
    /// collapses the space it occupied instead of leaving a gap.
    private func configureMap() {
        guard hasRecordedCoordinates else {
            // No GPS fix was ever taken, so there is nothing truthful to show.
            mapContainerView.isHidden = true
            return
        }

        let mapView = MKMapView()
        mapView.isUserInteractionEnabled = false
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.layer.cornerRadius = 8
        mapView.clipsToBounds = true
        mapContainerView.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: mapContainerView.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: mapContainerView.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: mapContainerView.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: mapContainerView.trailingAnchor)
        ])

        let startPin = MKPointAnnotation()
        startPin.coordinate = CLLocationCoordinate2D(latitude: run.startLat,
                                                     longitude: run.startLng)
        startPin.title = "Start"

        let finishPin = MKPointAnnotation()
        finishPin.coordinate = CLLocationCoordinate2D(latitude: run.endLat,
                                                      longitude: run.endLng)
        finishPin.title = "Finish"

        mapView.addAnnotations([startPin, finishPin])
        // Frames it so both pins are visible, whatever the distance between them.
        mapView.showAnnotations([startPin, finishPin], animated: false)
    }

    /// (0, 0) is our stand-in for "never got a fix" - it is a real coordinate in
    /// the Atlantic, so showing it on a map would be a lie.
    private var hasRecordedCoordinates: Bool {
        return !(run.startLat == 0 && run.startLng == 0)
    }

    // MARK: - Actions

    @IBAction func saveNoteButtonTapped(_ sender: UIButton) {
        view.endEditing(true)

        let newNote = noteTextView.text.nilIfBlank
        saveNoteButton.isEnabled = false

        RunStore.shared.updateNote(newNote, forRunId: run.id) { [weak self] error in
            guard let self = self else { return }
            self.saveNoteButton.isEnabled = true

            if let error = error {
                self.showAlert(title: "Could not save note",
                               message: error.localizedDescription)
                return
            }

            self.run.note = newNote
            self.showToast(message: "Note saved")
            // The list updates itself - its snapshot listener sees the write.
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Keyboard

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        // Convert into this view's space, then measure how much of the scroll
        // view the keyboard is sitting on top of. Landscape leaves very little
        // room, so this is what keeps the note field reachable.
        let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrameInView.minY)

        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
}
