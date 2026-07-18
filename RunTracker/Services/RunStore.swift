//
//  RunStore.swift
//  RunTracker
//
//  Everything that touches the "runs" collection in Firestore.
//  This is the permanent history - one document per finished run.
//

import Foundation
import FirebaseFirestore

class RunStore {

    // MARK: - Properties

    static let shared = RunStore()

    /// Computed rather than stored, because Firestore.firestore() must not be
    /// called before FirebaseApp.configure(). Firestore caches the instance, so
    /// this is cheap to re-evaluate.
    private var collection: CollectionReference {
        return Firestore.firestore().collection("runs")
    }

    // MARK: - Init

    private init() {}

    // MARK: - Reading

    /// Listens to the whole run history, newest first, and calls back on every
    /// change. Returns the registration so the caller can stop listening -
    /// forgetting to remove it leaks the listener and keeps the controller alive.
    func observeRuns(onChange: @escaping (Result<[Run], Error>) -> Void) -> ListenerRegistration {
        return collection
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    onChange(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    onChange(.success([]))
                    return
                }

                // compactMap: a single malformed document is skipped rather than
                // taking the whole list down with it.
                let runs = documents.compactMap { document in
                    Run(id: document.documentID, dictionary: document.data())
                }
                onChange(.success(runs))
            }
    }

    // MARK: - Writing

    /// Adds a finished run. The run's `id` is ignored - Firestore assigns the
    /// document id, and that is what comes back through the listener.
    func add(_ run: Run, completion: @escaping (Error?) -> Void) {
        collection.addDocument(data: run.toDictionary()) { error in
            completion(error)
        }
    }

    func delete(runId: String, completion: @escaping (Error?) -> Void) {
        collection.document(runId).delete { error in
            completion(error)
        }
    }

    /// Updates only the note field, leaving the rest of the document alone.
    func updateNote(_ note: String?, forRunId runId: String, completion: @escaping (Error?) -> Void) {
        collection.document(runId).updateData(["note": note ?? ""]) { error in
            completion(error)
        }
    }
}
