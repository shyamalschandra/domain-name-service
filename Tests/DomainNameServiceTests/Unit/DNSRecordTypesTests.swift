import XCTest
@testable import DomainNameService

final class DNSRecordTypesTests: XCTestCase {
    
    // MARK: - A Record Tests
    
    func testARecordCreation() {
        let address = IPv4Address("192.168.1.1")
        let aRecord = ARecord(address: address)
        
        XCTAssertEqual(aRecord.address.stringValue, "192.168.1.1")
        XCTAssertEqual(aRecord.rdata, Data([192, 168, 1, 1]))
    }
    
    func testARecordFromData() {
        let data = Data([192, 168, 1, 1])
        let aRecord = ARecord(data: data)
        
        XCTAssertNotNil(aRecord)
        XCTAssertEqual(aRecord?.address.stringValue, "192.168.1.1")
    }
    
    func testARecordInvalidData() {
        let invalidData = Data([192, 168, 1]) // Too short
        let aRecord = ARecord(data: invalidData)
        
        XCTAssertNil(aRecord)
    }
    
    // MARK: - AAAA Record Tests
    
    func testAAAARecordCreation() {
        let address = IPv6Address("2001:db8::1")
        let aaaaRecord = AAAARecord(address: address)
        
        XCTAssertEqual(aaaaRecord.address.stringValue, "2001:db8::1")
    }
    
    func testAAAARecordFromData() {
        var data = Data(repeating: 0, count: 16)
        data[0] = 0x20
        data[1] = 0x01
        data[2] = 0x0d
        data[3] = 0xb8
        
        let aaaaRecord = AAAARecord(data: data)
        
        XCTAssertNotNil(aaaaRecord)
    }
    
    func testAAAARecordInvalidData() {
        let invalidData = Data(repeating: 0, count: 15) // Too short
        let aaaaRecord = AAAARecord(data: invalidData)
        
        XCTAssertNil(aaaaRecord)
    }
    
    // MARK: - CNAME Record Tests
    
    func testCNAMERecordCreation() {
        let cnameRecord = CNAMERecord(canonicalName: "www.example.com")
        
        XCTAssertEqual(cnameRecord.canonicalName, "www.example.com")
    }
    
    func testCNAMERecordFromData() {
        let data = "www.example.com".data(using: .utf8) ?? Data()
        let cnameRecord = CNAMERecord(data: data)
        
        XCTAssertNotNil(cnameRecord)
        XCTAssertEqual(cnameRecord?.canonicalName, "www.example.com")
    }
    
    // MARK: - MX Record Tests
    
    func testMXRecordCreation() {
        let mxRecord = MXRecord(preference: 10, exchange: "mail.example.com")
        
        XCTAssertEqual(mxRecord.preference, 10)
        XCTAssertEqual(mxRecord.exchange, "mail.example.com")
    }
    
    func testMXRecordFromData() {
        var data = Data()
        data.append(UInt8(0)) // Preference high byte
        data.append(UInt8(10)) // Preference low byte
        data.append("mail.example.com".data(using: .utf8) ?? Data())
        
        let mxRecord = MXRecord(data: data)
        
        XCTAssertNotNil(mxRecord)
        XCTAssertEqual(mxRecord?.preference, 10)
        XCTAssertEqual(mxRecord?.exchange, "mail.example.com")
    }
    
    func testMXRecordSerialization() {
        let mxRecord = MXRecord(preference: 10, exchange: "mail.example.com")
        let data = mxRecord.rdata
        
        XCTAssertGreaterThanOrEqual(data.count, 2) // At least preference + exchange
        XCTAssertEqual(data[0], 0) // Preference high byte
        XCTAssertEqual(data[1], 10) // Preference low byte
    }
    
    // MARK: - NS Record Tests
    
    func testNSRecordCreation() {
        let nsRecord = NSRecord(nameServer: "ns1.example.com")
        
        XCTAssertEqual(nsRecord.nameServer, "ns1.example.com")
    }
    
    func testNSRecordFromData() {
        let data = "ns1.example.com".data(using: .utf8) ?? Data()
        let nsRecord = NSRecord(data: data)
        
        XCTAssertNotNil(nsRecord)
        XCTAssertEqual(nsRecord?.nameServer, "ns1.example.com")
    }
    
    // MARK: - PTR Record Tests
    
    func testPTRRecordCreation() {
        let ptrRecord = PTRRecord(pointer: "www.example.com")
        
        XCTAssertEqual(ptrRecord.pointer, "www.example.com")
    }
    
    func testPTRRecordFromData() {
        let data = "www.example.com".data(using: .utf8) ?? Data()
        let ptrRecord = PTRRecord(data: data)
        
        XCTAssertNotNil(ptrRecord)
        XCTAssertEqual(ptrRecord?.pointer, "www.example.com")
    }
    
    // MARK: - SOA Record Tests
    
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
        XCTAssertEqual(soaRecord.refresh, 3600)
        XCTAssertEqual(soaRecord.retry, 1800)
        XCTAssertEqual(soaRecord.expire, 604800)
        XCTAssertEqual(soaRecord.minimum, 3600)
    }
    
    func testSOARecordSerialization() {
        let soaRecord = SOARecord(
            mname: "ns1.example.com",
            rname: "admin.example.com",
            serial: 2023120101,
            refresh: 3600,
            retry: 1800,
            expire: 604800,
            minimum: 3600
        )
        
        let data = soaRecord.rdata
        XCTAssertGreaterThan(data.count, 20) // Should have mname + rname + numeric fields
    }
    
    // MARK: - TXT Record Tests
    
    func testTXTRecordCreation() {
        let txtRecord = TXTRecord(strings: ["v=spf1", "include:_spf.google.com", "~all"])
        
        XCTAssertEqual(txtRecord.strings.count, 3)
        XCTAssertEqual(txtRecord.strings[0], "v=spf1")
        XCTAssertEqual(txtRecord.strings[1], "include:_spf.google.com")
        XCTAssertEqual(txtRecord.strings[2], "~all")
    }
    
    func testTXTRecordFromData() {
        var data = Data()
        data.append(UInt8(6)) // Length of "v=spf1"
        data.append("v=spf1".data(using: .utf8) ?? Data())
        data.append(UInt8(4)) // Length of "~all"
        data.append("~all".data(using: .utf8) ?? Data())
        
        let txtRecord = TXTRecord(data: data)
        
        XCTAssertNotNil(txtRecord)
        XCTAssertEqual(txtRecord?.strings.count, 2)
        XCTAssertEqual(txtRecord?.strings[0], "v=spf1")
        XCTAssertEqual(txtRecord?.strings[1], "~all")
    }
    
    func testTXTRecordSerialization() {
        let txtRecord = TXTRecord(strings: ["v=spf1", "~all"])
        let data = txtRecord.rdata
        
        XCTAssertGreaterThanOrEqual(data.count, 2) // At least two strings
    }
    
    // MARK: - HINFO Record Tests
    
    func testHINFORecordCreation() {
        let hinfoRecord = HINFORecord(cpu: "x86-64", os: "Linux")
        
        XCTAssertEqual(hinfoRecord.cpu, "x86-64")
        XCTAssertEqual(hinfoRecord.os, "Linux")
    }
    
    func testHINFORecordFromData() {
        var data = Data()
        data.append(UInt8(6)) // Length of "x86-64"
        data.append("x86-64".data(using: .utf8) ?? Data())
        data.append(UInt8(5)) // Length of "Linux"
        data.append("Linux".data(using: .utf8) ?? Data())
        
        let hinfoRecord = HINFORecord(data: data)
        
        XCTAssertNotNil(hinfoRecord)
        XCTAssertEqual(hinfoRecord?.cpu, "x86-64")
        XCTAssertEqual(hinfoRecord?.os, "Linux")
    }
    
    // MARK: - WKS Record Tests
    
    func testWKSRecordCreation() {
        let address = IPv4Address("192.168.1.1")
        let bitMap = Data([0xFF, 0xFF, 0xFF, 0xFF])
        let wksRecord = WKSRecord(address: address, protocolNumber: 6, bitMap: bitMap)
        
        XCTAssertEqual(wksRecord.address.stringValue, "192.168.1.1")
        XCTAssertEqual(wksRecord.protocolNumber, 6)
        XCTAssertEqual(wksRecord.bitMap, bitMap)
    }
    
    func testWKSRecordFromData() {
        var data = Data()
        data.append(contentsOf: [192, 168, 1, 1]) // Address
        data.append(6) // Protocol (TCP)
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF]) // Bit map
        
        let wksRecord = WKSRecord(data: data)
        
        XCTAssertNotNil(wksRecord)
        XCTAssertEqual(wksRecord?.address.stringValue, "192.168.1.1")
        XCTAssertEqual(wksRecord?.protocolNumber, 6)
    }
    
    // MARK: - IPv4Address Tests
    
    func testIPv4AddressCreation() {
        let address = IPv4Address("192.168.1.1")
        
        XCTAssertEqual(address.stringValue, "192.168.1.1")
        XCTAssertEqual(address.data, Data([192, 168, 1, 1]))
    }
    
    func testIPv4AddressFromData() {
        let data = Data([192, 168, 1, 1])
        let address = IPv4Address(data)
        
        XCTAssertEqual(address.stringValue, "192.168.1.1")
        XCTAssertEqual(address.data, data)
    }
    
    // MARK: - IPv6Address Tests
    
    func testIPv6AddressCreation() {
        let address = IPv6Address("2001:db8::1")
        
        XCTAssertEqual(address.stringValue, "2001:db8::1")
        XCTAssertEqual(address.data.count, 16)
    }
    
    func testIPv6AddressFromData() {
        let data = Data(repeating: 0, count: 16)
        let address = IPv6Address(data)
        
        XCTAssertEqual(address.stringValue, "::")
        XCTAssertEqual(address.data.count, 16)
    }
}
