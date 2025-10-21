import XCTest
@testable import DomainNameService

final class DNSMessageTests: XCTestCase {
    
    func testDNSHeaderCreation() {
        let header = DNSHeader(
            id: 12345,
            isResponse: true,
            opcode: .query,
            isAuthoritative: true,
            isTruncated: false,
            recursionDesired: true,
            recursionAvailable: true,
            responseCode: .noError,
            questionCount: 1,
            answerCount: 2,
            authorityCount: 0,
            additionalCount: 0
        )
        
        XCTAssertEqual(header.id, 12345)
        XCTAssertTrue(header.isResponse)
        XCTAssertEqual(header.opcode, .query)
        XCTAssertTrue(header.isAuthoritative)
        XCTAssertFalse(header.isTruncated)
        XCTAssertTrue(header.recursionDesired)
        XCTAssertTrue(header.recursionAvailable)
        XCTAssertEqual(header.responseCode, .noError)
        XCTAssertEqual(header.questionCount, 1)
        XCTAssertEqual(header.answerCount, 2)
    }
    
    func testDNSQuestionCreation() {
        let question = DNSQuestion(
            name: "example.com",
            type: .a,
            class: .internet
        )
        
        XCTAssertEqual(question.name, "example.com")
        XCTAssertEqual(question.type, .a)
        XCTAssertEqual(question.class, .internet)
    }
    
    func testDNSResourceRecordCreation() {
        let record = DNSResourceRecord(
            name: "example.com",
            type: .a,
            class: .internet,
            ttl: 3600,
            rdata: Data([192, 168, 1, 1])
        )
        
        XCTAssertEqual(record.name, "example.com")
        XCTAssertEqual(record.type, .a)
        XCTAssertEqual(record.class, .internet)
        XCTAssertEqual(record.ttl, 3600)
        XCTAssertEqual(record.rdLength, 4)
        XCTAssertEqual(record.rdata, Data([192, 168, 1, 1]))
    }
    
    func testDNSMessageCreation() {
        let header = DNSHeader(id: 12345)
        let question = DNSQuestion(name: "example.com", type: .a)
        let answer = DNSResourceRecord(
            name: "example.com",
            type: .a,
            ttl: 3600,
            rdata: Data([192, 168, 1, 1])
        )
        
        let message = DNSMessage(
            header: header,
            questions: [question],
            answers: [answer]
        )
        
        XCTAssertEqual(message.header.id, 12345)
        XCTAssertEqual(message.questions.count, 1)
        XCTAssertEqual(message.answers.count, 1)
        XCTAssertEqual(message.questions.first?.name, "example.com")
        XCTAssertEqual(message.answers.first?.name, "example.com")
    }
    
    func testDNSRecordTypes() {
        XCTAssertEqual(DNSRecordType.a.rawValue, 1)
        XCTAssertEqual(DNSRecordType.aaaa.rawValue, 28)
        XCTAssertEqual(DNSRecordType.cname.rawValue, 5)
        XCTAssertEqual(DNSRecordType.mx.rawValue, 15)
        XCTAssertEqual(DNSRecordType.ns.rawValue, 2)
        XCTAssertEqual(DNSRecordType.ptr.rawValue, 12)
        XCTAssertEqual(DNSRecordType.soa.rawValue, 6)
        XCTAssertEqual(DNSRecordType.txt.rawValue, 16)
    }
    
    func testDNSRecordClasses() {
        XCTAssertEqual(DNSRecordClass.internet.rawValue, 1)
        XCTAssertEqual(DNSRecordClass.chaos.rawValue, 3)
        XCTAssertEqual(DNSRecordClass.hesiod.rawValue, 4)
        XCTAssertEqual(DNSRecordClass.any.rawValue, 255)
    }
    
    func testDNSOpcode() {
        XCTAssertEqual(DNSOpcode.query.rawValue, 0)
        XCTAssertEqual(DNSOpcode.inverseQuery.rawValue, 1)
        XCTAssertEqual(DNSOpcode.status.rawValue, 2)
    }
    
    func testDNSResponseCode() {
        XCTAssertEqual(DNSResponseCode.noError.rawValue, 0)
        XCTAssertEqual(DNSResponseCode.formatError.rawValue, 1)
        XCTAssertEqual(DNSResponseCode.serverFailure.rawValue, 2)
        XCTAssertEqual(DNSResponseCode.nameError.rawValue, 3)
        XCTAssertEqual(DNSResponseCode.notImplemented.rawValue, 4)
        XCTAssertEqual(DNSResponseCode.refused.rawValue, 5)
    }
}
