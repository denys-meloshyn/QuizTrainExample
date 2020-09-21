import Foundation
import QuizTrain
import XCTest

/*
 Principal Class for test targets owned by their Bundle. This should be accessed
 using its singleton property: TestManager.sharedInstance

 Performs logic required before any tests run and after all tests complete.
 */
public final class TestManager: NSObject {

    public let quizTrainManager: TestRailManager

    /*
     username: "YOUR@TESTRAIL.EMAIL"
     secret: "YOUR_TESTRAIL_PASSWORD_OR_API_KEY"
     hostname: "YOURINSTANCE.testrail.net"
     */
    public init(username: String, secret: String, hostname: String, projectId: Int, port: Int = 443, scheme: String = "https", testRailReporter: TestRailReporterProtocol) {
        print("\n========== TestManager ==========\n")
        defer { print("\n====================================\n") }

        print("QuizTrainManager setup started.")
        let objectAPI = QuizTrain.ObjectAPI(username: username, secret: secret, hostname: hostname, port: port, scheme: scheme)
        var quizTrainManager: TestRailManager!
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            QuizTrainProject.populatedProject(forProjectId: projectId, objectAPI: objectAPI) { (outcome) in
                switch outcome {
                case .failure(let error):
                    print("QuizTrainManager setup failed: \(error)")
                    fatalError(error.localizedDescription)
                case .success(let project):
                    testRailReporter.objectAPI = objectAPI
                    testRailReporter.project = project
                    quizTrainManager = TestRailManager(objectAPI: objectAPI, project: project, testRailReporter: testRailReporter)
                }
                group.leave()
            }
        }
        group.wait()
        self.quizTrainManager = quizTrainManager
        XCTestObservationCenter.shared.addTestObserver(self.quizTrainManager)
        print("QuizTrainManager setup completed.")

        super.init()

        TestManager._sharedInstance = self
    }

    deinit {
        XCTestObservationCenter.shared.removeTestObserver(self.quizTrainManager)
    }

    // MARK: - Singleton

    private static var _sharedInstance: TestManager!

    static public var sharedInstance: TestManager {
        return _sharedInstance
    }
    
    public func logTest(_ caseIds: [Case.Id], withCaseId: Bool = true, withProjectName: Bool = false, withSuiteName: Bool = true, withSectionNames: Bool = true) {
        let caseTitles = quizTrainManager.project.caseTitles(caseIds, withCaseId: withCaseId, withProjectName: withProjectName, withSuiteName: withSuiteName, withSectionNames: withSectionNames)
        for caseTitle in caseTitles {
            print(caseTitle)
        }
    }

    public func logTest(_ caseIds: Case.Id..., withCaseId: Bool = true, withProjectName: Bool = false, withSuiteName: Bool = true, withSectionNames: Bool = true) {
        logTest(caseIds, withCaseId: withCaseId, withProjectName: withProjectName, withSuiteName: withSuiteName, withSectionNames: withSectionNames)
    }

    public func logAndStartTesting(_ caseIds: [Case.Id]) {
        logTest(caseIds)
        startTesting(caseIds)
    }

    public func logAndStartTesting(_ caseIds: Case.Id...) {
        logTest(caseIds)
        startTesting(caseIds)
    }

    public func startTesting(_ caseIds: [Case.Id]) {
        quizTrainManager.startTesting(caseIds)
    }

    public func startTesting(_ caseIds: Case.Id...) {
        quizTrainManager.startTesting(caseIds)
    }

    public func completeTesting(_ caseIds: [Case.Id], withResultIfUntested result: TestRailManager.Result = .passed, comment: String? = nil) {
        quizTrainManager.completeTesting(caseIds, withResultIfUntested: result, comment: comment)
    }

    public func completeTesting(_ caseIds: Case.Id..., withResultIfUntested result: TestRailManager.Result = .passed, comment: String? = nil) {
        quizTrainManager.completeTesting(caseIds, withResultIfUntested: result, comment: comment)
    }
    
    @discardableResult public func runActivity<Result>(named name: String? = nil, testing caseId: Case.Id, block: (XCTActivity) throws -> Result) rethrows -> Result {
        return try runActivity(named: name, testing: [caseId], block: block)
    }

    @discardableResult public func runActivity<Result>(named name: String? = nil, testing caseIds: [Case.Id], block: (XCTActivity) throws -> Result) rethrows -> Result {

        let caseTitles = TestManager.sharedInstance.quizTrainManager.project.caseTitles(caseIds, withCaseId: true, withProjectName: false, withSuiteName: true, withSectionNames: true).joined(separator: " | ")

        let named: String
        if let name = name {
            named = name + ": " + caseTitles
        } else {
            named = caseTitles
        }

        startTesting(caseIds)
        let result = try XCTContext.runActivity(named: named, block: block)
        completeTesting(caseIds)

        return result
    }
}

// MARK: - Global

func logTest(_ caseIds: [Case.Id], withCaseId: Bool = true, withProjectName: Bool = false, withSuiteName: Bool = true, withSectionNames: Bool = true) {
    let caseTitles = TestManager.sharedInstance.quizTrainManager.project.caseTitles(caseIds, withCaseId: withCaseId, withProjectName: withProjectName, withSuiteName: withSuiteName, withSectionNames: withSectionNames)
    for caseTitle in caseTitles {
        print(caseTitle)
    }
}

func logTest(_ caseIds: Case.Id..., withCaseId: Bool = true, withProjectName: Bool = false, withSuiteName: Bool = true, withSectionNames: Bool = true) {
    logTest(caseIds, withCaseId: withCaseId, withProjectName: withProjectName, withSuiteName: withSuiteName, withSectionNames: withSectionNames)
}

func logAndStartTesting(_ caseIds: [Case.Id]) {
    logTest(caseIds)
    startTesting(caseIds)
}

func logAndStartTesting(_ caseIds: Case.Id...) {
    logTest(caseIds)
    startTesting(caseIds)
}

func startTesting(_ caseIds: [Case.Id]) {
    TestManager.sharedInstance.quizTrainManager.startTesting(caseIds)
}

func startTesting(_ caseIds: Case.Id...) {
    TestManager.sharedInstance.quizTrainManager.startTesting(caseIds)
}

func completeTesting(_ caseIds: [Case.Id], withResultIfUntested result: TestRailManager.Result = .passed, comment: String? = nil) {
    TestManager.sharedInstance.quizTrainManager.completeTesting(caseIds, withResultIfUntested: result, comment: comment)
}

func completeTesting(_ caseIds: Case.Id..., withResultIfUntested result: TestRailManager.Result = .passed, comment: String? = nil) {
    TestManager.sharedInstance.quizTrainManager.completeTesting(caseIds, withResultIfUntested: result, comment: comment)
}
