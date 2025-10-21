import Foundation
import DomainNameService

/// Simple usage examples for the DNS library
@main
struct SimpleUsage {
    static func main() async {
        print("DNS Library - Simple Usage Examples")
        print("===================================")
        
        // Example 1: Quick DNS lookups
        await quickLookups()
        
        // Example 2: Create and use a DNS resolver
        await customResolver()
        
        // Example 3: Work with DNS records
        await dnsRecords()
        
        // Example 4: Create DNS messages
        await dnsMessages()
    }
    
    // MARK: - Quick DNS Lookups
    static func quickLookups() async {
        print("\n1. Quick DNS Lookups")
        print("-------------------")
        
        do {
            // Look up A records (IPv4 addresses)
            let addresses = try await DomainNameService.lookupA("google.com")
            print("Google.com IPv4 addresses:")
            for address in addresses {
                print("  • \(address.stringValue)")
            }
            
            // Look up AAAA records (IPv6 addresses)
            let ipv6Addresses = try await DomainNameService.lookupAAAA("google.com")
            print("Google.com IPv6 addresses:")
            for address in ipv6Addresses {
                print("  • \(address.stringValue)")
            }
            
            // Look up MX records (mail servers)
            let mxRecords = try await DomainNameService.lookupMX("google.com")
            print("Google.com mail servers:")
            for record in mxRecords {
                print("  • \(record.exchange) (priority: \(record.preference))")
            }
            
        } catch {
            print("Lookup failed: \(error)")
        }
    }
    
    // MARK: - Custom DNS Resolver
    static func customResolver() async {
        print("\n2. Custom DNS Resolver")
        print("---------------------")
        
        do {
            // Create a custom resolver
            let resolver = DomainNameService.createResolver()
            
            // Resolve different record types for a domain
            let domain = "github.com"
            
            // A records (IPv4)
            let aRecords = try await resolver.resolveA(domain)
            print("\(domain) IPv4 addresses:")
            for record in aRecords {
                print("  • \(record.address.stringValue)")
            }
            
            // MX records (mail servers)
            let mxRecords = try await resolver.resolveMX(domain)
            print("\(domain) mail servers:")
            for record in mxRecords {
                print("  • \(record.exchange) (priority: \(record.preference))")
            }
            
            // TXT records (text records)
            let txtRecords = try await resolver.resolveTXT(domain)
            print("\(domain) text records:")
            for record in txtRecords {
                print("  • \(record.strings.joined(separator: " "))")
            }
            
        } catch {
            print("Resolver failed: \(error)")
        }
    }
    
    // MARK: - DNS Records
    static func dnsRecords() async {
        print("\n3. DNS Records")
        print("---------------")
        
        // Create different types of DNS records
        print("Creating DNS records:")
        
        // A record (IPv4 address)
        let aRecord = ARecord(address: IPv4Address("192.168.1.100"))
        print("  • A record: \(aRecord.address.stringValue)")
        
        // AAAA record (IPv6 address)
        let aaaaRecord = AAAARecord(address: IPv6Address("2001:db8::1"))
        print("  • AAAA record: \(aaaaRecord.address.stringValue)")
        
        // CNAME record (canonical name)
        let cnameRecord = CNAMERecord(canonicalName: "www.example.com")
        print("  • CNAME record: \(cnameRecord.canonicalName)")
        
        // MX record (mail exchange)
        let mxRecord = MXRecord(preference: 10, exchange: "mail.example.com")
        print("  • MX record: \(mxRecord.exchange) (priority: \(mxRecord.preference))")
        
        // NS record (name server)
        let nsRecord = NSRecord(nameServer: "ns1.example.com")
        print("  • NS record: \(nsRecord.nameServer)")
        
        // TXT record (text record)
        let txtRecord = TXTRecord(strings: ["v=spf1", "include:_spf.example.com", "~all"])
        print("  • TXT record: \(txtRecord.strings.joined(separator: " "))")
        
        // SOA record (start of authority)
        let soaRecord = SOARecord(
            mname: "ns1.example.com",
            rname: "admin.example.com",
            serial: 2023120101,
            refresh: 3600,
            retry: 1800,
            expire: 604800,
            minimum: 3600
        )
        print("  • SOA record: \(soaRecord.mname)")
    }
    
    // MARK: - DNS Messages
    static func dnsMessages() async {
        print("\n4. DNS Messages")
        print("---------------")
        
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
            
            print("Created DNS query message:")
            print("  • ID: \(queryMessage.header.id)")
            print("  • Question: \(queryMessage.questions.first?.name ?? "none")")
            print("  • Type: \(queryMessage.questions.first?.type.rawValue ?? 0)")
            
            // Serialize the message
            let codec = DNSMessageCodec()
            let serializedData = try codec.serialize(queryMessage)
            print("  • Serialized size: \(serializedData.count) bytes")
            
            // Deserialize the message
            let deserializedMessage = try codec.deserialize(serializedData)
            print("  • Deserialized ID: \(deserializedMessage.header.id)")
            print("  • Deserialized question: \(deserializedMessage.questions.first?.name ?? "none")")
            
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
            
            print("Created DNS response message:")
            print("  • ID: \(responseMessage.header.id)")
            print("  • Response code: \(responseMessage.header.responseCode)")
            print("  • Answers: \(responseMessage.answers.count)")
            
        } catch {
            print("DNS message creation failed: \(error)")
        }
    }
}
