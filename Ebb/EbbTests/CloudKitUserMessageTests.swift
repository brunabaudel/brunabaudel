import CloudKit
import Foundation
import Testing
@testable import Ebb

@Suite("CloudKit user-facing messages")
struct CloudKitUserMessageTests {
    @Test func partialFailureUsesFriendlyCopy() {
        let error = CKError(.partialFailure, userInfo: [:])
        let message = CloudKitUserMessage.backupFailure(from: error)
        #expect(message.contains("couldn't finish uploading"))
        #expect(!message.contains("CKErrorDomain"))
    }

    @Test func nsErrorPartialFailureCodeMapsToFriendlyCopy() {
        let error = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "The operation couldn't be completed. (CKErrorDomain error 2.)",
            ]
        )
        let message = CloudKitUserMessage.backupFailure(from: error)
        #expect(message.contains("couldn't finish uploading"))
        #expect(!message.contains("CKErrorDomain"))
    }

    @Test func networkUnavailableUsesFriendlyCopy() {
        let error = CKError(.networkUnavailable, userInfo: [:])
        let message = CloudKitUserMessage.backupFailure(from: error)
        #expect(message.contains("isn't reachable"))
    }

    @Test func rawCloudKitDomainStringFallsBackToDefault() {
        let error = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.internalError.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "The operation couldn't be completed. (CKErrorDomain error 2.)"]
        )
        let message = CloudKitUserMessage.backupFailure(from: error)
        #expect(message == CloudKitUserMessage.backupFailure(from: nil))
    }

    @Test func sanitizeStripsRawCloudKitCodes() {
        let sanitized = CloudKitUserMessage.sanitize(
            "The operation couldn't be completed. (CKErrorDomain error 2.)"
        )
        #expect(sanitized == CloudKitUserMessage.backupFailure(from: nil))
    }

    @Test func isPartialFailureDetectsNSErrorCode() {
        let error = NSError(domain: CKErrorDomain, code: CKError.Code.partialFailure.rawValue)
        #expect(CloudKitUserMessage.isPartialFailure(error))
    }

    @Test func nilErrorUsesDefaultMessage() {
        let message = CloudKitUserMessage.backupFailure(from: nil)
        #expect(message.contains("Stay on Wi‑Fi"))
    }
}
