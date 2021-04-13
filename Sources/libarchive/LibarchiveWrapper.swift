//
//  LibarchiveWrapper.swift
//  libarchive
//
//  Created by Alex - SEEMOO on 21.07.20.
//

import Foundation
import LibArc

/// Struct that implements functions from libarchive that are necessary for AirDrop.
public struct Libarchive {

    // MARK: - Write

    /// Creates a CPIO and gzipped file (data) with the given file and it's filename. To archive a compete folder use the `archiveToCPIO` function.
    /// - Parameters:
    ///   - file: File that should be part of the CPIO
    ///   - filename: The file's name
    /// - Throws: If the archiving fails. The error contains the libarchive error code
    /// - Returns: CPIO data
    public static func createCPIO(with file: Data, filename: String) throws -> Data {

        // Create the output file path
        let output = NSTemporaryDirectory() + "archive.cpio"

        // Create a new archive
        let archive: OpaquePointer = archive_write_new()

        // Use gzip as the filter
        archive_write_add_filter_gzip(archive)

        // Use CPIO as the format
        archive_write_set_format_cpio(archive)

        // Store in file
        archive_write_open_filename(archive, output.cString(using: .utf8))

        // Create an entry for the file
        let entry: OpaquePointer = archive_entry_new()
        let name = filename.cString(using: .utf8)
        archive_entry_set_pathname(entry, name)
        archive_entry_set_size(entry, Int64(file.count))
        archive_entry_set_filetype(entry, FileType.regular.raw)
        archive_entry_set_perm(entry, 0999)

        archive_write_header(archive, entry)

        // Add the file
        var buffer = Array(file)
        archive_write_data(archive, &buffer, buffer.count)
        // Finish the entry
        archive_entry_free(entry)

        // Close the archive
        let error = archive_write_close(archive)
        archive_free(archive)

        guard error == 0 else {
            throw WriteError.archivingFailed(errorCode: Int(error))
        }

        // Open the file
        let data = try Data(contentsOf: URL(fileURLWithPath: output))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: output))

        return data
    }

    /// Archive a complete folder in a gzipped CPIO file
    /// - Parameter url: The url to the folder that should be archived
    /// - Throws: If the archiving fails. The error contains an error code.
    /// - Returns: CPIO formatted file.
    public static func archiveToCPIO(directory url: URL) throws -> Data {
        // Create the output file path
        let output = NSTemporaryDirectory() + "archive.cpio"

        // Create a new archive
        let archive: OpaquePointer = archive_write_new()

        // Use gzip as the filter
        archive_write_add_filter_gzip(archive)

        // Use CPIO as the format
        archive_write_set_format_cpio(archive)

        // Store in file
        archive_write_open_filename(archive, output.cString(using: .utf8))

        // Write to archive
        try writeToArchive2(archive, from: url)

        // Close the archive
        let error = archive_write_close(archive)
        archive_free(archive)

        guard error == 0 else {
            throw WriteError.archivingFailed(errorCode: Int(error))
        }

        // Open the file
        let data = try Data(contentsOf: URL(fileURLWithPath: output))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: output))

        return data
    }

    /// Write the folder at the URL to an archive. This function wraps all the code necessary to add multiple files and sub-folders in the directory to the archive.
    /// - Parameters:
    ///   - archive: A Libarchive archive
    ///   - url: URL to a local path that should be archived
    /// - Throws: If the archiving fails.
    internal static func writeToArchive2(_ archive: OpaquePointer, from url: URL) throws {
        let disk = archive_read_disk_new()

        var error = archive_read_disk_open(disk, url.path.cString(using: .utf8))
        guard error == ARCHIVE_OK else {
            throw WriteError.archivingFailed(errorCode: Int(error))
        }

        // Continue until all files and sub-folders have been archived.
        while true {
            let entry = archive_entry_new()
            error = archive_read_next_header2(disk, entry)
            if error == ARCHIVE_EOF {
                break
            }
            guard error == ARCHIVE_OK else {
                throw WriteError.archivingFailed(errorCode: Int(error))
            }
            archive_read_disk_descend(disk)

            // Set pathname to base path
            let basePath = url.deletingLastPathComponent().path + "/"

            var pathname = String(cString: archive_entry_pathname(entry))
            pathname = pathname.replacingOccurrences(of: basePath, with: "")
            archive_entry_set_pathname(entry, pathname.cString(using: .utf8))

            error = archive_write_header(archive, entry)

            //            let sourcePath = String(cString: archive_entry_sourcepath(entry))
            //            let data = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
            //            let buffer = Array(data)
            //            archive_write_data(archive, buffer, buffer.count)

            var buff = [UInt8](repeating: 0, count: 1024)
            let fd = open(archive_entry_sourcepath(entry), O_RDONLY)
            var len = read(fd, &buff, buff.count)
            while len > 0 {
                archive_write_data(archive, &buff, len)
                len = read(fd, &buff, buff.count)
            }
            close(fd)

            archive_entry_free(entry)
        }

        archive_read_close(disk)
        archive_read_free(disk)
    }

    // MARK: - Read

    /// Unarchive a CPIO formatted file (data).
    /// - Parameter cpio: CPIO formatted data
    /// - Throws: if unarchiving fails
    /// - Returns: The url at which the file or folder has been placed.
    public static func readCPIO(cpio: Data) throws -> URL {

        // Create archive to read
        let archive = archive_read_new()
        archive_read_support_filter_gzip(archive)
        archive_read_support_format_cpio(archive)

        let archiveBuffer = Array(cpio)
        let error = archive_read_open_memory(archive, archiveBuffer, archiveBuffer.count)

        guard error == ARCHIVE_OK else {
            throw ReadError.readFailed(code: Int(error))
        }

        let entry = archive_entry_new()

        // Prepare the unarchiving
        let exportDir = self.archiveExtractURL
        let ext = archive_write_disk_new()
        let flags =
            ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_PERM | ARCHIVE_EXTRACT_ACL
            | ARCHIVE_EXTRACT_FFLAGS

        archive_write_disk_set_options(ext, flags)
        archive_write_disk_set_standard_lookup(ext)

        // Read through each entries header.
        while archive_read_next_header2(archive, entry) == ARCHIVE_OK {
            // Set base pathname
            let pathname = String(cString: archive_entry_pathname(entry))
            let pathURL = exportDir.appendingPathComponent(pathname)
            archive_entry_set_pathname(entry, pathURL.path.cString(using: .utf8))

            // Write the entry to disk
            var error = archive_write_header(ext, entry)

            guard error == ARCHIVE_OK else {
                throw ReadError.readFailed(code: Int(error))
            }

            let size = archive_entry_size(entry)
            if size > 0 {
                try copyData(from: archive, to: ext, with: Int(size))
            }

            // Check if the entry has been handled correctly.
            error = archive_write_finish_entry(ext)
            guard error == ARCHIVE_OK else {
                throw ReadError.readFailed(code: Int(error))
            }

        }
        archive_read_close(archive)
        guard archive_read_free(archive) == ARCHIVE_OK else {
            throw ReadError.freeFailed
        }

        archive_write_close(ext)
        archive_write_free(ext)

        return exportDir
    }

    internal static func copyData(
        from readArchive: OpaquePointer?, to writeArchive: OpaquePointer?, with size: Int
    ) throws {

        var buffer = [UInt8](repeating: 0, count: size)

        var s = archive_read_data(readArchive, &buffer, size)

        s = archive_write_data(writeArchive, &buffer, size)
        guard s >= ARCHIVE_OK else {
            throw ReadError.readFailed(code: s)
        }

    }

    /// Directory used for storing unarchived data.
    internal static var archiveExtractURL: URL {
        let fm = FileManager.default
        var parentDir: URL!

        #if os(macOS)
            if let downloads = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                parentDir = downloads
            }
        #else
            if let documents = fm.urls(for: .documentDirectory, in: .allDomainsMask).first {
                // Create PrivateDrop directory
                parentDir = documents
            }
        #endif
        if parentDir == nil {
            parentDir = URL(fileURLWithPath: NSTemporaryDirectory())
        }

        let privateDropDir = parentDir.appendingPathComponent("PrivateDrop")
        try? fm.createDirectory(at: privateDropDir, withIntermediateDirectories: true, attributes: nil)
        return privateDropDir
    }

    public enum FileType {
        case blockSpecial
        case characterSpecial
        case fifoSpecial
        case regular
        case directory
        case symbolicLink

        var raw: UInt32 {
            switch self {
            case .blockSpecial:
                return UInt32(S_IFBLK)
            case .characterSpecial:
                return UInt32(S_IFCHR)
            case .fifoSpecial:
                return UInt32(S_IFIFO)
            case .directory:
                return UInt32(S_IFDIR)
            case .regular:
                return UInt32(S_IFREG)
            case .symbolicLink:
                return UInt32(S_IFLNK)
            }
        }
    }

    enum WriteError: Swift.Error {
        case archivingFailed(errorCode: Int)
    }

    enum ReadError: Swift.Error {
        case readFailed(code: Int)
        case freeFailed
    }
}
