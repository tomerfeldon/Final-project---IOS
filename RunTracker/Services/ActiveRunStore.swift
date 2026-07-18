//
//  ActiveRunStore.swift
//  RunTracker
//
//  Everything that touches activeRun/ in the Realtime Database.
//
//  Why this is not in Firestore: this node is rewritten every single second
//  while a run is in progress and then thrown away. That is exactly the shape
//  the Realtime Database is built for - a small, hot, ephemeral value. Firestore
//  is the opposite: durable documents you query later. Each database is doing
//  the job it is good at.
//

import Foundation
import FirebaseDatabase

class ActiveRunStore {

    // MARK: - Properties

    static let shared = ActiveRunStore()

    /// Computed so Database.database() is never called before
    /// FirebaseApp.configure() has run.
    private var reference: DatabaseReference {
        return Database.database().reference(withPath: "activeRun")
    }

    // MARK: - Init

    private init() {}

    // MARK: - Writing

    /// Overwrites the whole node with the current state of the run.
    /// Called once per second, so failures are ignored on purpose: the next
    /// tick will try again a second later, and one dropped write does not
    /// matter to a value that is about to be replaced anyway.
    func write(_ session: ActiveRunSession) {
        reference.setValue(session.toDictionary())
    }

    /// Removes the live session. Called when a run is saved or abandoned.
    func clear() {
        reference.removeValue()
    }

    // MARK: - Reading

    /// Reads the session once, for the resume prompt on launch.
    /// Returns nil when there is no session, or when it is no longer active.
    func fetch(completion: @escaping (ActiveRunSession?) -> Void) {
        reference.observeSingleEvent(of: .value) { snapshot in
            guard let dictionary = snapshot.value as? [String: Any],
                  let session = ActiveRunSession(dictionary: dictionary),
                  session.isActive else {
                completion(nil)
                return
            }
            completion(session)
        } withCancel: { error in
            print("RunTracker: could not read active run - \(error.localizedDescription)")
            completion(nil)
        }
    }
}
