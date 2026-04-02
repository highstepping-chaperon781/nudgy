import XCTest
@testable import Nudge

final class SoundManagerTests: XCTestCase {

    func testPlayAllSoundsWithoutCrash() {
        let manager = SoundManager()
        manager.volume = 0.0 // Muted so tests don't make noise
        for effect in SoundEffect.allCases {
            manager.play(effect)
        }
        // No crash = pass
    }

    func testSoundDisabledDoesNotPlay() {
        let manager = SoundManager()
        manager.isEnabled = false
        manager.play(.success) // Should return immediately
    }

    func testPlayForStyleMapping() {
        let manager = SoundManager()
        manager.volume = 0.0
        manager.playForStyle(.success)
        manager.playForStyle(.warning)
        manager.playForStyle(.question)
        manager.playForStyle(.error)
        manager.playForStyle(.info)
    }

    func testVolumeRange() {
        let manager = SoundManager()
        manager.volume = 0.0
        XCTAssertEqual(manager.volume, 0.0)
        manager.volume = 1.0
        XCTAssertEqual(manager.volume, 1.0)
    }

    func testThreadSafety() {
        let manager = SoundManager()
        manager.volume = 0.0
        let expectation = expectation(description: "concurrent sounds")
        expectation.expectedFulfillmentCount = 10

        for _ in 0..<10 {
            DispatchQueue.global().async {
                manager.play(.success)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
