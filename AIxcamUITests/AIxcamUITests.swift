//
//  AIxcamUITests.swift
//  AIxcamUITests
//
//  Created by ray dior on 5/17/26.
//

import XCTest

/// Launch-time measurements. The behavioural UI tests live in
/// `OnboardingFlowUITests.swift`.
final class AIxcamUITests: XCTestCase {

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
