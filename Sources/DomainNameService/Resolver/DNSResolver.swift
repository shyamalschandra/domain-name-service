import Foundation
import NIOCore
import Logging

/// DNS Resolver as defined in RFC 1035 Section 7
public class DNSResolver {
    private let transportManager: DNSTransportManager
    private let logger: Logger
    private let cache: DNSCache
    private let rootServers: [String]
    
    public init(
        transportManager: DNSTransportManager? = nil,
        cache: DNSCache? = nil,
        rootServers: [String]? = nil,
        logger: Logger = Logger(label: "dns.resolver")
    ) {
        self.transportManager = transportManager ?? DNSTransportManager(logger: logger)
        self.cache = cache ?? DNSCache()
        self.rootServers = rootServers ?? [
            "198.41.0.4",     // a.root-servers.net
            "199.9.14.201",   // b.root-servers.net
            "192.33.4.12",    // c.root-servers.net
            "199.7.91.13",    // d.root-servers.net
            "192.203.230.10", // e.root-servers.net
            "192.5.5.241",    // f.root-servers.net
            "192.112.36.4",   // g.root-servers.net
            "198.97.190.53",  // h.root-servers.net
            "192.36.148.17",  // i.root-servers.net
            "192.58.128.30",  // j.root-servers.net
            "193.0.14.129",   // k.root-servers.net
            "199.7.83.42",    // l.root-servers.net
            "202.12.27.33"    // m.root-servers.net
        ]
        self.logger = logger
    }
    
    // MARK: - Public Query Methods
    
    /// Resolve A record (IPv4 address)
    public func resolveA(_ domain: String) async throws -> [ARecord] {
        let response = try await query(domain: domain, type: .a)
        return response.answers.compactMap { record in
            guard record.type == .a else { return nil }
            return ARecord(data: record.rdata)
        }
    }
    
    /// Resolve AAAA record (IPv6 address)
    public func resolveAAAA(_ domain: String) async throws -> [AAAARecord] {
        let response = try await query(domain: domain, type: .aaaa)
        return response.answers.compactMap { record in
            guard record.type == .aaaa else { return nil }
            return AAAARecord(data: record.rdata)
        }
    }
    
    /// Resolve CNAME record
    public func resolveCNAME(_ domain: String) async throws -> [CNAMERecord] {
        let response = try await query(domain: domain, type: .cname)
        return response.answers.compactMap { record in
            guard record.type == .cname else { return nil }
            return CNAMERecord(data: record.rdata)
        }
    }
    
    /// Resolve MX record
    public func resolveMX(_ domain: String) async throws -> [MXRecord] {
        let response = try await query(domain: domain, type: .mx)
        return response.answers.compactMap { record in
            guard record.type == .mx else { return nil }
            return MXRecord(data: record.rdata)
        }
    }
    
    /// Resolve NS record
    public func resolveNS(_ domain: String) async throws -> [NSRecord] {
        let response = try await query(domain: domain, type: .ns)
        return response.answers.compactMap { record in
            guard record.type == .ns else { return nil }
            return NSRecord(data: record.rdata)
        }
    }
    
    /// Resolve PTR record
    public func resolvePTR(_ domain: String) async throws -> [PTRRecord] {
        let response = try await query(domain: domain, type: .ptr)
        return response.answers.compactMap { record in
            guard record.type == .ptr else { return nil }
            return PTRRecord(data: record.rdata)
        }
    }
    
    /// Resolve SOA record
    public func resolveSOA(_ domain: String) async throws -> [SOARecord] {
        let response = try await query(domain: domain, type: .soa)
        return response.answers.compactMap { record in
            guard record.type == .soa else { return nil }
            return SOARecord(data: record.rdata)
        }
    }
    
    /// Resolve TXT record
    public func resolveTXT(_ domain: String) async throws -> [TXTRecord] {
        let response = try await query(domain: domain, type: .txt)
        return response.answers.compactMap { record in
            guard record.type == .txt else { return nil }
            return TXTRecord(data: record.rdata)
        }
    }
    
    /// Generic query method
    public func query(domain: String, type: DNSRecordType, `class`: DNSRecordClass = .internet) async throws -> DNSMessage {
        logger.info("Resolving \(type) record for \(domain)")
        
        // Check cache first
        if let cached = cache.get(domain: domain, type: type, class: `class`) {
            logger.debug("Cache hit for \(domain) \(type)")
            return cached
        }
        
        // Perform recursive resolution
        let response = try await recursiveResolve(domain: domain, type: type, class: `class`)
        
        // Cache the response
        cache.set(response, for: domain, type: type, class: `class`)
        
        return response
    }
    
    // MARK: - Private Resolution Methods
    
    private func recursiveResolve(domain: String, type: DNSRecordType, class: DNSRecordClass) async throws -> DNSMessage {
        var currentDomain = domain
        var nameServers = rootServers
        
        while true {
            logger.debug("Querying \(currentDomain) with name servers: \(nameServers)")
            
            // Try each name server
            for nameServer in nameServers {
                do {
                    let response = try await queryNameServer(
                        domain: currentDomain,
                        type: type,
                        class: `class`,
                        nameServer: nameServer
                    )
                    
                    // Check if we have the answer
                    if !response.answers.isEmpty {
                        return response
                    }
                    
                    // Check for CNAME records
                    let cnameRecords = response.answers.filter { $0.type == .cname }
                    if !cnameRecords.isEmpty {
                        let cnameRecord = cnameRecords.first!
                        let cname = CNAMERecord(data: cnameRecord.rdata)
                        return try await recursiveResolve(domain: cname?.canonicalName ?? "", type: type, class: `class`)
                    }
                    
                    // Check for NS records in authority section
                    let nsRecords = response.authority.filter { $0.type == .ns }
                    if !nsRecords.isEmpty {
                        let nsRecord = nsRecords.first!
                        let ns = NSRecord(data: nsRecord.rdata)
                        
                        // Get A records for the name server
                        let aRecords = try await resolveA(ns?.nameServer ?? "")
                        if !aRecords.isEmpty {
                            nameServers = aRecords.map { $0.address.stringValue }
                            currentDomain = ns?.nameServer ?? ""
                            continue
                        }
                    }
                    
                    // Check for additional records
                    let additionalARecords = response.additional.filter { $0.type == .a }
                    if !additionalARecords.isEmpty {
                        nameServers = additionalARecords.compactMap { record in
                            ARecord(data: record.rdata)?.address.stringValue
                        }
                        continue
                    }
                    
                } catch {
                    logger.warning("Failed to query name server \(nameServer): \(error)")
                    continue
                }
            }
            
            throw DNSError.nameError
        }
    }
    
    private func queryNameServer(domain: String, type: DNSRecordType, class: DNSRecordClass, nameServer: String) async throws -> DNSMessage {
        let question = DNSQuestion(name: domain, type: type, class: `class`)
        let header = DNSHeader(
            id: UInt16.random(in: 1...65535),
            isResponse: false,
            opcode: .query,
            recursionDesired: true
        )
        
        let message = DNSMessage(
            header: header,
            questions: [question]
        )
        
        let address = try SocketAddress(ipAddress: nameServer, port: 53)
        return try await transportManager.send(message, to: address)
    }
    
    public func close() async throws {
        try await transportManager.close()
    }
}

// MARK: - DNS Cache

public class DNSCache {
    private var cache: [String: DNSMessage] = [:]
    private let queue = DispatchQueue(label: "dns.cache", attributes: .concurrent)
    
    public init() {}
    
    public func get(domain: String, type: DNSRecordType, class: DNSRecordClass) -> DNSMessage? {
        let key = "\(domain):\(type.rawValue):\(`class`.rawValue)"
        return queue.sync {
            return cache[key]
        }
    }
    
    public func set(_ message: DNSMessage, for domain: String, type: DNSRecordType, class: DNSRecordClass) {
        let key = "\(domain):\(type.rawValue):\(`class`.rawValue)"
        queue.async(flags: .barrier) {
            self.cache[key] = message
        }
    }
    
    public func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

// MARK: - DNS Resolver Configuration

public struct DNSResolverConfig {
    public let timeout: TimeInterval
    public let retryCount: Int
    public let useCache: Bool
    public let rootServers: [String]
    
    public init(
        timeout: TimeInterval = 5.0,
        retryCount: Int = 3,
        useCache: Bool = true,
        rootServers: [String]? = nil
    ) {
        self.timeout = timeout
        self.retryCount = retryCount
        self.useCache = useCache
        self.rootServers = rootServers ?? [
            "198.41.0.4",     // a.root-servers.net
            "199.9.14.201",   // b.root-servers.net
            "192.33.4.12",    // c.root-servers.net
            "199.7.91.13",    // d.root-servers.net
            "192.203.230.10", // e.root-servers.net
            "192.5.5.241",    // f.root-servers.net
            "192.112.36.4",   // g.root-servers.net
            "198.97.190.53",  // h.root-servers.net
            "192.36.148.17",  // i.root-servers.net
            "192.58.128.30",  // j.root-servers.net
            "193.0.14.129",   // k.root-servers.net
            "199.7.83.42",    // l.root-servers.net
            "202.12.27.33"    // m.root-servers.net
        ]
    }
}
