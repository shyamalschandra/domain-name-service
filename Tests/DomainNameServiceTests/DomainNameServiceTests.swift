import XCTest
@testable import DomainNameService

final class DomainNameServiceTests: XCTestCase {
    
    func testDomainNameServiceCreation() {
        let resolver = DomainNameService.createResolver()
        XCTAssertNotNil(resolver)
    }
    
    func testDomainNameServiceServerCreation() throws {
        let server = try DomainNameService.createServer()
        XCTAssertNotNil(server)
    }
    
    func testDomainNameServiceZoneBuilder() {
        let builder = DomainNameService.createZoneBuilder()
        XCTAssertNotNil(builder)
    }
    
    func testDomainNameServiceTransportManager() {
        let manager = DomainNameService.createTransportManager()
        XCTAssertNotNil(manager)
    }
    
    func testQuickLookupA() async throws {
        let addresses = try await DomainNameService.lookupA("google.com")
        XCTAssertFalse(addresses.isEmpty)
        XCTAssertTrue(addresses.allSatisfy { !$0.isEmpty })
    }
    
    func testQuickLookupAAAA() async throws {
        let addresses = try await DomainNameService.lookupAAAA("google.com")
        XCTAssertFalse(addresses.isEmpty)
        XCTAssertTrue(addresses.allSatisfy { !$0.isEmpty })
    }
    
    func testQuickLookupMX() async throws {
        let records = try await DomainNameService.lookupMX("google.com")
        XCTAssertFalse(records.isEmpty)
        XCTAssertTrue(records.allSatisfy { !$0.exchange.isEmpty })
        XCTAssertTrue(records.allSatisfy { $0.preference > 0 })
    }
    
    func testQuickLookupCNAME() async throws {
        let records = try await DomainNameService.lookupCNAME("www.github.com")
        // This might be a CNAME or A record depending on the domain
        // Just verify we get some response
        XCTAssertNotNil(records)
    }
    
    func testQuickLookupTXT() async throws {
        let records = try await DomainNameService.lookupTXT("google.com")
        XCTAssertFalse(records.isEmpty)
        XCTAssertTrue(records.allSatisfy { !$0.isEmpty })
    }
    
    func testDNSErrorTypes() {
        let errors: [DNSError] = [
            .invalidMessageFormat,
            .invalidLabelLength,
            .compressionError,
            .unsupportedRecordType,
            .invalidDomainName
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
    
    func testDNSRecordTypeCases() {
        let recordTypes: [DNSRecordType] = [
            .a, .ns, .md, .mf, .cname, .soa, .mb, .mg, .mr, .null,
            .wks, .ptr, .hinfo, .minfo, .mx, .txt, .aaaa, .srv, .opt, .any
        ]
        
        for recordType in recordTypes {
            XCTAssertNotNil(recordType.rawValue)
        }
    }
    
    func testDNSRecordClassCases() {
        let recordClasses: [DNSRecordClass] = [
            .internet, .chaos, .hesiod, .any
        ]
        
        for recordClass in recordClasses {
            XCTAssertNotNil(recordClass.rawValue)
        }
    }
    
    func testDNSOpcodeCases() {
        let opcodes: [DNSOpcode] = [
            .query, .inverseQuery, .status
        ]
        
        for opcode in opcodes {
            XCTAssertNotNil(opcode.rawValue)
        }
    }
    
    func testDNSResponseCodeCases() {
        let responseCodes: [DNSResponseCode] = [
            .noError, .formatError, .serverFailure, .nameError,
            .notImplemented, .refused
        ]
        
        for responseCode in responseCodes {
            XCTAssertNotNil(responseCode.rawValue)
        }
    }
    
    func testIPv4AddressCreation() {
        let address = IPv4Address("192.168.1.1")
        XCTAssertEqual(address.stringValue, "192.168.1.1")
        XCTAssertEqual(address.data, Data([192, 168, 1, 1]))
    }
    
    func testIPv6AddressCreation() {
        let address = IPv6Address("2001:db8::1")
        XCTAssertEqual(address.stringValue, "2001:db8::1")
        XCTAssertEqual(address.data.count, 16)
    }
    
    func testARecordCreation() {
        let address = IPv4Address("192.168.1.1")
        let aRecord = ARecord(address: address)
        XCTAssertEqual(aRecord.address.stringValue, "192.168.1.1")
    }
    
    func testAAAARecordCreation() {
        let address = IPv6Address("2001:db8::1")
        let aaaaRecord = AAAARecord(address: address)
        XCTAssertEqual(aaaaRecord.address.stringValue, "2001:db8::1")
    }
    
    func testCNAMERecordCreation() {
        let cnameRecord = CNAMERecord(canonicalName: "www.example.com")
        XCTAssertEqual(cnameRecord.canonicalName, "www.example.com")
    }
    
    func testMXRecordCreation() {
        let mxRecord = MXRecord(preference: 10, exchange: "mail.example.com")
        XCTAssertEqual(mxRecord.preference, 10)
        XCTAssertEqual(mxRecord.exchange, "mail.example.com")
    }
    
    func testNSRecordCreation() {
        let nsRecord = NSRecord(nameServer: "ns1.example.com")
        XCTAssertEqual(nsRecord.nameServer, "ns1.example.com")
    }
    
    func testPTRRecordCreation() {
        let ptrRecord = PTRRecord(pointer: "www.example.com")
        XCTAssertEqual(ptrRecord.pointer, "www.example.com")
    }
    
    func testSOARecordCreation() {
        let soaRecord = SOARecord(
            mname: "ns1.example.com",
            rname: "admin.example.com",
            serial: 2023120101,
            refresh: 3600,
            retry: 1800,
            expire: 604800,
            minimum: 3600
        )
        
        XCTAssertEqual(soaRecord.mname, "ns1.example.com")
        XCTAssertEqual(soaRecord.rname, "admin.example.com")
        XCTAssertEqual(soaRecord.serial, 2023120101)
    }
    
    func testTXTRecordCreation() {
        let txtRecord = TXTRecord(strings: ["v=spf1", "include:_spf.example.com", "~all"])
        XCTAssertEqual(txtRecord.strings.count, 3)
        XCTAssertEqual(txtRecord.strings[0], "v=spf1")
    }
    
    func testHINFORecordCreation() {
        let hinfoRecord = HINFORecord(cpu: "x86-64", os: "Linux")
        XCTAssertEqual(hinfoRecord.cpu, "x86-64")
        XCTAssertEqual(hinfoRecord.os, "Linux")
    }
    
    func testWKSRecordCreation() {
        let address = IPv4Address("192.168.1.1")
        let bitMap = Data([0xFF, 0xFF, 0xFF, 0xFF])
        let wksRecord = WKSRecord(address: address, protocolNumber: 6, bitMap: bitMap)
        
        XCTAssertEqual(wksRecord.address.stringValue, "192.168.1.1")
        XCTAssertEqual(wksRecord.protocolNumber, 6)
        XCTAssertEqual(wksRecord.bitMap, bitMap)
    }
}
