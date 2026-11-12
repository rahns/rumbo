import Foundation

/// The outer layer of a backup file (`.rumbo`): a marker, a format version, the payload's length and a
/// CRC-32 checksum, then the payload (the app's backup JSON, compressed). It isn't encryption: it keeps the
/// file from being readable or editable as text, and any change to the payload is caught by the checksum.
/// See docs/04-data-model.md §4.3.
///
/// Layout (big-endian): "RUMBO" (5 bytes) · format version (1 byte) · payload length (4 bytes) ·
/// CRC-32 of the payload (4 bytes) · payload.
public enum BackupContainer {
    public static let magic = Data("RUMBO".utf8)
    public static let formatVersion: UInt8 = 1
    static let headerSize = 5 + 1 + 4 + 4

    public enum Failure: Error, Equatable {
        /// Not a Rumbo backup at all (including the old plain-JSON backups).
        case notABackup
        /// Made by a newer version of Rumbo.
        case newerFormat
        /// The right kind of file, but changed or cut short since it was saved.
        case damaged
    }

    public static func wrap(_ payload: Data) -> Data {
        var data = magic
        data.append(formatVersion)
        data.append(bigEndian: UInt32(payload.count))
        data.append(bigEndian: crc32(payload))
        data.append(payload)
        return data
    }

    public static func unwrap(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        guard bytes.count >= magic.count, Data(bytes.prefix(magic.count)) == magic else { throw Failure.notABackup }
        guard bytes.count >= headerSize else { throw Failure.damaged }
        guard bytes[5] <= formatVersion else { throw Failure.newerFormat }
        let length = Int(readUInt32(bytes, at: 6))
        let checksum = readUInt32(bytes, at: 10)
        guard bytes.count - headerSize == length else { throw Failure.damaged }
        let payload = Data(bytes[headerSize...])
        guard crc32(payload) == checksum else { throw Failure.damaged }
        return payload
    }

    /// CRC-32 (IEEE 802.3, as in zip and PNG).
    public static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        bytes[offset..<(offset + 4)].reduce(0) { ($0 << 8) | UInt32($1) }
    }
}

private extension Data {
    mutating func append(bigEndian value: UInt32) {
        append(contentsOf: [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)])
    }
}
