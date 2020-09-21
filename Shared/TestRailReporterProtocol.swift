import Foundation

import QuizTrain

public protocol TestRailReporterProtocol: class {
    var objectAPI: ObjectAPI! { set get }
    var project: QuizTrainProject! { set get }
    var completed: [NewCaseResults.Result] { set get }
    func submitResultsToTestRail(includingAllCases: Bool, closingPlanAfterSubmittingResults closePlan: Bool)
    
    func testBundleDidFinish(_ testBundle: Bundle)
}

extension TestRailReporterProtocol {
    var assignedto: User {
        project.users.first(where: { $0.email == objectAPI.api.username })! // All results are assigned to the API user account.
    }

    // MARK: Results Parsing

    /*
     Returns a tuple splitting |results| into two arrays. Array 0 contains
     NewCaseResults.Result's whose caseIds appear in the project, and array 1
     contains those whose caseIds do not appear in the project.

     This is useful to identify results which were created with invalid/stale
     caseIds.
     */
    func splitResults(_ results: [NewCaseResults.Result], _ project: QuizTrainProject) -> ([NewCaseResults.Result], [NewCaseResults.Result]) {
        var validResults = [NewCaseResults.Result]()
        var invalidResults = [NewCaseResults.Result]()

        for result in results {
            if project.cases.filter({ $0.id == result.caseId }).first != nil {
                validResults.append(result)
            } else {
                invalidResults.append(result)
            }
        }

        return (validResults, invalidResults)
    }

    func submitResultsToTestRail(includingAllCases: Bool = false, closingPlanAfterSubmittingResults closePlan: Bool = true) {
        submitResultsToTestRail(includingAllCases: includingAllCases, closingPlanAfterSubmittingResults: closePlan)
    }
}
