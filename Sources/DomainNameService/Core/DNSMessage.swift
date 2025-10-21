import Foundation
import NIOCore

/// DNS Message as defined in RFC 1035 Section 4.1
public struct DNSMessage: Sendable {
    /// DNS Message Header
    public var header: DNSHeader
    
    /// Question section - contains the question for the name server
    public var questions: [DNSQuestion]
    
    /// Answer section - contains RRs answering the question
    public var answers: [DNSResourceRecord]
    
    /// Authority section - contains RRs pointing toward an authority
    public var authority: [DNSResourceRecord]
    
    /// Additional section - contains RRs which may be helpful in using the RRs in the other sections
    public var additional: [DNSResourceRecord]
    
    public init(
        header: DNSHeader = DNSHeader(),
        questions: [DNSQuestion] = [],
        answers: [DNSResourceRecord] = [],
        authority: [DNSResourceRecord] = [],
        additional: [DNSResourceRecord] = []
    ) {
        // Update header counts to match the arrays
        var updatedHeader = header
        updatedHeader.questionCount = UInt16(questions.count)
        updatedHeader.answerCount = UInt16(answers.count)
        updatedHeader.authorityCount = UInt16(authority.count)
        updatedHeader.additionalCount = UInt16(additional.count)
        
        self.header = updatedHeader
        self.questions = questions
        self.answers = answers
        self.authority = authority
        self.additional = additional
    }
}

// MARK: - DNS Header

/// DNS Message Header as defined in RFC 1035 Section 4.1.1
public struct DNSHeader: Sendable {
    /// A 16 bit identifier assigned by the program that generates any kind of query
    public var id: UInt16
    
    /// Query/Response flag (0 = query, 1 = response)
    public var isResponse: Bool
    
    /// Kind of query (0 = standard query, 1 = inverse query, 2 = server status request)
    public var opcode: DNSOpcode
    
    /// Authoritative Answer - this bit is valid in responses
    public var isAuthoritative: Bool
    
    /// Truncation - specifies that this message was truncated
    public var isTruncated: Bool
    
    /// Recursion Desired - this bit directs the name server to pursue the query recursively
    public var recursionDesired: Bool
    
    /// Recursion Available - this be is set or cleared in a response
    public var recursionAvailable: Bool
    
    /// Reserved for future use - must be zero
    public var z: UInt8
    
    /// Response code - this 4 bit field is set as part of responses
    public var responseCode: DNSResponseCode
    
    /// Number of entries in the question section
    public var questionCount: UInt16
    
    /// Number of resource records in the answer section
    public var answerCount: UInt16
    
    /// Number of name server resource records in the authority records section
    public var authorityCount: UInt16
    
    /// Number of resource records in the additional records section
    public var additionalCount: UInt16
    
    public init(
        id: UInt16 = 0,
        isResponse: Bool = false,
        opcode: DNSOpcode = .query,
        isAuthoritative: Bool = false,
        isTruncated: Bool = false,
        recursionDesired: Bool = false,
        recursionAvailable: Bool = false,
        z: UInt8 = 0,
        responseCode: DNSResponseCode = .noError,
        questionCount: UInt16 = 0,
        answerCount: UInt16 = 0,
        authorityCount: UInt16 = 0,
        additionalCount: UInt16 = 0
    ) {
        self.id = id
        self.isResponse = isResponse
        self.opcode = opcode
        self.isAuthoritative = isAuthoritative
        self.isTruncated = isTruncated
        self.recursionDesired = recursionDesired
        self.recursionAvailable = recursionAvailable
        self.z = z
        self.responseCode = responseCode
        self.questionCount = questionCount
        self.answerCount = answerCount
        self.authorityCount = authorityCount
        self.additionalCount = additionalCount
    }
}

// MARK: - DNS Opcode

/// DNS Opcode as defined in RFC 1035 Section 4.1.1
public enum DNSOpcode: UInt8, CaseIterable, Sendable {
    case query = 0
    case inverseQuery = 1
    case status = 2
    
    // Reserved values 3-15
}

// MARK: - DNS Response Code

/// DNS Response Code as defined in RFC 1035 Section 4.1.1
public enum DNSResponseCode: UInt8, CaseIterable, Sendable {
    case noError = 0
    case formatError = 1
    case serverFailure = 2
    case nameError = 3
    case notImplemented = 4
    case refused = 5
    
    // Reserved values 6-15
}

// MARK: - DNS Question

/// DNS Question as defined in RFC 1035 Section 4.1.2
public struct DNSQuestion: Sendable {
    /// A domain name represented as a sequence of labels
    public var name: String
    
    /// A two octet code which specifies the type of the query
    public var type: DNSRecordType
    
    /// A two octet code that specifies the class of the query
    public var `class`: DNSRecordClass
    
    public init(name: String, type: DNSRecordType, class: DNSRecordClass = .internet) {
        self.name = name
        self.type = type
        self.class = `class`
    }
}

// MARK: - DNS Record Type

/// DNS Record Type as defined in RFC 1035 Section 3.2.2
public enum DNSRecordType: UInt16, CaseIterable, Sendable {
    case a = 1
    case ns = 2
    case md = 3      // Obsolete
    case mf = 4      // Obsolete
    case cname = 5
    case soa = 6
    case mb = 7      // Experimental
    case mg = 8      // Experimental
    case mr = 9      // Experimental
    case null = 10   // Experimental
    case wks = 11
    case ptr = 12
    case hinfo = 13
    case minfo = 14  // Experimental
    case mx = 15
    case txt = 16
    case aaaa = 28
    case srv = 33
    case opt = 41
    case any = 255
}

// MARK: - DNS Record Class

/// DNS Record Class as defined in RFC 1035 Section 3.2.4
public enum DNSRecordClass: UInt16, CaseIterable, Sendable {
    case internet = 1
    case chaos = 3
    case hesiod = 4
    case any = 255
}

// MARK: - DNS Resource Record

/// DNS Resource Record as defined in RFC 1035 Section 3.2.1
public struct DNSResourceRecord: Sendable {
    /// A domain name to which this resource record pertains
    public var name: String
    
    /// Two octets containing one of the RR type codes
    public var type: DNSRecordType
    
    /// Two octets which specify the class of the data in the RDATA field
    public var `class`: DNSRecordClass
    
    /// A 32 bit unsigned integer that specifies the time interval (in seconds) that the resource record may be cached
    public var ttl: UInt32
    
    /// An unsigned 16 bit integer that specifies the length in octets of the RDATA field
    public var rdLength: UInt16
    
    /// A variable length string of octets that describes the resource
    public var rdata: Data
    
    public init(
        name: String,
        type: DNSRecordType,
        class: DNSRecordClass = .internet,
        ttl: UInt32 = 0,
        rdata: Data = Data()
    ) {
        self.name = name
        self.type = type
        self.class = `class`
        self.ttl = ttl
        self.rdLength = UInt16(rdata.count)
        self.rdata = rdata
    }
}
