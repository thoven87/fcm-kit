import Foundation
import NIOCore

// MARK: - FCMJSONDecoder

/// A type that can decode `Decodable` values from a `ByteBuffer`.
///
/// `JSONDecoder` conforms to this protocol out of the box.
/// Conform your own type to customise date strategies, key decoding, etc.
public protocol FCMJSONDecoder: Sendable {
    func decode<T: Decodable>(_ type: T.Type, from buffer: ByteBuffer) throws -> T
}

extension JSONDecoder: FCMJSONDecoder {
    public func decode<T: Decodable>(_ type: T.Type, from buffer: ByteBuffer) throws -> T {
        var copy = buffer
        // readBytes returns nil only when length > readableBytes, which cannot happen here.
        let bytes = copy.readBytes(length: buffer.readableBytes)!
        return try decode(type, from: Data(bytes))
    }
}

// MARK: - FCMJSONEncoder

/// A type that can encode `Encodable` values directly into a `ByteBuffer`.
///
/// `JSONEncoder` conforms to this protocol out of the box.
public protocol FCMJSONEncoder: Sendable {
    func encode<T: Encodable>(_ value: T, into buffer: inout ByteBuffer) throws
}

extension JSONEncoder: FCMJSONEncoder {
    public func encode<T: Encodable>(_ value: T, into buffer: inout ByteBuffer) throws {
        let data = try encode(value)
        buffer.writeBytes(data)
    }
}
