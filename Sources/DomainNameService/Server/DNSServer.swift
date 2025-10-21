import Foundation
import NIOCore
import NIOPosix
import Logging

/// DNS Name Server as defined in RFC 1035 Section 6
public class DNSServer {
    private let eventLoopGroup: EventLoopGroup
    private let bootstrap: DatagramBootstrap
    private let channel: Channel
    private let logger: Logger
    private let zoneManager: DNSZoneManager
    
    public init(
        eventLoopGroup: EventLoopGroup? = nil,
        zoneManager: DNSZoneManager? = nil,
        logger: Logger = Logger(label: "dns.server")
    ) throws {
        self.eventLoopGroup = eventLoopGroup ?? NIOPosix.MultiThreadedEventLoopGroup.singleton
        self.zoneManager = zoneManager ?? DNSZoneManager()
        self.logger = logger
        
        // Create bootstrap without capturing self
        let zoneManager = self.zoneManager
        let logger = self.logger
        
        let bootstrap = DatagramBootstrap(group: self.eventLoopGroup)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(DNSServerHandler(zoneManager: zoneManager, logger: logger))
            }
        
        self.bootstrap = bootstrap
        self.channel = try bootstrap.bind(host: "0.0.0.0", port: 53).wait()
    }
    
    public func start() async throws {
        logger.info("DNS Server started on port 53")
        try await channel.closeFuture
    }
    
    public func stop() async throws {
        try await channel.close()
    }
}

/// DNS Server Handler
private class DNSServerHandler: ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias OutboundOut = AddressedEnvelope<ByteBuffer>
    
    private let zoneManager: DNSZoneManager
    private let logger: Logger
    
    init(zoneManager: DNSZoneManager, logger: Logger) {
        self.zoneManager = zoneManager
        self.logger = logger
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = unwrapInboundIn(data)
        let buffer = envelope.data
        
        do {
            let codec = DNSMessageCodec()
            let request = try codec.deserialize(Data(buffer.readableBytesView))
            
            logger.debug("Received DNS query: \(request.questions.first?.name ?? "unknown")")
            
            let response = try processQuery(request)
            let responseData = try codec.serialize(response)
            
            let responseEnvelope = AddressedEnvelope(remoteAddress: envelope.remoteAddress, data: ByteBuffer(data: responseData))
            context.writeAndFlush(wrapOutboundOut(responseEnvelope), promise: nil)
            
        } catch {
            logger.error("Failed to process DNS query: \(error)")
        }
    }
    
    private func processQuery(_ request: DNSMessage) throws -> DNSMessage {
        var response = DNSMessage()
        response.header = DNSHeader(
            id: request.header.id,
            isResponse: true,
            opcode: request.header.opcode,
            isAuthoritative: true,
            isTruncated: false,
            recursionDesired: request.header.recursionDesired,
            recursionAvailable: true,
            responseCode: .noError
        )
        
        for question in request.questions {
            let records = try zoneManager.lookup(domain: question.name, type: question.type, class: question.class)
            
            if !records.isEmpty {
                response.answers.append(contentsOf: records)
                response.header.answerCount = UInt16(records.count)
            } else {
                // Check for NS records for delegation
                let nsRecords = try zoneManager.lookup(domain: question.name, type: .ns, class: question.class)
                if !nsRecords.isEmpty {
                    response.authority.append(contentsOf: nsRecords)
                    response.header.authorityCount = UInt16(nsRecords.count)
                } else {
                    response.header.responseCode = .nameError
                }
            }
        }
        
        return response
    }
}

/// DNS Zone Manager
public class DNSZoneManager {
    public var zones: [String: DNSZone] = [:]
    private let queue = DispatchQueue(label: "dns.zone", attributes: .concurrent)
    
    public init() {}
    
    public func addZone(_ zone: DNSZone) {
        queue.async(flags: .barrier) {
            self.zones[zone.name] = zone
        }
    }
    
    public func removeZone(_ name: String) {
        queue.async(flags: .barrier) {
            self.zones.removeValue(forKey: name)
        }
    }
    
    public func lookup(domain: String, type: DNSRecordType, class: DNSRecordClass) throws -> [DNSResourceRecord] {
        return queue.sync {
            // Find the best matching zone
            var bestZone: DNSZone?
            var bestMatch = ""
            
            for (zoneName, zone) in zones {
                if domain.hasSuffix(zoneName) && zoneName.count > bestMatch.count {
                    bestZone = zone
                    bestMatch = zoneName
                }
            }
            
            guard let zone = bestZone else { return [] }
            
            // Look up records in the zone
            return zone.lookup(domain: domain, type: type, class: `class`)
        }
    }
}

/// DNS Zone
public class DNSZone {
    public let name: String
    public let soa: SOARecord
    private var records: [String: [DNSResourceRecord]] = [:]
    private let queue = DispatchQueue(label: "dns.zone.records", attributes: .concurrent)
    
    public init(name: String, soa: SOARecord) {
        self.name = name
        self.soa = soa
    }
    
    public func addRecord(_ record: DNSResourceRecord) {
        queue.async(flags: .barrier) {
            if self.records[record.name] == nil {
                self.records[record.name] = []
            }
            self.records[record.name]?.append(record)
        }
    }
    
    public func removeRecord(_ record: DNSResourceRecord) {
        queue.async(flags: .barrier) {
            self.records[record.name]?.removeAll { $0.name == record.name && $0.type == record.type }
        }
    }
    
    public func lookup(domain: String, type: DNSRecordType, class: DNSRecordClass) -> [DNSResourceRecord] {
        return queue.sync {
            guard let domainRecords = records[domain] else { return [] }
            return domainRecords.filter { $0.type == type && $0.class == `class` }
        }
    }
    
    public func getAllRecords() -> [DNSResourceRecord] {
        return queue.sync {
            return records.values.flatMap { $0 }
        }
    }
}

/// DNS Zone Builder
public class DNSZoneBuilder {
    private var zone: DNSZone?
    
    public init() {}
    
    public func createZone(name: String, soa: SOARecord) -> DNSZoneBuilder {
        self.zone = DNSZone(name: name, soa: soa)
        return self
    }
    
    public func addARecord(name: String, address: String, ttl: UInt32 = 3600) -> DNSZoneBuilder {
        guard let zone = zone else { return self }
        let aRecord = ARecord(address: IPv4Address(address))
        let record = DNSResourceRecord(
            name: name,
            type: .a,
            ttl: ttl,
            rdata: aRecord.rdata
        )
        zone.addRecord(record)
        return self
    }
    
    public func addAAAARecord(name: String, address: String, ttl: UInt32 = 3600) -> DNSZoneBuilder {
        guard let zone = zone else { return self }
        let aaaaRecord = AAAARecord(address: IPv6Address(address))
        let record = DNSResourceRecord(
            name: name,
            type: .aaaa,
            ttl: ttl,
            rdata: aaaaRecord.rdata
        )
        zone.addRecord(record)
        return self
    }
    
    public func addCNAMERecord(name: String, canonicalName: String, ttl: UInt32 = 3600) -> DNSZoneBuilder {
        guard let zone = zone else { return self }
        let cnameRecord = CNAMERecord(canonicalName: canonicalName)
        let record = DNSResourceRecord(
            name: name,
            type: .cname,
            ttl: ttl,
            rdata: cnameRecord.rdata
        )
        zone.addRecord(record)
        return self
    }
    
    public func addMXRecord(name: String, preference: UInt16, exchange: String, ttl: UInt32 = 3600) -> DNSZoneBuilder {
        guard let zone = zone else { return self }
        let mxRecord = MXRecord(preference: preference, exchange: exchange)
        let record = DNSResourceRecord(
            name: name,
            type: .mx,
            ttl: ttl,
            rdata: mxRecord.rdata
        )
        zone.addRecord(record)
        return self
    }
    
    public func addNSRecord(name: String, nameServer: String, ttl: UInt32 = 3600) -> DNSZoneBuilder {
        guard let zone = zone else { return self }
        let nsRecord = NSRecord(nameServer: nameServer)
        let record = DNSResourceRecord(
            name: name,
            type: .ns,
            ttl: ttl,
            rdata: nsRecord.rdata
        )
        zone.addRecord(record)
        return self
    }
    
    public func addTXTRecord(name: String, strings: [String], ttl: UInt32 = 3600) -> DNSZoneBuilder {
        guard let zone = zone else { return self }
        let txtRecord = TXTRecord(strings: strings)
        let record = DNSResourceRecord(
            name: name,
            type: .txt,
            ttl: ttl,
            rdata: txtRecord.rdata
        )
        zone.addRecord(record)
        return self
    }
    
    public func build() -> DNSZone? {
        return zone
    }
}

// MARK: - DNS Server Configuration

public struct DNSServerConfig {
    public let port: Int
    public let host: String
    public let maxConnections: Int
    public let timeout: TimeInterval
    
    public init(
        port: Int = 53,
        host: String = "0.0.0.0",
        maxConnections: Int = 1000,
        timeout: TimeInterval = 30.0
    ) {
        self.port = port
        self.host = host
        self.maxConnections = maxConnections
        self.timeout = timeout
    }
}
