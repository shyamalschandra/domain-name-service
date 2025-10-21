import XCTest
@testable import DomainNameService

final class DNSMessageCodecTests: XCTestCase {
    
    func testSerializeDeserializeRoundTrip() throws {
        let originalMessage = DNSMessage(
            header: DNSHeader(
                id: 12345,
                isResponse: true,
                opcode: .query,
                isAuthoritative: true,
                recursionDesired: true,
                recursionAvailable: true,
                responseCode: .noError,
                questionCount: 1,
                answerCount: 1
            ),
            questions: [
                DNSQuestion(name: "example.com", type: .a, class: .internet)
            ],
            answers: [
                DNSResourceRecord(
                    name: "example.com",
                    type: .a,
                    class: .internet,
                    ttl: 3600,
                    rdata: Data([192, 168, 1, 1])
                )
            ]
        )
        
        let codec = DNSMessageCodec()
        let serialized = try codec.serialize(originalMessage)
        let deserialized = try codec.deserialize(serialized)
        
        XCTAssertEqual(deserialized.header.id, originalMessage.header.id)
        XCTAssertEqual(deserialized.header.isResponse, originalMessage.header.isResponse)
        XCTAssertEqual(deserialized.header.opcode, originalMessage.header.opcode)
        XCTAssertEqual(deserialized.header.isAuthoritative, originalMessage.header.isAuthoritative)
        XCTAssertEqual(deserialized.header.recursionDesired, originalMessage.header.recursionDesired)
        XCTAssertEqual(deserialized.header.recursionAvailable, originalMessage.header.recursionAvailable)
        XCTAssertEqual(deserialized.header.responseCode, originalMessage.header.responseCode)
        XCTAssertEqual(deserialized.header.questionCount, originalMessage.header.questionCount)
        XCTAssertEqual(deserialized.header.answerCount, originalMessage.header.answerCount)
        
        XCTAssertEqual(deserialized.questions.count, originalMessage.questions.count)
        XCTAssertEqual(deserialized.questions.first?.name, originalMessage.questions.first?.name)
        XCTAssertEqual(deserialized.questions.first?.type, originalMessage.questions.first?.type)
        XCTAssertEqual(deserialized.questions.first?.class, originalMessage.questions.first?.class)
        
        XCTAssertEqual(deserialized.answers.count, originalMessage.answers.count)
        XCTAssertEqual(deserialized.answers.first?.name, originalMessage.answers.first?.name)
        XCTAssertEqual(deserialized.answers.first?.type, originalMessage.answers.first?.type)
        XCTAssertEqual(deserialized.answers.first?.class, originalMessage.answers.first?.class)
        XCTAssertEqual(deserialized.answers.first?.ttl, originalMessage.answers.first?.ttl)
        XCTAssertEqual(deserialized.answers.first?.rdata, originalMessage.answers.first?.rdata)
    }
    
    func testSerializeQuery() throws {
        let message = DNSMessage(
            header: DNSHeader(
                id: 12345,
                isResponse: false,
                opcode: .query,
                recursionDesired: true
            ),
            questions: [
                DNSQuestion(name: "example.com", type: .a)
            ]
        )
        
        let codec = DNSMessageCodec()
        let data = try codec.serialize(message)
        
        // Basic validation - should have at least 12 bytes for header
        XCTAssertGreaterThanOrEqual(data.count, 12)
        
        // Check that it's a valid DNS message
        let deserialized = try codec.deserialize(data)
        XCTAssertEqual(deserialized.header.id, 12345)
        XCTAssertFalse(deserialized.header.isResponse)
        XCTAssertEqual(deserialized.header.opcode, .query)
        XCTAssertTrue(deserialized.header.recursionDesired)
        XCTAssertEqual(deserialized.questions.count, 1)
        XCTAssertEqual(deserialized.questions.first?.name, "example.com")
        XCTAssertEqual(deserialized.questions.first?.type, .a)
    }
    
    func testSerializeResponse() throws {
        let message = DNSMessage(
            header: DNSHeader(
                id: 12345,
                isResponse: true,
                opcode: .query,
                isAuthoritative: true,
                recursionDesired: true,
                recursionAvailable: true,
                responseCode: .noError,
                questionCount: 1,
                answerCount: 1
            ),
            questions: [
                DNSQuestion(name: "example.com", type: .a)
            ],
            answers: [
                DNSResourceRecord(
                    name: "example.com",
                    type: .a,
                    ttl: 3600,
                    rdata: Data([192, 168, 1, 1])
                )
            ]
        )
        
        let codec = DNSMessageCodec()
        let data = try codec.serialize(message)
        
        // Basic validation
        XCTAssertGreaterThanOrEqual(data.count, 12)
        
        let deserialized = try codec.deserialize(data)
        XCTAssertEqual(deserialized.header.id, 12345)
        XCTAssertTrue(deserialized.header.isResponse)
        XCTAssertTrue(deserialized.header.isAuthoritative)
        XCTAssertTrue(deserialized.header.recursionAvailable)
        XCTAssertEqual(deserialized.header.responseCode, .noError)
        XCTAssertEqual(deserialized.header.questionCount, 1)
        XCTAssertEqual(deserialized.header.answerCount, 1)
    }
    
    func testSerializeMultipleQuestions() throws {
        let message = DNSMessage(
            header: DNSHeader(
                id: 12345,
                isResponse: false,
                opcode: .query,
                questionCount: 2
            ),
            questions: [
                DNSQuestion(name: "example.com", type: .a),
                DNSQuestion(name: "example.com", type: .mx)
            ]
        )
        
        let codec = DNSMessageCodec()
        let data = try codec.serialize(message)
        let deserialized = try codec.deserialize(data)
        
        XCTAssertEqual(deserialized.questions.count, 2)
        XCTAssertEqual(deserialized.questions[0].name, "example.com")
        XCTAssertEqual(deserialized.questions[0].type, .a)
        XCTAssertEqual(deserialized.questions[1].name, "example.com")
        XCTAssertEqual(deserialized.questions[1].type, .mx)
    }
    
    func testSerializeMultipleAnswers() throws {
        let message = DNSMessage(
            header: DNSHeader(
                id: 12345,
                isResponse: true,
                opcode: .query,
                isAuthoritative: true,
                questionCount: 1,
                answerCount: 2
            ),
            questions: [
                DNSQuestion(name: "example.com", type: .a)
            ],
            answers: [
                DNSResourceRecord(
                    name: "example.com",
                    type: .a,
                    ttl: 3600,
                    rdata: Data([192, 168, 1, 1])
                ),
                DNSResourceRecord(
                    name: "example.com",
                    type: .a,
                    ttl: 3600,
                    rdata: Data([192, 168, 1, 2])
                )
            ]
        )
        
        let codec = DNSMessageCodec()
        let data = try codec.serialize(message)
        let deserialized = try codec.deserialize(data)
        
        XCTAssertEqual(deserialized.answers.count, 2)
        XCTAssertEqual(deserialized.answers[0].rdata, Data([192, 168, 1, 1]))
        XCTAssertEqual(deserialized.answers[1].rdata, Data([192, 168, 1, 2]))
    }
    
    func testSerializeAuthorityRecords() throws {
        let message = DNSMessage(
            header: DNSHeader(
                id: 12345,
                isResponse: true,
                opcode: .query,
                isAuthoritative: true,
                questionCount: 1,
                authorityCount: 1
            ),
            questions: [
                DNSQuestion(name: "example.com", type: .a)
            ],
            authority: [
                DNSResourceRecord(
                    name: "example.com",
                    type: .ns,
                    ttl: 3600,
                    rdata: "ns1.example.com".data(using: .utf8) ?? Data()
                )
            ]
        )
        
        let codec = DNSMessageCodec()
        let data = try codec.serialize(message)
        let deserialized = try codec.deserialize(data)
        
        XCTAssertEqual(deserialized.authority.count, 1)
        XCTAssertEqual(deserialized.authority.first?.type, .ns)
    }
    
    func testSerializeAdditionalRecords() throws {
        let message = DNSMessage(
            header: DNSHeader(
                id: 12345,
                isResponse: true,
                opcode: .query,
                isAuthoritative: true,
                questionCount: 1,
                additionalCount: 1
            ),
            questions: [
                DNSQuestion(name: "example.com", type: .a)
            ],
            additional: [
                DNSResourceRecord(
                    name: "ns1.example.com",
                    type: .a,
                    ttl: 3600,
                    rdata: Data([192, 168, 1, 10])
                )
            ]
        )
        
        let codec = DNSMessageCodec()
        let data = try codec.serialize(message)
        let deserialized = try codec.deserialize(data)
        
        XCTAssertEqual(deserialized.additional.count, 1)
        XCTAssertEqual(deserialized.additional.first?.type, .a)
    }
    
    func testInvalidMessageFormat() {
        let codec = DNSMessageCodec()
        let invalidData = Data([1, 2, 3]) // Too short for a valid DNS message
        
        XCTAssertThrowsError(try codec.deserialize(invalidData)) { error in
            XCTAssertTrue(error is DNSError)
        }
    }
}
