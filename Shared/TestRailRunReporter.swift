//
// Created by $USER_NAME on 16/09/2020.
//

import Foundation
import QuizTrain

public class TestRailRunReporter: TestRailReporterProtocol {
    public var objectAPI: ObjectAPI!
    public var project: QuizTrainProject!
    private let suiteID: Suite.Id
    var name: String
    public var completed = [NewCaseResults.Result]()
    
    public init(suiteID: Suite.Id, name: String) {
        self.name = name
        self.suiteID = suiteID
    }

    public func submitResultsToTestRail(includingAllCases: Bool, closingPlanAfterSubmittingResults closePlan: Bool) {
        // Filter valid/invalid results.
        let (validResults, invalidResults) = splitResults(completed, project)
        if invalidResults.isEmpty == false {
            print("--------------------------------------")
            print("WARNING: The following results are for invalid caseIds and will not be submitted to TestRail.")
            for result in invalidResults {
                let status: Status? = project[result.statusId!]
                print("\(result.caseId): \(status?.name ?? "") - \(result.comment ?? "")")
            }
            print("--------------------------------------")
        }
        let validCaseIds = validResults.map { $0.caseId }

        // Get Case's for all valid results.
        var cases = [Case]()
        for caseId in validCaseIds {
            guard let `case`: Case = project[caseId] else {
                fatalError("There is no Case for caseId \(caseId) in project: \(project)")
            }
            guard cases.contains(where: { $0.id == caseId }) == false else {
                continue // skip duplicates
            }
            cases.append(`case`)
        }

        // Create NewPlan.Entry's for every included Suite.
        var newPlanEntries = [NewPlan.Entry]()
        if includingAllCases {
            for suite in project.suites {
                newPlanEntries.append(NewPlan.Entry(includeAll: true, suiteId: suite.id))
            }
        } else {
            // Only include suite's for tested cases.
            var suites = [Suite]()
            for `case` in cases {
                guard let suiteId = `case`.suiteId else {
                    fatalError("Case does not have a suiteId: \(`case`)")
                }
                guard let suite: Suite = project[suiteId] else {
                    fatalError("There is no Suite for suiteId \(suiteId) in project: \(project)")
                }
                guard suites.contains(suite) == false else {
                    continue
                }
                suites.append(suite)
            }

            // For each suite only include the cases tested in that suite.
            for suite in suites {
                let casesInSuite = cases.filter { $0.suiteId == suite.id }
                let caseIdsInSuite = casesInSuite.map { $0.id }
                let newPlanEntry = NewPlan.Entry(assignedtoId: assignedto.id, caseIds: caseIdsInSuite, includeAll: false, suiteId: suite.id)
                newPlanEntries.append(newPlanEntry)
            }
        }

        let group = DispatchGroup()

        // Create a Plan.
        print("Plan creation started.")
        guard !validResults.isEmpty else {
            print("Plan creation skipped. There are no results to submit.")
            return
        }

        // Submit results.
        print("Submitting \(validResults.count) test results started.")
        var errors = [ObjectAPI.AddError]()
        var resultsRun = [Run]()

        let newRun = NewRun(assignedtoId: assignedto.id, caseIds: validCaseIds, description: nil, includeAll: nil, milestoneId: nil, name: name, suiteId: suiteID)
        var responseRun: Run?
        group.enter()
        objectAPI.addRun(newRun, to: project.project) { (outcome) in
            switch outcome {
            case .failure(let error):
                errors.append(error)
            case .success(let someResults):
                responseRun = someResults
                resultsRun.append(someResults)
            }
            group.leave()
        }
        group.wait()

        guard let run = responseRun else {
            return
        }

        validResults.forEach { result in
            group.enter()
            let newResult = NewResult(assignedtoId: result.assignedtoId,
                                      comment: result.comment,
                                      defects: result.defects,
                                      elapsed: result.elapsed,
                                      statusId: result.statusId,
                                      version: result.version,
                                      customFields: result.customFields)
            objectAPI.addResultForCase(newResult, toRunWithId: run.id, toCaseWithId: result.caseId) { outcome in
                switch outcome {
                case .failure(let error):
                    errors.append(error)
                case .success(let someResults):
                    print("\(someResults)")
                }
                group.leave()
            }

            group.wait()
        }

        guard errors.count == 0 else {
            print("Submitting test results failed with \(errors.count) error(s):")
            for error in errors {
                print(error.debugDescription)
            }
            return
        }

        print("Submitting \(resultsRun.count) test results completed.")

//        if closePlan {
//            print("Closing plan started.")
//            group.enter()
//            objectAPI.closePlan(plan) { (outcome) in
//                switch outcome {
//                case .failure(let error):
//                    print("Closing plan failed: \(error)")
//                case .success(_):
//                    break
//                }
//                group.leave()
//            }
//            group.wait()
//            print("Closing plan completed.")
//        }
    }
}
