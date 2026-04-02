import XCTest
@testable import Nudge

final class RingBufferTests: XCTestCase {

    func testAppendAndRetrieve() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        XCTAssertEqual(buffer.elements, [1, 2, 3])
        XCTAssertEqual(buffer.count, 3)
    }

    func testCapacityLimit() {
        var buffer = RingBuffer<Int>(capacity: 3)
        for i in 1...5 {
            buffer.append(i)
        }
        XCTAssertEqual(buffer.elements, [3, 4, 5])
        XCTAssertEqual(buffer.count, 3)
    }

    func testLast() {
        var buffer = RingBuffer<String>(capacity: 10)
        XCTAssertNil(buffer.last)
        buffer.append("hello")
        buffer.append("world")
        XCTAssertEqual(buffer.last, "world")
    }

    func testIsEmpty() {
        var buffer = RingBuffer<Int>(capacity: 5)
        XCTAssertTrue(buffer.isEmpty)
        buffer.append(1)
        XCTAssertFalse(buffer.isEmpty)
    }

    func testDefaultCapacity() {
        let buffer = RingBuffer<Int>()
        XCTAssertEqual(buffer.capacity, 50)
    }
}
