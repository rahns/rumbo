import Foundation
import Testing
@testable import RumboCore

@Suite struct BackupContainerTests {
    let payload = Data((0..<500).map { UInt8($0 % 251) })

    @Test func wrapsAndUnwraps() throws {
        let file = BackupContainer.wrap(payload)
        #expect(file.prefix(5) == Data("RUMBO".utf8))
        #expect(file.count == payload.count + 14)
        #expect(try BackupContainer.unwrap(file) == payload)
        #expect(try BackupContainer.unwrap(BackupContainer.wrap(Data())) == Data())
    }

    @Test func theChecksumIsStandardCRC32() {
        #expect(BackupContainer.crc32(Data("123456789".utf8)) == 0xCBF4_3926)
        #expect(BackupContainer.crc32(Data()) == 0)
    }

    @Test func anyChangedByteIsCaught() {
        let file = BackupContainer.wrap(payload)
        for index in stride(from: 6, to: file.count, by: 7) {
            var edited = file
            edited[edited.startIndex + index] ^= 0x01
            #expect(throws: BackupContainer.Failure.self) { try BackupContainer.unwrap(edited) }
        }
        var flipped = file
        flipped[flipped.startIndex + 200] ^= 0x40
        #expect(throws: BackupContainer.Failure.damaged) { try BackupContainer.unwrap(flipped) }
    }

    @Test func cutShortOrPaddedFilesAreDamaged() {
        let file = BackupContainer.wrap(payload)
        #expect(throws: BackupContainer.Failure.damaged) { try BackupContainer.unwrap(file.dropLast()) }
        #expect(throws: BackupContainer.Failure.damaged) { try BackupContainer.unwrap(file + Data([0])) }
        #expect(throws: BackupContainer.Failure.damaged) { try BackupContainer.unwrap(file.prefix(8)) }
    }

    @Test func oldJSONBackupsAndOtherFilesAreNotBackups() {
        let oldBackup = Data(#"{"version": 2, "profile": {"displayName": "Rahn"}}"#.utf8)
        #expect(throws: BackupContainer.Failure.notABackup) { try BackupContainer.unwrap(oldBackup) }
        #expect(throws: BackupContainer.Failure.notABackup) { try BackupContainer.unwrap(Data()) }
        #expect(throws: BackupContainer.Failure.notABackup) { try BackupContainer.unwrap(Data("RUMB".utf8)) }
    }

    @Test func aNewerFormatIsRecognised() {
        var file = BackupContainer.wrap(payload)
        file[file.startIndex + 5] = BackupContainer.formatVersion + 1
        #expect(throws: BackupContainer.Failure.newerFormat) { try BackupContainer.unwrap(file) }
    }
}
