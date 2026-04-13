import Foundation

/// Represents async loading state for any piece of data.
enum Loadable<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)

    var value: T? {
        if case .success(let v) = self { return v }
        return nil
    }

    var error: Error? {
        if case .failure(let e) = self { return e }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
