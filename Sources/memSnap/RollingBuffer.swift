import Foundation

// MARK: - RollingBuffer

/// A fixed-capacity FIFO buffer. When `capacity` is exceeded the oldest element
/// is evicted automatically. Matches the `beeMon` RollingBuffer pattern.
struct RollingBuffer<T> {
    private var buffer: [T] = []
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        buffer.reserveCapacity(capacity)
    }

    mutating func append(_ value: T) {
        buffer.append(value)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    var elements: [T] { buffer }
    var count: Int { buffer.count }
    var isEmpty: Bool { buffer.isEmpty }

    /// Returns the last `n` elements (or all if fewer exist).
    func last(_ n: Int) -> [T] {
        guard n > 0 else { return [] }
        return Array(buffer.suffix(n))
    }
}
