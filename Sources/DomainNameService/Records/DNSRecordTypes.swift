import Foundation
import NIOCore

// MARK: - A Record (RFC 1035 Section 3.4.1)

/// A record - 32-bit Internet address
public struct ARecord: Sendable {
    public let address: IPv4Address
    
    public init(address: IPv4Address) {
        self.address = address
    }
    
    public init?(data: Data) {
        guard data.count == 4 else { return nil }
        self.address = IPv4Address(data)
    }
    
    public var rdata: Data {
        return address.data
    }
}

// MARK: - AAAA Record (RFC 3596)

/// AAAA record - 128-bit IPv6 address
public struct AAAARecord: Sendable {
    public let address: IPv6Address
    
    public init(address: IPv6Address) {
        self.address = address
    }
    
    public init?(data: Data) {
        guard data.count == 16 else { return nil }
        self.address = IPv6Address(data)
    }
    
    public var rdata: Data {
        return address.data
    }
}

// MARK: - CNAME Record (RFC 1035 Section 3.3.1)

/// CNAME record - Canonical name
public struct CNAMERecord: Sendable {
    public let canonicalName: String
    
    public init(canonicalName: String) {
        self.canonicalName = canonicalName
    }
    
    public init?(data: Data) {
        // Parse domain name from data
        guard let name = String(data: data, encoding: .utf8) else { return nil }
        self.canonicalName = name
    }
    
    public var rdata: Data {
        return canonicalName.data(using: .utf8) ?? Data()
    }
}

// MARK: - MX Record (RFC 1035 Section 3.3.9)

/// MX record - Mail exchange
public struct MXRecord: Sendable {
    public let preference: UInt16
    public let exchange: String
    
    public init(preference: UInt16, exchange: String) {
        self.preference = preference
        self.exchange = exchange
    }
    
    public init?(data: Data) {
        guard data.count >= 2 else { return nil }
        
        let preference = UInt16(data[0]) << 8 | UInt16(data[1])
        let exchangeData = data.dropFirst(2)
        
        guard let exchange = String(data: exchangeData, encoding: .utf8) else { return nil }
        
        self.preference = preference
        self.exchange = exchange
    }
    
    public var rdata: Data {
        var data = Data()
        data.append(UInt8(preference >> 8))
        data.append(UInt8(preference & 0xFF))
        data.append(exchange.data(using: .utf8) ?? Data())
        return data
    }
}

// MARK: - NS Record (RFC 1035 Section 3.3.11)

/// NS record - Name server
public struct NSRecord: Sendable {
    public let nameServer: String
    
    public init(nameServer: String) {
        self.nameServer = nameServer
    }
    
    public init?(data: Data) {
        guard let nameServer = String(data: data, encoding: .utf8) else { return nil }
        self.nameServer = nameServer
    }
    
    public var rdata: Data {
        return nameServer.data(using: .utf8) ?? Data()
    }
}

// MARK: - PTR Record (RFC 1035 Section 3.3.12)

/// PTR record - Pointer
public struct PTRRecord: Sendable {
    public let pointer: String
    
    public init(pointer: String) {
        self.pointer = pointer
    }
    
    public init?(data: Data) {
        guard let pointer = String(data: data, encoding: .utf8) else { return nil }
        self.pointer = pointer
    }
    
    public var rdata: Data {
        return pointer.data(using: .utf8) ?? Data()
    }
}

// MARK: - SOA Record (RFC 1035 Section 3.3.13)

/// SOA record - Start of Authority
public struct SOARecord: Sendable {
    public let mname: String        // Primary name server
    public let rname: String        // Responsible person's mailbox
    public let serial: UInt32       // Serial number
    public let refresh: UInt32      // Refresh interval
    public let retry: UInt32        // Retry interval
    public let expire: UInt32       // Expire time
    public let minimum: UInt32      // Minimum TTL
    
    public init(
        mname: String,
        rname: String,
        serial: UInt32,
        refresh: UInt32,
        retry: UInt32,
        expire: UInt32,
        minimum: UInt32
    ) {
        self.mname = mname
        self.rname = rname
        self.serial = serial
        self.refresh = refresh
        self.retry = retry
        self.expire = expire
        self.minimum = minimum
    }
    
    public init?(data: Data) {
        var offset = 0
        
        // Parse mname
        guard let mname = SOARecord.parseDomainName(from: data, offset: &offset) else { return nil }
        
        // Parse rname
        guard let rname = SOARecord.parseDomainName(from: data, offset: &offset) else { return nil }
        
        // Parse numeric fields
        guard data.count >= offset + 20 else { return nil }
        
        let serial = UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
        offset += 4
        
        let refresh = UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
        offset += 4
        
        let retry = UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
        offset += 4
        
        let expire = UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
        offset += 4
        
        let minimum = UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
        
        self.mname = mname
        self.rname = rname
        self.serial = serial
        self.refresh = refresh
        self.retry = retry
        self.expire = expire
        self.minimum = minimum
    }
    
    public var rdata: Data {
        var data = Data()
        data.append(mname.data(using: .utf8) ?? Data())
        data.append(rname.data(using: .utf8) ?? Data())
        
        // Serial
        data.append(UInt8(serial >> 24))
        data.append(UInt8((serial >> 16) & 0xFF))
        data.append(UInt8((serial >> 8) & 0xFF))
        data.append(UInt8(serial & 0xFF))
        
        // Refresh
        data.append(UInt8(refresh >> 24))
        data.append(UInt8((refresh >> 16) & 0xFF))
        data.append(UInt8((refresh >> 8) & 0xFF))
        data.append(UInt8(refresh & 0xFF))
        
        // Retry
        data.append(UInt8(retry >> 24))
        data.append(UInt8((retry >> 16) & 0xFF))
        data.append(UInt8((retry >> 8) & 0xFF))
        data.append(UInt8(retry & 0xFF))
        
        // Expire
        data.append(UInt8(expire >> 24))
        data.append(UInt8((expire >> 16) & 0xFF))
        data.append(UInt8((expire >> 8) & 0xFF))
        data.append(UInt8(expire & 0xFF))
        
        // Minimum
        data.append(UInt8(minimum >> 24))
        data.append(UInt8((minimum >> 16) & 0xFF))
        data.append(UInt8((minimum >> 8) & 0xFF))
        data.append(UInt8(minimum & 0xFF))
        
        return data
    }
    
    private static func parseDomainName(from data: Data, offset: inout Int) -> String? {
        // Simplified domain name parsing - in a real implementation,
        // this would handle compression pointers
        var labels: [String] = []
        
        while offset < data.count {
            let length = Int(data[offset])
            offset += 1
            
            if length == 0 {
                break
            }
            
            guard offset + length <= data.count else { return nil }
            let labelData = data.subdata(in: offset..<offset + length)
            guard let label = String(data: labelData, encoding: .utf8) else { return nil }
            labels.append(label)
            offset += length
        }
        
        return labels.joined(separator: ".")
    }
}

// MARK: - TXT Record (RFC 1035 Section 3.3.14)

/// TXT record - Text strings
public struct TXTRecord: Sendable {
    public let strings: [String]
    
    public init(strings: [String]) {
        self.strings = strings
    }
    
    public init?(data: Data) {
        var strings: [String] = []
        var offset = 0
        
        while offset < data.count {
            let length = Int(data[offset])
            offset += 1
            
            guard offset + length <= data.count else { return nil }
            let stringData = data.subdata(in: offset..<offset + length)
            guard let string = String(data: stringData, encoding: .utf8) else { return nil }
            strings.append(string)
            offset += length
        }
        
        // Ensure we have at least one string
        guard !strings.isEmpty else { return nil }
        
        self.strings = strings
    }
    
    public var rdata: Data {
        var data = Data()
        for string in strings {
            let stringData = string.data(using: .utf8) ?? Data()
            data.append(UInt8(stringData.count))
            data.append(stringData)
        }
        return data
    }
}

// MARK: - HINFO Record (RFC 1035 Section 3.3.2)

/// HINFO record - Host information
public struct HINFORecord: Sendable {
    public let cpu: String
    public let os: String
    
    public init(cpu: String, os: String) {
        self.cpu = cpu
        self.os = os
    }
    
    public init?(data: Data) {
        var offset = 0
        
        // Parse CPU string
        guard let cpu = HINFORecord.parseString(from: data, offset: &offset) else { return nil }
        
        // Parse OS string
        guard let os = HINFORecord.parseString(from: data, offset: &offset) else { return nil }
        
        self.cpu = cpu
        self.os = os
    }
    
    public var rdata: Data {
        var data = Data()
        
        let cpuData = cpu.data(using: .utf8) ?? Data()
        data.append(UInt8(cpuData.count))
        data.append(cpuData)
        
        let osData = os.data(using: .utf8) ?? Data()
        data.append(UInt8(osData.count))
        data.append(osData)
        
        return data
    }
    
    private static func parseString(from data: Data, offset: inout Int) -> String? {
        guard offset < data.count else { return nil }
        let length = Int(data[offset])
        offset += 1
        
        guard offset + length <= data.count else { return nil }
        let stringData = data.subdata(in: offset..<offset + length)
        offset += length
        
        return String(data: stringData, encoding: .utf8)
    }
}

// MARK: - WKS Record (RFC 1035 Section 3.4.2)

/// WKS record - Well-known services
public struct WKSRecord: Sendable {
    public let address: IPv4Address
    public let protocolNumber: UInt8
    public let bitMap: Data
    
    public init(address: IPv4Address, protocolNumber: UInt8, bitMap: Data) {
        self.address = address
        self.protocolNumber = protocolNumber
        self.bitMap = bitMap
    }
    
    public init?(data: Data) {
        guard data.count >= 5 else { return nil }
        
        let address = IPv4Address(data.prefix(4))
        let protocolNumber = data[4]
        let bitMap = data.dropFirst(5)
        
        self.address = address
        self.protocolNumber = protocolNumber
        self.bitMap = bitMap
    }
    
    public var rdata: Data {
        var data = Data()
        data.append(address.data)
        data.append(protocolNumber)
        data.append(bitMap)
        return data
    }
}

// MARK: - IPv4Address

public struct IPv4Address: Sendable {
    public let data: Data
    
    public init(_ data: Data) {
        self.data = data
    }
    
    public init(_ string: String) {
        let components = string.components(separatedBy: ".")
        var bytes: [UInt8] = []
        
        for component in components {
            if let byte = UInt8(component) {
                bytes.append(byte)
            }
        }
        
        self.data = Data(bytes)
    }
    
    public var stringValue: String {
        guard data.count == 4 else { return "0.0.0.0" }
        return "\(data[0]).\(data[1]).\(data[2]).\(data[3])"
    }
}

// MARK: - IPv6Address

public struct IPv6Address: Sendable {
    public let data: Data
    
    public init(_ data: Data) {
        self.data = data
    }
    
    public init(_ string: String) {
        var bytes = Array(repeating: UInt8(0), count: 16)
        
        // Handle :: notation by expanding it
        let expanded = IPv6Address.expandIPv6String(string)
        let components = expanded.components(separatedBy: ":")
        
        var byteIndex = 0
        for component in components {
            let value = UInt16(component, radix: 16) ?? 0
            bytes[byteIndex] = UInt8(value >> 8)
            bytes[byteIndex + 1] = UInt8(value & 0xFF)
            byteIndex += 2
        }
        
        self.data = Data(bytes)
    }
    
    private static func expandIPv6String(_ string: String) -> String {
        // Handle :: notation
        if string.contains("::") {
            let parts = string.components(separatedBy: "::")
            let leftParts = parts[0].isEmpty ? [] : parts[0].components(separatedBy: ":")
            let rightParts = parts.count > 1 && !parts[1].isEmpty ? parts[1].components(separatedBy: ":") : []
            
            let totalParts = 8
            let missingParts = totalParts - leftParts.count - rightParts.count
            
            var expanded: [String] = []
            expanded.append(contentsOf: leftParts)
            for _ in 0..<missingParts {
                expanded.append("0")
            }
            expanded.append(contentsOf: rightParts)
            
            return expanded.joined(separator: ":")
        }
        
        return string
    }
    
    public var stringValue: String {
        guard data.count == 16 else { return "::" }
        
        var components: [String] = []
        for i in stride(from: 0, to: 16, by: 2) {
            let value = UInt16(data[i]) << 8 | UInt16(data[i + 1])
            components.append(String(value, radix: 16))
        }
        
        // Find the longest sequence of consecutive zeros
        var bestStart = -1
        var bestLength = 0
        var currentStart = -1
        var currentLength = 0
        
        for (index, component) in components.enumerated() {
            if component == "0" {
                if currentStart == -1 {
                    currentStart = index
                }
                currentLength += 1
            } else {
                if currentLength > bestLength {
                    bestStart = currentStart
                    bestLength = currentLength
                }
                currentStart = -1
                currentLength = 0
            }
        }
        
        // Check if we ended with a zero sequence
        if currentLength > bestLength {
            bestStart = currentStart
            bestLength = currentLength
        }
        
        // Special case: if all components are zero, return "::"
        if components.allSatisfy({ $0 == "0" }) {
            return "::"
        }
        
        // Apply zero compression if we found a sequence of 2 or more zeros
        if bestLength >= 2 {
            var result: [String] = []
            
            if bestStart > 0 {
                result.append(contentsOf: Array(components[0..<bestStart]))
            }
            
            result.append("")
            
            if bestStart + bestLength < components.count {
                result.append(contentsOf: Array(components[(bestStart + bestLength)...]))
            }
            
            return result.joined(separator: ":")
        }
        
        return components.joined(separator: ":")
    }
}
