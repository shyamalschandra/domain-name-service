import Foundation
import NIOCore
import NIOPosix
import NIOTransportServices
import Logging

/// DNS Transport Protocol
public protocol DNSTransport {
    func send(_ message: DNSMessage, to address: SocketAddress) async throws -> DNSMessage
    func close() async throws
}

/// DNS UDP Transport as defined in RFC 1035 Section 4.2.1
public final class DNSUDPTransport: DNSTransport, @unchecked Sendable {
    private let eventLoopGroup: EventLoopGroup
    private let bootstrap: DatagramBootstrap
    private let channel: Channel
    private let logger: Logger
    
    public init(eventLoopGroup: EventLoopGroup? = nil, logger: Logger = Logger(label: "dns.udp")) throws {
        self.eventLoopGroup = eventLoopGroup ?? NIOPosix.MultiThreadedEventLoopGroup.singleton
        self.logger = logger
        
        self.bootstrap = DatagramBootstrap(group: self.eventLoopGroup)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(DNSMessageHandler())
            }
        
        self.channel = try bootstrap.bind(host: "0.0.0.0", port: 0).wait()
    }
    
    public func send(_ message: DNSMessage, to address: SocketAddress) async throws -> DNSMessage {
        let codec = DNSMessageCodec()
        let data = try codec.serialize(message)
        
        logger.debug("Sending DNS message to \(address)")
        
        let response = try await withCheckedThrowingContinuation { continuation in
            let future = channel.writeAndFlush(AddressedEnvelope(remoteAddress: address, data: data))
                .flatMap { _ in
                    // Wait for response
                    return self.channel.pipeline.handler(type: DNSMessageHandler.self).flatMap { handler in
                        handler.responsePromise.futureResult
                    }
                }
            
            future.whenComplete { result in
                continuation.resume(with: result)
            }
        }
        
        return response
    }
    
    public func close() async throws {
        try await channel.close()
    }
}

/// DNS TCP Transport as defined in RFC 1035 Section 4.2.2
public final class DNSTCPTransport: DNSTransport, @unchecked Sendable {
    private let eventLoopGroup: EventLoopGroup
    private let bootstrap: ClientBootstrap
    private let logger: Logger
    
    public init(eventLoopGroup: EventLoopGroup? = nil, logger: Logger = Logger(label: "dns.tcp")) throws {
        self.eventLoopGroup = eventLoopGroup ?? NIOPosix.MultiThreadedEventLoopGroup.singleton
        self.logger = logger
        
        self.bootstrap = ClientBootstrap(group: self.eventLoopGroup)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(DNSMessageHandler())
            }
    }
    
    public func send(_ message: DNSMessage, to address: SocketAddress) async throws -> DNSMessage {
        let codec = DNSMessageCodec()
        let data = try codec.serialize(message)
        
        // For TCP, we need to prepend the message length
        let tcpData = {
            var result = Data()
            result.append(UInt8(data.count >> 8))
            result.append(UInt8(data.count & 0xFF))
            result.append(data)
            return result
        }()
        
        logger.debug("Sending DNS message via TCP to \(address)")
        
        let response = try await withCheckedThrowingContinuation { continuation in
            let connectFuture = bootstrap.connect(to: address)
            
            connectFuture.flatMap { channel in
                channel.writeAndFlush(ByteBuffer(data: tcpData))
                    .flatMap { _ in
                        // Wait for response
                        return channel.pipeline.handler(type: DNSMessageHandler.self).flatMap { handler in
                            handler.responsePromise.futureResult
                        }
                    }
                    .always { _ in
                        _ = channel.close()
                    }
            }.whenComplete { result in
                continuation.resume(with: result)
            }
        }
        
        return response
    }
    
    public func close() async throws {
        // TCP connections are closed after each request
    }
}

/// DNS Message Handler for processing incoming DNS messages
private final class DNSMessageHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias OutboundOut = AddressedEnvelope<ByteBuffer>
    
    let responsePromise: EventLoopPromise<DNSMessage>
    
    init() {
        self.responsePromise = MultiThreadedEventLoopGroup.currentEventLoop!.makePromise()
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        do {
            let codec = DNSMessageCodec()
            let message: DNSMessage
            
            // Try to handle as AddressedEnvelope<ByteBuffer> first
            do {
                let envelope = unwrapInboundIn(data)
                let buffer = envelope.data
                message = try codec.deserialize(Data(buffer.readableBytesView))
            } catch {
                // If that fails, the data might be AddressedEnvelope<Data>
                // We need to handle this case differently
                // For now, let's just fail with a more descriptive error
                responsePromise.fail(DNSError.invalidMessageFormat)
                return
            }
            
            responsePromise.succeed(message)
        } catch {
            responsePromise.fail(error)
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        responsePromise.fail(error)
        context.close(promise: nil)
    }
}

/// DNS Transport Factory
public class DNSTransportFactory {
    public static func createUDPTransport(eventLoopGroup: EventLoopGroup? = nil, logger: Logger = Logger(label: "dns.udp")) throws -> DNSUDPTransport {
        return try DNSUDPTransport(eventLoopGroup: eventLoopGroup, logger: logger)
    }
    
    public static func createTCPTransport(eventLoopGroup: EventLoopGroup? = nil, logger: Logger = Logger(label: "dns.tcp")) throws -> DNSTCPTransport {
        return try DNSTCPTransport(eventLoopGroup: eventLoopGroup, logger: logger)
    }
}

/// DNS Transport Configuration
public struct DNSTransportConfig {
    public let timeout: TimeInterval
    public let retryCount: Int
    public let useTCP: Bool
    public let useUDP: Bool
    
    public init(
        timeout: TimeInterval = 5.0,
        retryCount: Int = 3,
        useTCP: Bool = true,
        useUDP: Bool = true
    ) {
        self.timeout = timeout
        self.retryCount = retryCount
        self.useTCP = useTCP
        self.useUDP = useUDP
    }
}

/// DNS Transport Manager
public class DNSTransportManager {
    private let config: DNSTransportConfig
    private let logger: Logger
    private var udpTransport: DNSUDPTransport?
    private var tcpTransport: DNSTCPTransport?
    
    public init(config: DNSTransportConfig = DNSTransportConfig(), logger: Logger = Logger(label: "dns.transport")) {
        self.config = config
        self.logger = logger
    }
    
    public func send(_ message: DNSMessage, to address: SocketAddress) async throws -> DNSMessage {
        // Try UDP first if available
        if config.useUDP {
            do {
                if udpTransport == nil {
                    udpTransport = try DNSTransportFactory.createUDPTransport(logger: logger)
                }
                return try await udpTransport!.send(message, to: address)
            } catch {
                logger.warning("UDP transport failed, falling back to TCP: \(error)")
            }
        }
        
        // Fall back to TCP
        if config.useTCP {
            tcpTransport = try DNSTransportFactory.createTCPTransport(logger: logger)
            return try await tcpTransport!.send(message, to: address)
        }
        
        throw DNSError.transportError("No available transport protocol")
    }
    
    public func close() async throws {
        try await udpTransport?.close()
        try await tcpTransport?.close()
    }
}

// MARK: - DNS Transport Error

extension DNSError {
    static func transportError(_ message: String) -> DNSError {
        return .invalidMessageFormat // Reuse existing error for now
    }
}
