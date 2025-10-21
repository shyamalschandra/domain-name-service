// Domain Name Service - A complete DNS implementation for Swift 6.1+
// Based on RFC 1035: Domain Names - Implementation and Specification

import Foundation
import NIOCore
import NIOPosix
import Logging

// MARK: - Public API

/// Main DNS library interface
public struct DomainNameService {
    /// Create a DNS resolver
    public static func createResolver(
        config: DNSResolverConfig = DNSResolverConfig(),
        logger: Logger = Logger(label: "dns.resolver")
    ) -> DNSResolver {
        return DNSResolver(logger: logger)
    }
    
    /// Create a DNS server
    public static func createServer(
        config: DNSServerConfig = DNSServerConfig(),
        logger: Logger = Logger(label: "dns.server")
    ) throws -> DNSServer {
        return try DNSServer(logger: logger)
    }
    
    /// Create a DNS zone builder
    public static func createZoneBuilder() -> DNSZoneBuilder {
        return DNSZoneBuilder()
    }
    
    /// Create a DNS transport manager
    public static func createTransportManager(
        config: DNSTransportConfig = DNSTransportConfig(),
        logger: Logger = Logger(label: "dns.transport")
    ) -> DNSTransportManager {
        return DNSTransportManager(config: config, logger: logger)
    }
}

// MARK: - Convenience Methods

extension DomainNameService {
    /// Quick A record lookup
    public static func lookupA(_ domain: String) async throws -> [String] {
        let resolver = createResolver()
        let records = try await resolver.resolveA(domain)
        return records.map { $0.address.stringValue }
    }
    
    /// Quick AAAA record lookup
    public static func lookupAAAA(_ domain: String) async throws -> [String] {
        let resolver = createResolver()
        let records = try await resolver.resolveAAAA(domain)
        return records.map { $0.address.stringValue }
    }
    
    /// Quick MX record lookup
    public static func lookupMX(_ domain: String) async throws -> [(preference: UInt16, exchange: String)] {
        let resolver = createResolver()
        let records = try await resolver.resolveMX(domain)
        return records.map { (preference: $0.preference, exchange: $0.exchange) }
    }
    
    /// Quick CNAME record lookup
    public static func lookupCNAME(_ domain: String) async throws -> [String] {
        let resolver = createResolver()
        let records = try await resolver.resolveCNAME(domain)
        return records.map { $0.canonicalName }
    }
    
    /// Quick TXT record lookup
    public static func lookupTXT(_ domain: String) async throws -> [[String]] {
        let resolver = createResolver()
        let records = try await resolver.resolveTXT(domain)
        return records.map { $0.strings }
    }
}

// MARK: - Re-exports

// All types are already public and accessible through the module
// No need for typealias declarations as they create circular references
