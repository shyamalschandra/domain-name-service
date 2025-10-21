import Foundation
import NIOCore

/// DNS Message Codec for serializing and deserializing DNS messages according to RFC 1035
public struct DNSMessageCodec {
    private let compressionMap: [String: UInt16]
    
    public init(compressionMap: [String: UInt16] = [:]) {
        self.compressionMap = compressionMap
    }
    
    // MARK: - Serialization
    
    /// Serialize a DNS message to binary data
    public func serialize(_ message: DNSMessage) throws -> Data {
        var buffer = ByteBuffer()
        var compressionMap: [String: UInt16] = [:]
        
        // Serialize header
        try serializeHeader(message.header, into: &buffer)
        
        // Serialize questions
        for question in message.questions {
            try serializeQuestion(question, into: &buffer, compressionMap: &compressionMap)
        }
        
        // Serialize answers
        for answer in message.answers {
            try serializeResourceRecord(answer, into: &buffer, compressionMap: &compressionMap)
        }
        
        // Serialize authority records
        for authority in message.authority {
            try serializeResourceRecord(authority, into: &buffer, compressionMap: &compressionMap)
        }
        
        // Serialize additional records
        for additional in message.additional {
            try serializeResourceRecord(additional, into: &buffer, compressionMap: &compressionMap)
        }
        
        return Data(buffer.readableBytesView)
    }
    
    func serializeHeader(_ header: DNSHeader, into buffer: inout ByteBuffer) throws {
        // ID (16 bits)
        buffer.writeInteger(header.id, endianness: .big)
        
        // Flags (16 bits)
        var flags: UInt16 = 0
        if header.isResponse { flags |= 0x8000 }
        flags |= UInt16(header.opcode.rawValue) << 11
        if header.isAuthoritative { flags |= 0x0400 }
        if header.isTruncated { flags |= 0x0200 }
        if header.recursionDesired { flags |= 0x0100 }
        if header.recursionAvailable { flags |= 0x0080 }
        flags |= UInt16(header.z) << 4
        flags |= UInt16(header.responseCode.rawValue)
        
        buffer.writeInteger(flags, endianness: .big)
        
        // Counts
        buffer.writeInteger(header.questionCount, endianness: .big)
        buffer.writeInteger(header.answerCount, endianness: .big)
        buffer.writeInteger(header.authorityCount, endianness: .big)
        buffer.writeInteger(header.additionalCount, endianness: .big)
    }
    
    func serializeQuestion(_ question: DNSQuestion, into buffer: inout ByteBuffer, compressionMap: inout [String: UInt16]) throws {
        try serializeDomainName(question.name, into: &buffer, compressionMap: &compressionMap)
        buffer.writeInteger(question.type.rawValue, endianness: .big)
        buffer.writeInteger(question.class.rawValue, endianness: .big)
    }
    
    func serializeResourceRecord(_ record: DNSResourceRecord, into buffer: inout ByteBuffer, compressionMap: inout [String: UInt16]) throws {
        try serializeDomainName(record.name, into: &buffer, compressionMap: &compressionMap)
        buffer.writeInteger(record.type.rawValue, endianness: .big)
        buffer.writeInteger(record.class.rawValue, endianness: .big)
        buffer.writeInteger(record.ttl, endianness: .big)
        buffer.writeInteger(record.rdLength, endianness: .big)
        buffer.writeData(record.rdata)
    }
    
    func serializeDomainName(_ name: String, into buffer: inout ByteBuffer, compressionMap: inout [String: UInt16]) throws {
        // For now, let's disable compression to avoid the complex issues
        // This will make the messages larger but more reliable
        let labels = name.components(separatedBy: ".")
        
        for label in labels {
            let labelData = label.data(using: .utf8) ?? Data()
            if labelData.count > 63 {
                throw DNSError.invalidLabelLength
            }
            
            buffer.writeInteger(UInt8(labelData.count), endianness: .big)
            buffer.writeData(labelData)
        }
        
        // Write null terminator
        buffer.writeInteger(UInt8(0), endianness: .big)
    }
    
    // MARK: - Deserialization
    
    /// Deserialize binary data to a DNS message
    public func deserialize(_ data: Data) throws -> DNSMessage {
        var buffer = ByteBuffer(data: data)
        
        // Deserialize header
        let header = try deserializeHeader(from: &buffer)
        
        // Deserialize questions
        var questions: [DNSQuestion] = []
        for _ in 0..<header.questionCount {
            let question = try deserializeQuestion(from: &buffer)
            questions.append(question)
        }
        
        // Deserialize answers
        var answers: [DNSResourceRecord] = []
        for _ in 0..<header.answerCount {
            let answer = try deserializeResourceRecord(from: &buffer)
            answers.append(answer)
        }
        
        // Deserialize authority records
        var authority: [DNSResourceRecord] = []
        for _ in 0..<header.authorityCount {
            let authorityRecord = try deserializeResourceRecord(from: &buffer)
            authority.append(authorityRecord)
        }
        
        // Deserialize additional records
        var additional: [DNSResourceRecord] = []
        for _ in 0..<header.additionalCount {
            let additionalRecord = try deserializeResourceRecord(from: &buffer)
            additional.append(additionalRecord)
        }
        
        return DNSMessage(
            header: header,
            questions: questions,
            answers: answers,
            authority: authority,
            additional: additional
        )
    }
    
    func deserializeHeader(from buffer: inout ByteBuffer) throws -> DNSHeader {
        guard let id = buffer.readInteger(endianness: .big, as: UInt16.self),
              let flags = buffer.readInteger(endianness: .big, as: UInt16.self),
              let questionCount = buffer.readInteger(endianness: .big, as: UInt16.self),
              let answerCount = buffer.readInteger(endianness: .big, as: UInt16.self),
              let authorityCount = buffer.readInteger(endianness: .big, as: UInt16.self),
              let additionalCount = buffer.readInteger(endianness: .big, as: UInt16.self) else {
            throw DNSError.invalidMessageFormat
        }
        
        let isResponse = (flags & 0x8000) != 0
        let opcode = DNSOpcode(rawValue: UInt8((flags >> 11) & 0x0F)) ?? .query
        let isAuthoritative = (flags & 0x0400) != 0
        let isTruncated = (flags & 0x0200) != 0
        let recursionDesired = (flags & 0x0100) != 0
        let recursionAvailable = (flags & 0x0080) != 0
        let z = UInt8((flags >> 4) & 0x07)
        let responseCode = DNSResponseCode(rawValue: UInt8(flags & 0x0F)) ?? .noError
        
        return DNSHeader(
            id: id,
            isResponse: isResponse,
            opcode: opcode,
            isAuthoritative: isAuthoritative,
            isTruncated: isTruncated,
            recursionDesired: recursionDesired,
            recursionAvailable: recursionAvailable,
            z: z,
            responseCode: responseCode,
            questionCount: questionCount,
            answerCount: answerCount,
            authorityCount: authorityCount,
            additionalCount: additionalCount
        )
    }
    
    func deserializeQuestion(from buffer: inout ByteBuffer) throws -> DNSQuestion {
        let name = try deserializeDomainName(from: &buffer)
        
        guard let type = buffer.readInteger(endianness: .big, as: UInt16.self),
              let `class` = buffer.readInteger(endianness: .big, as: UInt16.self) else {
            throw DNSError.invalidMessageFormat
        }
        
        return DNSQuestion(
            name: name,
            type: DNSRecordType(rawValue: type) ?? .a,
            class: DNSRecordClass(rawValue: `class`) ?? .internet
        )
    }
    
    func deserializeResourceRecord(from buffer: inout ByteBuffer) throws -> DNSResourceRecord {
        let name = try deserializeDomainName(from: &buffer)
        
        guard let type = buffer.readInteger(endianness: .big, as: UInt16.self),
              let `class` = buffer.readInteger(endianness: .big, as: UInt16.self),
              let ttl = buffer.readInteger(endianness: .big, as: UInt32.self),
              let rdLength = buffer.readInteger(endianness: .big, as: UInt16.self) else {
            throw DNSError.invalidMessageFormat
        }
        
        guard let rdata = buffer.readData(length: Int(rdLength)) else {
            throw DNSError.invalidMessageFormat
        }
        
        return DNSResourceRecord(
            name: name,
            type: DNSRecordType(rawValue: type) ?? .a,
            class: DNSRecordClass(rawValue: `class`) ?? .internet,
            ttl: ttl,
            rdata: rdata
        )
    }
    
    func deserializeDomainName(from buffer: inout ByteBuffer) throws -> String {
        var labels: [String] = []
        
        while true {
            guard let labelLength = buffer.readInteger(endianness: .big, as: UInt8.self) else {
                throw DNSError.invalidMessageFormat
            }
            
            // Check for compression pointer
            if (labelLength & 0xC0) == 0xC0 {
                guard let pointer = buffer.readInteger(endianness: .big, as: UInt16.self) else {
                    throw DNSError.invalidMessageFormat
                }
                
                let offset = Int(pointer & 0x3FFF)
                let compressedName = try deserializeDomainNameFromOffset(offset, in: buffer)
                return compressedName
            }
            
            // End of domain name
            if labelLength == 0 {
                break
            }
            
            // Read label data
            guard let labelData = buffer.readData(length: Int(labelLength)) else {
                throw DNSError.invalidMessageFormat
            }
            
            guard let label = String(data: labelData, encoding: .utf8) else {
                throw DNSError.invalidMessageFormat
            }
            
            labels.append(label)
        }
        
        return labels.joined(separator: ".")
    }
    
    private func deserializeDomainNameFromOffset(_ offset: Int, in buffer: ByteBuffer) throws -> String {
        var labels: [String] = []
        var position = offset
        
        while true {
            guard position < buffer.writerIndex else {
                throw DNSError.invalidMessageFormat
            }
            
            guard let labelLength = buffer.getInteger(at: position, endianness: .big, as: UInt8.self) else {
                throw DNSError.invalidMessageFormat
            }
            
            // Check for compression pointer
            if (labelLength & 0xC0) == 0xC0 {
                guard let pointer = buffer.getInteger(at: position, endianness: .big, as: UInt16.self) else {
                    throw DNSError.invalidMessageFormat
                }
                
                let newOffset = Int(pointer & 0x3FFF)
                let compressedName = try deserializeDomainNameFromOffset(newOffset, in: buffer)
                labels.append(compressedName)
                break
            }
            
            // End of domain name
            if labelLength == 0 {
                break
            }
            
            // Read label data
            guard let labelData = buffer.getData(at: position + 1, length: Int(labelLength)) else {
                throw DNSError.invalidMessageFormat
            }
            
            guard let label = String(data: labelData, encoding: .utf8) else {
                throw DNSError.invalidMessageFormat
            }
            
            labels.append(label)
            position += Int(labelLength) + 1
        }
        
        return labels.joined(separator: ".")
    }
}

// MARK: - DNS Error

public enum DNSError: Error, LocalizedError {
    case invalidMessageFormat
    case invalidLabelLength
    case compressionError
    case unsupportedRecordType
    case invalidDomainName
    case nameError
    
    public var errorDescription: String? {
        switch self {
        case .invalidMessageFormat:
            return "Invalid DNS message format"
        case .invalidLabelLength:
            return "Invalid label length (must be 0-63 characters)"
        case .compressionError:
            return "DNS message compression error"
        case .unsupportedRecordType:
            return "Unsupported DNS record type"
        case .invalidDomainName:
            return "Invalid domain name format"
        case .nameError:
            return "Domain name not found"
        }
    }
}
