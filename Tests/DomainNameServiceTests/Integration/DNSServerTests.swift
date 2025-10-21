import XCTest
@testable import DomainNameService

final class DNSServerTests: XCTestCase {
    
    var server: DNSServer!
    var zoneManager: DNSZoneManager!
    
    override func setUp() async throws {
        zoneManager = DNSZoneManager()
        
        // Create a test zone
        let soa = SOARecord(
            mname: "ns1.test.com",
            rname: "admin.test.com",
            serial: 2023120101,
            refresh: 3600,
            retry: 1800,
            expire: 604800,
            minimum: 3600
        )
        
        let zone = DNSZoneBuilder()
            .createZone(name: "test.com", soa: soa)
            .addARecord(name: "test.com", address: "192.168.1.1")
            .addARecord(name: "www.test.com", address: "192.168.1.2")
            .addAAAARecord(name: "test.com", address: "2001:db8::1")
            .addCNAMERecord(name: "alias.test.com", canonicalName: "www.test.com")
            .addMXRecord(name: "test.com", preference: 10, exchange: "mail.test.com")
            .addNSRecord(name: "test.com", nameServer: "ns1.test.com")
            .addTXTRecord(name: "test.com", strings: ["v=spf1", "include:_spf.test.com", "~all"])
            .build()
        
        guard let zone = zone else {
            XCTFail("Failed to create test zone")
            return
        }
        
        zoneManager.addZone(zone)
        
        server = try DNSServer(zoneManager: zoneManager)
    }
    
    override func tearDown() async throws {
        try await server?.stop()
        server = nil
        zoneManager = nil
    }
    
    func testZoneCreation() {
        let soa = SOARecord(
            mname: "ns1.example.com",
            rname: "admin.example.com",
            serial: 2023120101,
            refresh: 3600,
            retry: 1800,
            expire: 604800,
            minimum: 3600
        )
        
        let zone = DNSZone(name: "example.com", soa: soa)
        
        XCTAssertEqual(zone.name, "example.com")
        XCTAssertEqual(zone.soa.mname, "ns1.example.com")
        XCTAssertEqual(zone.soa.rname, "admin.example.com")
    }
    
    func testZoneBuilder() {
        let soa = SOARecord(
            mname: "ns1.example.com",
            rname: "admin.example.com",
            serial: 2023120101,
            refresh: 3600,
            retry: 1800,
            expire: 604800,
            minimum: 3600
        )
        
        let zone = DNSZoneBuilder()
            .createZone(name: "example.com", soa: soa)
            .addARecord(name: "example.com", address: "192.168.1.1")
            .addARecord(name: "www.example.com", address: "192.168.1.2")
            .addAAAARecord(name: "example.com", address: "2001:db8::1")
            .addCNAMERecord(name: "alias.example.com", canonicalName: "www.example.com")
            .addMXRecord(name: "example.com", preference: 10, exchange: "mail.example.com")
            .addNSRecord(name: "example.com", nameServer: "ns1.example.com")
            .addTXTRecord(name: "example.com", strings: ["v=spf1", "include:_spf.example.com", "~all"])
            .build()
        
        XCTAssertNotNil(zone)
        XCTAssertEqual(zone?.name, "example.com")
        
        let records = zone?.getAllRecords() ?? []
        XCTAssertGreaterThan(records.count, 0)
    }
    
    func testZoneLookup() {
        let soa = SOARecord(
            mname: "ns1.example.com",
            rname: "admin.example.com",
            serial: 2023120101,
            refresh: 3600,
            retry: 1800,
            expire: 604800,
            minimum: 3600
        )
        
        let zone = DNSZone(name: "example.com", soa: soa)
        
        // Add some records
        let aRecord = DNSResourceRecord(
            name: "example.com",
            type: .a,
            ttl: 3600,
            rdata: Data([192, 168, 1, 1])
        )
        zone.addRecord(aRecord)
        
        let mxRecord = DNSResourceRecord(
            name: "example.com",
            type: .mx,
            ttl: 3600,
            rdata: Data([0, 10]) + "mail.example.com".data(using: .utf8)!
        )
        zone.addRecord(mxRecord)
        
        // Test lookups
        let aRecords = zone.lookup(domain: "example.com", type: .a, class: .internet)
        XCTAssertEqual(aRecords.count, 1)
        XCTAssertEqual(aRecords.first?.type, .a)
        
        let mxRecords = zone.lookup(domain: "example.com", type: .mx, class: .internet)
        XCTAssertEqual(mxRecords.count, 1)
        XCTAssertEqual(mxRecords.first?.type, .mx)
        
        let nsRecords = zone.lookup(domain: "example.com", type: .ns, class: .internet)
        XCTAssertEqual(nsRecords.count, 0) // No NS records added
    }
    
    func testZoneManager() {
        let soa = SOARecord(
            mname: "ns1.example.com",
            rname: "admin.example.com",
            serial: 2023120101,
            refresh: 3600,
            retry: 1800,
            expire: 604800,
            minimum: 3600
        )
        
        let zone = DNSZone(name: "example.com", soa: soa)
        zoneManager.addZone(zone)
        
        // Test lookup
        let records = try! zoneManager.lookup(domain: "example.com", type: .a, class: .internet)
        XCTAssertNotNil(records)
        
        // Test removal
        zoneManager.removeZone("example.com")
        let recordsAfterRemoval = try! zoneManager.lookup(domain: "example.com", type: .a, class: .internet)
        XCTAssertEqual(recordsAfterRemoval.count, 0)
    }
    
    func testServerConfiguration() {
        let config = DNSServerConfig(
            port: 5353,
            host: "127.0.0.1",
            maxConnections: 100,
            timeout: 60.0
        )
        
        XCTAssertEqual(config.port, 5353)
        XCTAssertEqual(config.host, "127.0.0.1")
        XCTAssertEqual(config.maxConnections, 100)
        XCTAssertEqual(config.timeout, 60.0)
    }
    
    func testARecordLookup() {
        let records = try! zoneManager.lookup(domain: "test.com", type: .a, class: .internet)
        XCTAssertFalse(records.isEmpty)
        
        let aRecord = ARecord(data: records.first!.rdata)
        XCTAssertNotNil(aRecord)
        XCTAssertEqual(aRecord?.address.stringValue, "192.168.1.1")
    }
    
    func testAAAARecordLookup() {
        let records = try! zoneManager.lookup(domain: "test.com", type: .aaaa, class: .internet)
        XCTAssertFalse(records.isEmpty)
        
        let aaaaRecord = AAAARecord(data: records.first!.rdata)
        XCTAssertNotNil(aaaaRecord)
        XCTAssertEqual(aaaaRecord?.address.stringValue, "2001:db8::1")
    }
    
    func testCNAMERecordLookup() {
        let records = try! zoneManager.lookup(domain: "alias.test.com", type: .cname, class: .internet)
        XCTAssertFalse(records.isEmpty)
        
        let cnameRecord = CNAMERecord(data: records.first!.rdata)
        XCTAssertNotNil(cnameRecord)
        XCTAssertEqual(cnameRecord?.canonicalName, "www.test.com")
    }
    
    func testMXRecordLookup() {
        let records = try! zoneManager.lookup(domain: "test.com", type: .mx, class: .internet)
        XCTAssertFalse(records.isEmpty)
        
        let mxRecord = MXRecord(data: records.first!.rdata)
        XCTAssertNotNil(mxRecord)
        XCTAssertEqual(mxRecord?.preference, 10)
        XCTAssertEqual(mxRecord?.exchange, "mail.test.com")
    }
    
    func testNSRecordLookup() {
        let records = try! zoneManager.lookup(domain: "test.com", type: .ns, class: .internet)
        XCTAssertFalse(records.isEmpty)
        
        let nsRecord = NSRecord(data: records.first!.rdata)
        XCTAssertNotNil(nsRecord)
        XCTAssertEqual(nsRecord?.nameServer, "ns1.test.com")
    }
    
    func testTXTRecordLookup() {
        let records = try! zoneManager.lookup(domain: "test.com", type: .txt, class: .internet)
        XCTAssertFalse(records.isEmpty)
        
        let txtRecord = TXTRecord(data: records.first!.rdata)
        XCTAssertNotNil(txtRecord)
        XCTAssertEqual(txtRecord?.strings.count, 3)
        XCTAssertEqual(txtRecord?.strings[0], "v=spf1")
        XCTAssertEqual(txtRecord?.strings[1], "include:_spf.test.com")
        XCTAssertEqual(txtRecord?.strings[2], "~all")
    }
    
    func testNonExistentDomain() {
        let records = try! zoneManager.lookup(domain: "nonexistent.test.com", type: .a, class: .internet)
        XCTAssertTrue(records.isEmpty)
    }
    
    func testNonExistentRecordType() {
        let records = try! zoneManager.lookup(domain: "test.com", type: .ptr, class: .internet)
        XCTAssertTrue(records.isEmpty)
    }
    
    func testMultipleRecords() {
        // Add multiple A records for the same domain
        let zone = zoneManager.zones["test.com"]!
        let additionalRecord = DNSResourceRecord(
            name: "test.com",
            type: .a,
            ttl: 3600,
            rdata: Data([192, 168, 1, 3])
        )
        zone.addRecord(additionalRecord)
        
        let records = try! zoneManager.lookup(domain: "test.com", type: .a, class: .internet)
        XCTAssertEqual(records.count, 2)
    }
}
