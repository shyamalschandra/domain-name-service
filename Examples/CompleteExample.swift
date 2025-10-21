import Foundation
import DomainNameService
import Logging

/// Complete example demonstrating all features of the DNS library
@main
struct CompleteExample {
    static func main() async {
        // Set up logging
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .info
            return handler
        }
        
        let logger = Logger(label: "dns.example")
        
        do {
            // Example 1: Basic DNS Resolution
            await basicResolutionExample()
            
            // Example 2: Advanced DNS Resolution with Custom Resolver
            await advancedResolutionExample()
            
            // Example 3: DNS Server Setup
            await dnsServerExample()
            
            // Example 4: DNS Message Creation and Serialization
            await dnsMessageExample()
            
            // Example 5: All DNS Record Types
            await dnsRecordTypesExample()
            
            logger.info("All examples completed successfully!")
            
        } catch {
            logger.error("Example failed: \(error)")
        }
    }
    
    // MARK: - Example 1: Basic DNS Resolution
    static func basicResolutionExample() async {
        print("\n=== Basic DNS Resolution ===")
        
        do {
            // Quick A record lookup
            let addresses = try await DomainNameService.lookupA("google.com")
            print("Google.com IPv4 addresses:")
            for address in addresses {
                print("  - \(address.stringValue)")
            }
            
            // Quick AAAA record lookup
            let ipv6Addresses = try await DomainNameService.lookupAAAA("google.com")
            print("Google.com IPv6 addresses:")
            for address in ipv6Addresses {
                print("  - \(address.stringValue)")
            }
            
            // Quick MX record lookup
            let mxRecords = try await DomainNameService.lookupMX("google.com")
            print("Google.com mail servers:")
            for record in mxRecords {
                print("  - \(record.exchange) (priority: \(record.preference))")
            }
            
        } catch {
            print("Basic resolution failed: \(error)")
        }
    }
    
    // MARK: - Example 2: Advanced DNS Resolution
    static func advancedResolutionExample() async {
        print("\n=== Advanced DNS Resolution ===")
        
        do {
            // Create a resolver with custom configuration
            let resolver = DomainNameService.createResolver()
            
            // Resolve different record types
            let domain = "github.com"
            
            // A records
            let aRecords = try await resolver.resolveA(domain)
            print("\(domain) A records:")
            for record in aRecords {
                print("  - \(record.address.stringValue)")
            }
            
            // AAAA records
            let aaaaRecords = try await resolver.resolveAAAA(domain)
            print("\(domain) AAAA records:")
            for record in aaaaRecords {
                print("  - \(record.address.stringValue)")
            }
            
            // MX records
            let mxRecords = try await resolver.resolveMX(domain)
            print("\(domain) MX records:")
            for record in mxRecords {
                print("  - \(record.exchange) (priority: \(record.preference))")
            }
            
            // TXT records
            let txtRecords = try await resolver.resolveTXT(domain)
            print("\(domain) TXT records:")
            for record in txtRecords {
                print("  - \(record.strings.joined(separator: " "))")
            }
            
            // Generic query
            let message = try await resolver.query(domain: domain, type: .a)
            print("Generic query response: \(message.header.responseCode)")
            
        } catch {
            print("Advanced resolution failed: \(error)")
        }
    }
    
    // MARK: - Example 3: DNS Server Setup
    static func dnsServerExample() async {
        print("\n=== DNS Server Setup ===")
        
        do {
            // Create a DNS server
            let server = try DomainNameService.createServer()
            
            // Create a zone using the builder
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
                .addMXRecord(name: "example.com", preference: 10, exchange: "mail.example.com")
                .addNSRecord(name: "example.com", nameServer: "ns1.example.com")
                .addTXTRecord(name: "example.com", strings: ["v=spf1", "include:_spf.example.com", "~all"])
                .build()
            
            // Add zone to server
            if let zone = zone {
                server.zoneManager.addZone(zone)
                print("Added zone: \(zone.name)")
                print("Zone records: \(zone.records.count)")
            }
            
            print("DNS server configured successfully!")
            print("Note: In a real scenario, you would start the server with: try await server.start()")
            
        } catch {
            print("DNS server setup failed: \(error)")
        }
    }
    
    // MARK: - Example 4: DNS Message Creation and Serialization
    static func dnsMessageExample() async {
        print("\n=== DNS Message Creation and Serialization ===")
        
        do {
            // Create a DNS query message
            let queryMessage = DNSMessage(
                header: DNSHeader(
                    id: 12345,
                    isResponse: false,
                    opcode: .query,
                    recursionDesired: true
                ),
                questions: [
                    DNSQuestion(name: "example.com", type: .a, class: .internet)
                ]
            )
            
            // Serialize the message
            let codec = DNSMessageCodec()
            let serializedData = try codec.serialize(queryMessage)
            print("Serialized message size: \(serializedData.count) bytes")
            
            // Deserialize the message
            let deserializedMessage = try codec.deserialize(serializedData)
            print("Deserialized message ID: \(deserializedMessage.header.id)")
            print("Deserialized question: \(deserializedMessage.questions.first?.name ?? "none")")
            
            // Create a DNS response message
            let responseMessage = DNSMessage(
                header: DNSHeader(
                    id: 12345,
                    isResponse: true,
                    opcode: .query,
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
                        ttl: 3600,
                        rdata: Data([192, 168, 1, 1])
                    )
                ]
            )
            
            // Serialize and deserialize the response
            let responseData = try codec.serialize(responseMessage)
            let deserializedResponse = try codec.deserialize(responseData)
            print("Response message answers: \(deserializedResponse.answers.count)")
            
        } catch {
            print("DNS message example failed: \(error)")
        }
    }
    
    // MARK: - Example 5: All DNS Record Types
    static func dnsRecordTypesExample() async {
        print("\n=== All DNS Record Types ===")
        
        // A Record (IPv4)
        let aRecord = ARecord(address: IPv4Address("192.168.1.1"))
        print("A record: \(aRecord.address.stringValue)")
        
        // AAAA Record (IPv6)
        let aaaaRecord = AAAARecord(address: IPv6Address("2001:db8::1"))
        print("AAAA record: \(aaaaRecord.address.stringValue)")
        
        // CNAME Record
        let cnameRecord = CNAMERecord(canonicalName: "www.example.com")
        print("CNAME record: \(cnameRecord.canonicalName)")
        
        // MX Record
        let mxRecord = MXRecord(preference: 10, exchange: "mail.example.com")
        print("MX record: \(mxRecord.exchange) (priority: \(mxRecord.preference))")
        
        // NS Record
        let nsRecord = NSRecord(nameServer: "ns1.example.com")
        print("NS record: \(nsRecord.nameServer)")
        
        // PTR Record
        let ptrRecord = PTRRecord(pointer: "www.example.com")
        print("PTR record: \(ptrRecord.pointer)")
        
        // SOA Record
        let soaRecord = SOARecord(
            mname: "ns1.example.com",
            rname: "admin.example.com",
            serial: 2023120101,
            refresh: 3600,
            retry: 1800,
            expire: 604800,
            minimum: 3600
        )
        print("SOA record: \(soaRecord.mname)")
        
        // TXT Record
        let txtRecord = TXTRecord(strings: ["v=spf1", "include:_spf.example.com", "~all"])
        print("TXT record: \(txtRecord.strings.joined(separator: " "))")
        
        // HINFO Record
        let hinfoRecord = HINFORecord(cpu: "x86-64", os: "Linux")
        print("HINFO record: CPU=\(hinfoRecord.cpu), OS=\(hinfoRecord.os)")
        
        // WKS Record
        let wksRecord = WKSRecord(
            address: IPv4Address("192.168.1.1"),
            protocolNumber: 6, // TCP
            bitMap: Data([0xFF, 0xFF, 0xFF, 0xFF])
        )
        print("WKS record: \(wksRecord.address.stringValue)")
        
        // Test record serialization
        do {
            let codec = DNSMessageCodec()
            
            // Create a message with all record types
            let message = DNSMessage(
                header: DNSHeader(
                    id: 54321,
                    isResponse: true,
                    opcode: .query,
                    responseCode: .noError,
                    answerCount: 10
                ),
                questions: [
                    DNSQuestion(name: "example.com", type: .a, class: .internet)
                ],
                answers: [
                    DNSResourceRecord(name: "example.com", type: .a, ttl: 3600, rdata: aRecord.data),
                    DNSResourceRecord(name: "example.com", type: .aaaa, ttl: 3600, rdata: aaaaRecord.data),
                    DNSResourceRecord(name: "www.example.com", type: .cname, ttl: 3600, rdata: cnameRecord.data),
                    DNSResourceRecord(name: "example.com", type: .mx, ttl: 3600, rdata: mxRecord.data),
                    DNSResourceRecord(name: "example.com", type: .ns, ttl: 3600, rdata: nsRecord.data),
                    DNSResourceRecord(name: "1.1.168.192.in-addr.arpa", type: .ptr, ttl: 3600, rdata: ptrRecord.data),
                    DNSResourceRecord(name: "example.com", type: .soa, ttl: 3600, rdata: soaRecord.data),
                    DNSResourceRecord(name: "example.com", type: .txt, ttl: 3600, rdata: txtRecord.data),
                    DNSResourceRecord(name: "example.com", type: .hinfo, ttl: 3600, rdata: hinfoRecord.data),
                    DNSResourceRecord(name: "example.com", type: .wks, ttl: 3600, rdata: wksRecord.data)
                ]
            )
            
            let data = try codec.serialize(message)
            print("Serialized message with all record types: \(data.count) bytes")
            
            let deserialized = try codec.deserialize(data)
            print("Deserialized message has \(deserialized.answers.count) answers")
            
        } catch {
            print("Record serialization failed: \(error)")
        }
    }
}
