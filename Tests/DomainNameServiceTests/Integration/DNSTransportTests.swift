import XCTest
@testable import DomainNameService
import NIOCore
import NIOPosix

final class DNSTransportTests: XCTestCase {
    
    var eventLoopGroup: EventLoopGroup!
    
    override func setUp() {
        super.setUp()
        eventLoopGroup = MultiThreadedEventLoopGroup.singleton
    }
    
    override func tearDown() {
        try? eventLoopGroup.syncShutdownGracefully()
        eventLoopGroup = nil
        super.tearDown()
    }
    
    func testUDPTransportCreation() async throws {
        let transport = try DNSUDPTransport(eventLoopGroup: eventLoopGroup)
        XCTAssertNotNil(transport)
        try await transport.close()
    }
    
    func testTCPTransportCreation() async throws {
        let transport = try DNSTCPTransport(eventLoopGroup: eventLoopGroup)
        XCTAssertNotNil(transport)
        try await transport.close()
    }
    
    func testTransportManagerCreation() {
        let manager = DNSTransportManager()
        XCTAssertNotNil(manager)
    }
    
    func testTransportConfig() {
        let config = DNSTransportConfig(
            timeout: 10.0,
            retryCount: 5,
            useTCP: true,
            useUDP: true
        )
        
        XCTAssertEqual(config.timeout, 10.0)
        XCTAssertEqual(config.retryCount, 5)
        XCTAssertTrue(config.useTCP)
        XCTAssertTrue(config.useUDP)
    }
    
    func testTransportFactory() async throws {
        let udpTransport = try DNSTransportFactory.createUDPTransport(eventLoopGroup: eventLoopGroup)
        XCTAssertNotNil(udpTransport)
        try await udpTransport.close()
        
        let tcpTransport = try DNSTransportFactory.createTCPTransport(eventLoopGroup: eventLoopGroup)
        XCTAssertNotNil(tcpTransport)
        try await tcpTransport.close()
    }
    
    func testTransportManagerWithConfig() {
        let config = DNSTransportConfig(
            timeout: 5.0,
            retryCount: 3,
            useTCP: true,
            useUDP: false
        )
        
        let manager = DNSTransportManager(config: config)
        XCTAssertNotNil(manager)
    }
    
    func testMessageSerialization() throws {
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
        
        XCTAssertGreaterThanOrEqual(data.count, 12) // At least header size
        XCTAssertFalse(data.isEmpty)
    }
    
    func testMessageDeserialization() throws {
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
        let deserialized = try codec.deserialize(data)
        
        XCTAssertEqual(deserialized.header.id, message.header.id)
        XCTAssertEqual(deserialized.header.isResponse, message.header.isResponse)
        XCTAssertEqual(deserialized.header.opcode, message.header.opcode)
        XCTAssertEqual(deserialized.header.recursionDesired, message.header.recursionDesired)
        XCTAssertEqual(deserialized.questions.count, message.questions.count)
        XCTAssertEqual(deserialized.questions.first?.name, message.questions.first?.name)
        XCTAssertEqual(deserialized.questions.first?.type, message.questions.first?.type)
    }
    
    func testInvalidMessageDeserialization() {
        let codec = DNSMessageCodec()
        let invalidData = Data([1, 2, 3]) // Too short
        
        XCTAssertThrowsError(try codec.deserialize(invalidData)) { error in
            XCTAssertTrue(error is DNSError)
        }
    }
    
    func testDomainNameSerialization() throws {
        let codec = DNSMessageCodec()
        var buffer = ByteBuffer()
        var compressionMap: [String: UInt16] = [:]
        
        try codec.serializeDomainName("example.com", into: &buffer, compressionMap: &compressionMap)
        
        let data = Data(buffer.readableBytesView)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testDomainNameDeserialization() throws {
        let codec = DNSMessageCodec()
        var buffer = ByteBuffer()
        var compressionMap: [String: UInt16] = [:]
        
        try codec.serializeDomainName("example.com", into: &buffer, compressionMap: &compressionMap)
        
        let domainName = try codec.deserializeDomainName(from: &buffer)
        XCTAssertEqual(domainName, "example.com")
    }
    
    func testCompressionMap() throws {
        let codec = DNSMessageCodec()
        var buffer = ByteBuffer()
        var compressionMap: [String: UInt16] = [:]
        
        // Serialize first domain
        try codec.serializeDomainName("example.com", into: &buffer, compressionMap: &compressionMap)
        
        // Serialize second domain (should use compression)
        try codec.serializeDomainName("www.example.com", into: &buffer, compressionMap: &compressionMap)
        
        XCTAssertFalse(compressionMap.isEmpty)
        XCTAssertTrue(compressionMap.keys.contains("example.com"))
    }
    
    func testRecordTypeSerialization() throws {
        let record = DNSResourceRecord(
            name: "example.com",
            type: .a,
            class: .internet,
            ttl: 3600,
            rdata: Data([192, 168, 1, 1])
        )
        
        let codec = DNSMessageCodec()
        var buffer = ByteBuffer()
        var compressionMap: [String: UInt16] = [:]
        
        try codec.serializeResourceRecord(record, into: &buffer, compressionMap: &compressionMap)
        
        let data = Data(buffer.readableBytesView)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testRecordTypeDeserialization() throws {
        let record = DNSResourceRecord(
            name: "example.com",
            type: .a,
            class: .internet,
            ttl: 3600,
            rdata: Data([192, 168, 1, 1])
        )
        
        let codec = DNSMessageCodec()
        var buffer = ByteBuffer()
        var compressionMap: [String: UInt16] = [:]
        
        try codec.serializeResourceRecord(record, into: &buffer, compressionMap: &compressionMap)
        
        let deserialized = try codec.deserializeResourceRecord(from: &buffer)
        XCTAssertEqual(deserialized.name, record.name)
        XCTAssertEqual(deserialized.type, record.type)
        XCTAssertEqual(deserialized.class, record.class)
        XCTAssertEqual(deserialized.ttl, record.ttl)
        XCTAssertEqual(deserialized.rdata, record.rdata)
    }
    
    func testHeaderSerialization() throws {
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
        
        let codec = DNSMessageCodec()
        var buffer = ByteBuffer()
        
        try codec.serializeHeader(header, into: &buffer)
        
        let data = Data(buffer.readableBytesView)
        XCTAssertEqual(data.count, 12) // DNS header is always 12 bytes
    }
    
    func testHeaderDeserialization() throws {
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
        
        let codec = DNSMessageCodec()
        var buffer = ByteBuffer()
        
        try codec.serializeHeader(header, into: &buffer)
        
        let deserialized = try codec.deserializeHeader(from: &buffer)
        XCTAssertEqual(deserialized.id, header.id)
        XCTAssertEqual(deserialized.isResponse, header.isResponse)
        XCTAssertEqual(deserialized.opcode, header.opcode)
        XCTAssertEqual(deserialized.isAuthoritative, header.isAuthoritative)
        XCTAssertEqual(deserialized.isTruncated, header.isTruncated)
        XCTAssertEqual(deserialized.recursionDesired, header.recursionDesired)
        XCTAssertEqual(deserialized.recursionAvailable, header.recursionAvailable)
        XCTAssertEqual(deserialized.responseCode, header.responseCode)
        XCTAssertEqual(deserialized.questionCount, header.questionCount)
        XCTAssertEqual(deserialized.answerCount, header.answerCount)
        XCTAssertEqual(deserialized.authorityCount, header.authorityCount)
        XCTAssertEqual(deserialized.additionalCount, header.additionalCount)
    }
    
    func testQuestionSerialization() throws {
        let question = DNSQuestion(name: "example.com", type: .a, class: .internet)
        
        let codec = DNSMessageCodec()
        var buffer = ByteBuffer()
        var compressionMap: [String: UInt16] = [:]
        
        try codec.serializeQuestion(question, into: &buffer, compressionMap: &compressionMap)
        
        let data = Data(buffer.readableBytesView)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testQuestionDeserialization() throws {
        let question = DNSQuestion(name: "example.com", type: .a, class: .internet)
        
        let codec = DNSMessageCodec()
        var buffer = ByteBuffer()
        var compressionMap: [String: UInt16] = [:]
        
        try codec.serializeQuestion(question, into: &buffer, compressionMap: &compressionMap)
        
        let deserialized = try codec.deserializeQuestion(from: &buffer)
        XCTAssertEqual(deserialized.name, question.name)
        XCTAssertEqual(deserialized.type, question.type)
        XCTAssertEqual(deserialized.class, question.class)
    }
}
