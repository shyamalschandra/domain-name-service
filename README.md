# Domain Name Service

A complete DNS implementation for Swift 6.1+ based on RFC 1035: Domain Names - Implementation and Specification.

## Features

- **Complete RFC 1035 Implementation**: Full support for all DNS record types and message formats
- **UDP and TCP Transport**: Both transport protocols as specified in RFC 1035
- **DNS Resolver**: Recursive DNS resolution with caching
- **DNS Server**: Authoritative name server implementation
- **Message Compression**: DNS message compression for efficient transmission
- **Comprehensive Testing**: Full test suite covering all functionality
- **Swift 6.1+ Support**: Modern Swift with async/await support

## Installation

Add this package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/Domain-Name-Service.git", from: "1.0.0")
]
```

## Quick Start

### DNS Resolution

```swift
import DomainNameService

// Quick A record lookup
let addresses = try await DomainNameService.lookupA("google.com")
print("Google.com addresses: \(addresses)")

// Quick AAAA record lookup
let ipv6Addresses = try await DomainNameService.lookupAAAA("google.com")
print("Google.com IPv6 addresses: \(ipv6Addresses)")

// Quick MX record lookup
let mxRecords = try await DomainNameService.lookupMX("google.com")
for record in mxRecords {
    print("Mail server: \(record.exchange) (priority: \(record.preference))")
}
```

### Advanced DNS Resolution

```swift
import DomainNameService

// Create a resolver with custom configuration
let resolver = DomainNameService.createResolver()

// Resolve A records
let aRecords = try await resolver.resolveA("example.com")
for record in aRecords {
    print("A record: \(record.address.stringValue)")
}

// Resolve MX records
let mxRecords = try await resolver.resolveMX("example.com")
for record in mxRecords {
    print("MX record: \(record.exchange) (priority: \(record.preference))")
}

// Resolve TXT records
let txtRecords = try await resolver.resolveTXT("example.com")
for record in txtRecords {
    print("TXT record: \(record.strings)")
}

// Generic query
let message = try await resolver.query(domain: "example.com", type: .a)
print("Response: \(message)")
```

### DNS Server

```swift
import DomainNameService

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
    .addMXRecord(name: "example.com", preference: 10, exchange: "mail.example.com")
    .addNSRecord(name: "example.com", nameServer: "ns1.example.com")
    .addTXTRecord(name: "example.com", strings: ["v=spf1", "include:_spf.example.com", "~all"])
    .build()

// Add zone to server
if let zone = zone {
    server.zoneManager.addZone(zone)
}

// Start server
try await server.start()
```

### DNS Record Types

```swift
import DomainNameService

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
print("TXT record: \(txtRecord.strings)")

// HINFO Record
let hinfoRecord = HINFORecord(cpu: "x86-64", os: "Linux")
print("HINFO record: CPU=\(hinfoRecord.cpu), OS=\(hinfoRecord.os)")

// WKS Record
let wksRecord = WKSRecord(
    address: IPv4Address("192.168.1.1"),
    protocol: 6, // TCP
    bitMap: Data([0xFF, 0xFF, 0xFF, 0xFF])
)
print("WKS record: \(wksRecord.address.stringValue)")
```

### DNS Message Handling

```swift
import DomainNameService

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

// Serialize message
let codec = DNSMessageCodec()
let data = try codec.serialize(message)

// Deserialize message
let deserialized = try codec.deserialize(data)
print("Deserialized message: \(deserialized)")
```

### Transport Configuration

```swift
import DomainNameService

// Create transport manager with custom configuration
let config = DNSTransportConfig(
    timeout: 10.0,
    retryCount: 3,
    useTCP: true,
    useUDP: true
)

let transportManager = DNSTransportManager(config: config)

// Create resolver with custom transport
let resolver = DNSResolver(transportManager: transportManager)

// Use resolver
let addresses = try await resolver.resolveA("example.com")
```

## API Reference

### Core Types

- `DNSMessage`: Complete DNS message structure
- `DNSHeader`: DNS message header
- `DNSQuestion`: DNS question section
- `DNSResourceRecord`: DNS resource record
- `DNSMessageCodec`: Message serialization/deserialization

### Record Types

- `ARecord`: IPv4 address record
- `AAAARecord`: IPv6 address record
- `CNAMERecord`: Canonical name record
- `MXRecord`: Mail exchange record
- `NSRecord`: Name server record
- `PTRRecord`: Pointer record
- `SOARecord`: Start of authority record
- `TXTRecord`: Text record
- `HINFORecord`: Host information record
- `WKSRecord`: Well-known services record

### Transport

- `DNSTransport`: Transport protocol interface
- `DNSUDPTransport`: UDP transport implementation
- `DNSTCPTransport`: TCP transport implementation
- `DNSTransportManager`: Transport management

### Resolver

- `DNSResolver`: DNS resolution client
- `DNSCache`: DNS response caching
- `DNSResolverConfig`: Resolver configuration

### Server

- `DNSServer`: DNS name server
- `DNSZone`: DNS zone management
- `DNSZoneManager`: Zone management
- `DNSZoneBuilder`: Zone creation helper

## Testing

Run the test suite:

```bash
swift test
```

The test suite includes:

- Unit tests for all DNS record types
- Message serialization/deserialization tests
- Transport protocol tests
- Resolver functionality tests
- Server functionality tests
- Integration tests

## Requirements

- Swift 6.1+
- macOS 13.0+
- iOS 16.0+
- tvOS 16.0+
- watchOS 9.0+
- visionOS 1.0+

## Dependencies

- SwiftNIO: For networking and async I/O
- SwiftNIO SSL: For secure transport
- Swift Logging: For logging

## License

This project is licensed under the Copyright License.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## RFC Compliance

This implementation follows RFC 1035: Domain Names - Implementation and Specification, including:

- Complete message format support
- All standard record types
- UDP and TCP transport protocols
- Message compression
- Recursive resolution
- Authoritative name server functionality

## Performance

The library is designed for high performance with:

- Async/await support for concurrent operations
- Efficient message serialization/deserialization
- DNS message compression
- Connection pooling and reuse
- Configurable timeouts and retries
