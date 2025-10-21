import Foundation
import DomainNameService

// MARK: - Basic DNS Resolution Examples

@main
struct BasicUsage {
    static func main() async {
        print("Domain Name Service - Basic Usage Examples")
        print("==========================================")
        
        // Example 1: Quick DNS lookups
        await exampleQuickLookups()
        
        // Example 2: Advanced DNS resolution
        await exampleAdvancedResolution()
        
        // Example 3: DNS record creation
        await exampleRecordCreation()
        
        // Example 4: DNS message handling
        await exampleMessageHandling()
        
        // Example 5: DNS server setup
        await exampleServerSetup()
    }
    
    static func exampleQuickLookups() async {
        print("\n1. Quick DNS Lookups")
        print("-------------------")
        
        do {
            // A record lookup
            let addresses = try await DomainNameService.lookupA("google.com")
            print("Google.com A records: \(addresses)")
            
            // AAAA record lookup
            let ipv6Addresses = try await DomainNameService.lookupAAAA("google.com")
            print("Google.com AAAA records: \(ipv6Addresses)")
            
            // MX record lookup
            let mxRecords = try await DomainNameService.lookupMX("google.com")
            print("Google.com MX records:")
            for record in mxRecords {
                print("  - \(record.exchange) (priority: \(record.preference))")
            }
            
            // TXT record lookup
            let txtRecords = try await DomainNameService.lookupTXT("google.com")
            print("Google.com TXT records:")
            for record in txtRecords {
                print("  - \(record)")
            }
            
        } catch {
            print("Error during quick lookups: \(error)")
        }
    }
    
    static func exampleAdvancedResolution() async {
        print("\n2. Advanced DNS Resolution")
        print("-------------------------")
        
        do {
            let resolver = DomainNameService.createResolver()
            
            // Resolve A records
            let aRecords = try await resolver.resolveA("github.com")
            print("GitHub.com A records:")
            for record in aRecords {
                print("  - \(record.address.stringValue)")
            }
            
            // Resolve AAAA records
            let aaaaRecords = try await resolver.resolveAAAA("github.com")
            print("GitHub.com AAAA records:")
            for record in aaaaRecords {
                print("  - \(record.address.stringValue)")
            }
            
            // Resolve MX records
            let mxRecords = try await resolver.resolveMX("github.com")
            print("GitHub.com MX records:")
            for record in mxRecords {
                print("  - \(record.exchange) (priority: \(record.preference))")
            }
            
            // Resolve NS records
            let nsRecords = try await resolver.resolveNS("github.com")
            print("GitHub.com NS records:")
            for record in nsRecords {
                print("  - \(record.nameServer)")
            }
            
            // Resolve SOA record
            let soaRecords = try await resolver.resolveSOA("github.com")
            print("GitHub.com SOA record:")
            for record in soaRecords {
                print("  - Primary: \(record.mname)")
                print("  - Admin: \(record.rname)")
                print("  - Serial: \(record.serial)")
                print("  - Refresh: \(record.refresh)")
                print("  - Retry: \(record.retry)")
                print("  - Expire: \(record.expire)")
                print("  - Minimum: \(record.minimum)")
            }
            
            // Generic query
            let message = try await resolver.query(domain: "github.com", type: .a)
            print("GitHub.com generic query response:")
            print("  - Response code: \(message.header.responseCode)")
            print("  - Authoritative: \(message.header.isAuthoritative)")
            print("  - Questions: \(message.questions.count)")
            print("  - Answers: \(message.answers.count)")
            print("  - Authority: \(message.authority.count)")
            print("  - Additional: \(message.additional.count)")
            
            try await resolver.close()
            
        } catch {
            print("Error during advanced resolution: \(error)")
        }
    }
    
    static func exampleRecordCreation() async {
        print("\n3. DNS Record Creation")
        print("---------------------")
        
        // A Record
        let aRecord = ARecord(address: IPv4Address("192.168.1.1"))
        print("A Record: \(aRecord.address.stringValue)")
        
        // AAAA Record
        let aaaaRecord = AAAARecord(address: IPv6Address("2001:db8::1"))
        print("AAAA Record: \(aaaaRecord.address.stringValue)")
        
        // CNAME Record
        let cnameRecord = CNAMERecord(canonicalName: "www.example.com")
        print("CNAME Record: \(cnameRecord.canonicalName)")
        
        // MX Record
        let mxRecord = MXRecord(preference: 10, exchange: "mail.example.com")
        print("MX Record: \(mxRecord.exchange) (priority: \(mxRecord.preference))")
        
        // NS Record
        let nsRecord = NSRecord(nameServer: "ns1.example.com")
        print("NS Record: \(nsRecord.nameServer)")
        
        // PTR Record
        let ptrRecord = PTRRecord(pointer: "www.example.com")
        print("PTR Record: \(ptrRecord.pointer)")
        
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
        print("SOA Record:")
        print("  - Primary: \(soaRecord.mname)")
        print("  - Admin: \(soaRecord.rname)")
        print("  - Serial: \(soaRecord.serial)")
        
        // TXT Record
        let txtRecord = TXTRecord(strings: ["v=spf1", "include:_spf.example.com", "~all"])
        print("TXT Record: \(txtRecord.strings)")
        
        // HINFO Record
        let hinfoRecord = HINFORecord(cpu: "x86-64", os: "Linux")
        print("HINFO Record: CPU=\(hinfoRecord.cpu), OS=\(hinfoRecord.os)")
        
        // WKS Record
        let wksRecord = WKSRecord(
            address: IPv4Address("192.168.1.1"),
            protocol: 6, // TCP
            bitMap: Data([0xFF, 0xFF, 0xFF, 0xFF])
        )
        print("WKS Record: \(wksRecord.address.stringValue) (protocol: \(wksRecord.protocol))")
    }
    
    static func exampleMessageHandling() async {
        print("\n4. DNS Message Handling")
        print("---------------------")
        
        do {
            // Create a DNS message
            let message = DNSMessage(
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
            
            print("Original message:")
            print("  - ID: \(message.header.id)")
            print("  - Response: \(message.header.isResponse)")
            print("  - Opcode: \(message.header.opcode)")
            print("  - Recursion desired: \(message.header.recursionDesired)")
            print("  - Questions: \(message.questions.count)")
            
            // Serialize message
            let codec = DNSMessageCodec()
            let data = try codec.serialize(message)
            print("  - Serialized size: \(data.count) bytes")
            
            // Deserialize message
            let deserialized = try codec.deserialize(data)
            print("Deserialized message:")
            print("  - ID: \(deserialized.header.id)")
            print("  - Response: \(deserialized.header.isResponse)")
            print("  - Opcode: \(deserialized.header.opcode)")
            print("  - Recursion desired: \(deserialized.header.recursionDesired)")
            print("  - Questions: \(deserialized.questions.count)")
            
        } catch {
            print("Error during message handling: \(error)")
        }
    }
    
    static func exampleServerSetup() async {
        print("\n5. DNS Server Setup")
        print("-----------------")
        
        do {
            // Create a DNS server
            let server = try DomainNameService.createServer()
            
            // Create a zone
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
            
            if let zone = zone {
                print("Created zone: \(zone.name)")
                print("  - Primary: \(zone.soa.mname)")
                print("  - Admin: \(zone.soa.rname)")
                print("  - Records: \(zone.getAllRecords().count)")
                
                // Add zone to server
                server.zoneManager.addZone(zone)
                print("Zone added to server")
                
                // Test zone lookups
                let aRecords = try server.zoneManager.lookup(domain: "example.com", type: .a, class: .internet)
                print("A records for example.com: \(aRecords.count)")
                
                let mxRecords = try server.zoneManager.lookup(domain: "example.com", type: .mx, class: .internet)
                print("MX records for example.com: \(mxRecords.count)")
                
                let txtRecords = try server.zoneManager.lookup(domain: "example.com", type: .txt, class: .internet)
                print("TXT records for example.com: \(txtRecords.count)")
            }
            
            print("DNS server setup complete")
            
        } catch {
            print("Error during server setup: \(error)")
        }
    }
}
