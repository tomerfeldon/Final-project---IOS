//
//  RunsListController.swift
//  RunTracker
//
//  Main screen: the history of every saved run, newest first.
//

import UIKit
import FirebaseFirestore

class RunsListController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyStateLabel: UILabel!

    // MARK: - Properties

    private var runs: [Run] = []
    private var runsListener: ListenerRegistration?

    /// Set just before performing the detail segue. Read back in prepare(for:).
    private var selectedRun: Run?
    private var shouldFocusNoteOnDetail = false

    /// Set just before segueing to the active run screen, and consumed there.
    private var sessionToResume: ActiveRunSession?
    private var hasCheckedForActiveRun = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        startListeningForRuns()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkForUnfinishedRun()
    }

    deinit {
        // A listener that outlives its controller keeps firing and keeps self
        // alive. Always hand it back.
        runsListener?.remove()
    }

    // MARK: - UI Setup

    private func setupTableView() {
        // Set in code rather than in the storyboard: fewer connections to get
        // wrong, and it is obvious here that this controller drives the table.
        tableView.dataSource = self
        tableView.delegate = self

        // Lets a cell grow when the user has larger text sizes turned on.
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90
        tableView.tableFooterView = UIView()

        // Stay quiet until the first snapshot arrives. Showing "No runs yet"
        // straight away would flash the wrong message at anyone who has runs.
        emptyStateLabel.isHidden = true
    }

    private func updateEmptyState() {
        let isEmpty = runs.isEmpty
        emptyStateLabel.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }

    // MARK: - Firestore

    private func startListeningForRuns() {
        runsListener = RunStore.shared.observeRuns { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let runs):
                self.runs = runs
                self.tableView.reloadData()
                self.updateEmptyState()

            case .failure(let error):
                self.showAlert(title: "Could not load runs",
                               message: error.localizedDescription)
            }
        }
    }

    // MARK: - Resuming an Unfinished Run

    /// The Realtime Database still holds a live session if the app died mid-run,
    /// or if the user simply backed out of the active run screen. Either way,
    /// this is where we offer it back.
    ///
    /// Checked once per arrival at this screen rather than on every appearance,
    /// so the alert cannot reappear behind itself. The flag is cleared whenever
    /// we leave for the active run screen - see prepare(for:).
    private func checkForUnfinishedRun() {
        guard !hasCheckedForActiveRun else { return }
        hasCheckedForActiveRun = true

        ActiveRunStore.shared.fetch { [weak self] session in
            guard let self = self, let session = session else { return }
            self.promptToResume(session)
        }
    }

    private func promptToResume(_ session: ActiveRunSession) {
        // Borrow Run's formatting so the numbers here read exactly like the
        // numbers everywhere else.
        let preview = Run(id: "",
                          date: session.startDate,
                          distanceMeters: session.distanceMeters,
                          durationSeconds: session.elapsedSeconds,
                          startLat: 0, startLng: 0, endLat: 0, endLng: 0,
                          note: nil)

        let alert = UIAlertController(
            title: "Unfinished run",
            message: "You left a run in progress: \(preview.formattedDuration) and \(preview.formattedDistance). Pick it back up?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
            ActiveRunStore.shared.clear()
        })
        alert.addAction(UIAlertAction(title: "Resume", style: .default) { [weak self] _ in
            self?.sessionToResume = session
            self?.performSegue(withIdentifier: "showActiveRun", sender: nil)
        })
        present(alert, animated: true)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showRunDetail",
           let detailController = segue.destination as? RunDetailController,
           let run = selectedRun {
            detailController.run = run
            detailController.shouldFocusNote = shouldFocusNoteOnDetail
        }

        if segue.identifier == "showActiveRun",
           let activeRunController = segue.destination as? ActiveRunController {
            activeRunController.sessionToResume = sessionToResume
            // Consume it: the "New Run" button fires this same segue, and it
            // must always start a fresh run.
            sessionToResume = nil

            // Look again when we come back. If the user backed out mid-run the
            // session is still live and should be offered again; if they saved
            // or discarded, the lookup finds nothing and stays quiet.
            hasCheckedForActiveRun = false
        }
    }

    private func showDetail(for run: Run, focusNote: Bool) {
        selectedRun = run
        shouldFocusNoteOnDetail = focusNote
        performSegue(withIdentifier: "showRunDetail", sender: nil)
    }
}

// MARK: - UITableViewDataSource

extension RunsListController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return runs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: RunCell.reuseIdentifier,
                                                       for: indexPath) as? RunCell else {
            return UITableViewCell()
        }

        cell.configure(with: runs[indexPath.row])
        cell.delegate = self
        return cell
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }

        let run = runs[indexPath.row]
        RunStore.shared.delete(runId: run.id) { [weak self] error in
            if let error = error {
                self?.showAlert(title: "Delete failed", message: error.localizedDescription)
            }
        }

        // The local array is deliberately left alone. The snapshot listener is
        // the single source of truth and will remove the row for us - mutating
        // both here would risk the table and Firestore drifting apart.
    }
}

// MARK: - UITableViewDelegate

extension RunsListController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showDetail(for: runs[indexPath.row], focusNote: false)
    }
}

// MARK: - RunCellDelegate

extension RunsListController: RunCellDelegate {

    func runCellDidTapNote(_ cell: RunCell) {
        // Ask the table which row this cell is showing right now, rather than
        // storing an index on the cell - reused cells make stored indexes lie.
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        showDetail(for: runs[indexPath.row], focusNote: true)
    }
}
