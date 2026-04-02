import Foundation

/// Fixed-capacity ring buffer that drops oldest elements when full.
struct RingBuffer<T>: Sendable where T: Sendable {
    private var storage: [T] = []
    let capacity: Int

    init(capacity: Int = 50) {
        self.capacity = capacity
    }

    mutating func append(_ element: T) {
        storage.append(element)
        if storage.count > capacity {
            storage.removeFirst()
        }
    }

    var elements: [T] { storage }
    var count: Int { storage.count }
    var last: T? { storage.last }
    var isEmpty: Bool { storage.isEmpty }
}
