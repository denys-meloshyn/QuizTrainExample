import QuizTrain
import XCTest

public final class TestRailManager: NSObject {

    let objectAPI: ObjectAPI
    let project: QuizTrainProject
    let testRailReporter: TestRailReporterProtocol

    var submitResults = true
    var closePlanAfterSubmittingResults = true
    var includeAllCasesInPlan = false

    init(objectAPI: ObjectAPI, project: QuizTrainProject, testRailReporter: TestRailReporterProtocol) {
        self.objectAPI = objectAPI
        self.project = project
        self.testRailReporter = testRailReporter
        super.init()
    }

    // MARK: - Testing

    public enum Result: String {
        case passed
        case blocked
        case untested
        case retest
        case failed
    }

    private func status(_ result: Result) -> Status {
        return project.statuses.first(where: { $0.name == result.rawValue })!
    }

    private var assignedto: User {
        return project.users.first(where: { $0.email == objectAPI.api.username })! // All results are assigned to the API user account.
    }

    private func newResult(for caseId: Case.Id) -> NewCaseResults.Result {
        let untestedStatus = status(.untested)
        return NewCaseResults.Result(assignedtoId: assignedto.id, caseId: caseId, statusId: untestedStatus.id)
    }

    private var started = [NewCaseResults.Result]()
    private var completed = [NewCaseResults.Result]()

    /*
     Starts testing one or more caseIds. This adds a new NewCaseResults.Result
     to the |started| queue for each caseId with its result in an untested
     state. If any failures occur before a caseId is completed it will record
     those failures and be marked failed.

     For every caseId each startTesting call must be balanced with a
     completeTesting call. This can be done explicitly by you or implicitly by
     the XCTestObservation extension. See the extension for details.

     It is programmer error if you submit an identical caseId more than once to
     this queue.
     */
    func startTesting(_ caseIds: [Case.Id]) {
        for caseId in caseIds {
            guard started.filter({ $0.caseId == caseId }).count == 0 else {
                fatalError("You cannot start caseId \(caseId) because it has already been started.")
            }
            guard completed.filter({ $0.caseId == caseId }).count == 0 else {
                fatalError("You cannot start caseId \(caseId) because it has already been completed.")
            }
            started.append(newResult(for: caseId))
        }
    }

    func startTesting(_ caseIds: Case.Id...) {
        startTesting(caseIds)
    }

    fileprivate struct Failure {
        let test: XCTest
        let description: String
        let filePath: String?
        let lineNumber: Int
        var comment: String { return "Failure: \(test.name):\(filePath ?? ""):\(lineNumber): \(description)" }
    }

    /*
     Marks all results in the started queue as .failed and appends the failure
     comment to them.
     */
    fileprivate func recordFailure(_ failure: Failure) {
        let failedStatus = status(.failed)
        for i in started.indices {
            started[i].statusId = failedStatus.id
            if started[i].comment != nil {
                started[i].comment! += "\n\(failure.comment)"
            } else {
                started[i].comment = failure.comment
            }
        }
    }

    /*
     Completes testing |caseIds|. This:

     1. Removes them from the |started| queue.
     2. Changes their status to |result| if they are still .untested.
         - If they are not .untested their status is left unchanged.
     3. Appends the |comment|.
     4. Adds them to the |completed| queue.

     It is programmer error if you complete a caseId which is not currently
     started.
     */
    public func completeTesting(_ caseIds: [Case.Id], withResultIfUntested result: Result = .passed, comment: String? = nil) {

        // Remove from started queue.
        var completed = [NewCaseResults.Result]()
        for caseId in caseIds {
            guard let complete = started.filter({ $0.caseId == caseId }).first,
                let index = started.firstIndex(of: complete) else {
                    fatalError("You cannot complete caseId \(caseId) because it has not been started.")
            }
            completed.append(complete)
            started.remove(at: index)
        }

        let status = self.status(result)
        let untestedStatus = self.status(.untested)

        for i in completed.indices {

            // Only set the status if untested.
            if completed[i].statusId == untestedStatus.id {
                completed[i].statusId = status.id
            }

            // Append comment.
            if let comment = comment {
                if completed[i].comment != nil {
                    completed[i].comment! += "\n\(comment)"
                } else {
                    completed[i].comment = comment
                }
            }
        }

        self.completed.append(contentsOf: completed)
    }

    public func completeTesting(_ caseIds: Case.Id..., withResultIfUntested result: Result = .passed, comment: String? = nil) {
        completeTesting(caseIds, withResultIfUntested: result, comment: comment)
    }

    fileprivate func completeAllTests() {
        let casesIds = started.compactMap { $0.caseId }
        completeTesting(casesIds)
    }

}

// MARK: - XCTestObservation

extension TestRailManager: XCTestObservation {

    public func testBundleWillStart(_ testBundle: Bundle) {
        completeAllTests()
    }

    public func testSuiteWillStart(_ testSuite: XCTestSuite) {
        completeAllTests()
    }

    public func testCaseWillStart(_ testCase: XCTestCase) {
        completeAllTests()
    }

    public func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
        recordFailure(Failure(test: testCase, description: description, filePath: filePath, lineNumber: lineNumber))
    }

    public func testCaseDidFinish(_ testCase: XCTestCase) {
        completeAllTests()
    }

    public func testSuite(_ testSuite: XCTestSuite, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
        recordFailure(Failure(test: testSuite, description: description, filePath: filePath, lineNumber: lineNumber))
    }

    public func testSuiteDidFinish(_ testSuite: XCTestSuite) {
        completeAllTests()
    }
    public func testBundleDidFinish(_ testBundle: Bundle) {
        completeAllTests()

        print("\n========== QuizTrainManager ==========\n")
        if submitResults {
            testRailReporter.submitResultsToTestRail(includingAllCases: includeAllCasesInPlan, closingPlanAfterSubmittingResults: closePlanAfterSubmittingResults) // blocking
        } else {
            print("Submitting results is disabled.")
        }
        print("\n======================================\n")
    }

}
