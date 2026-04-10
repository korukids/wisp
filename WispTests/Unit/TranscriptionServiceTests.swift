import XCTest
@testable import Wisp

final class TranscriptionServiceTests: XCTestCase {

    func testServiceCreation() {
        let service = TranscriptionService()
        XCTAssertNotNil(service)
    }

}
