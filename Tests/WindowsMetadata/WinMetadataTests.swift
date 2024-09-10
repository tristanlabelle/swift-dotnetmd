@testable import DotNetMetadata
import WindowsMetadata
import DotNetMetadataFormat
import struct Foundation.UUID
import XCTest

final class WinMetadataTests: XCTestCase {
    internal static var context: AssemblyLoadContext!
    internal static var mscorlib: Assembly!
    internal static var assembly: Assembly!

    override class func setUp() {
        guard let windowsFoundationPath = SystemAssemblies.WinMetadata.windowsFoundationPath else { return }
        let url = URL(fileURLWithPath: windowsFoundationPath)

        context = WinMDLoadContext()
        // Resolve the mscorlib dependency from the .NET Framework 4 machine installation
        if let mscorlibPath = SystemAssemblies.DotNetFramework4.mscorlibPath {
            mscorlib = try? context.load(path: mscorlibPath)
        }
        assembly = try? context.load(url: url)
    }

    override func setUpWithError() throws {
        try XCTSkipIf(Self.assembly == nil, "System Windows.Foundation.winmd not found")
    }

    func testMscorlibTypeReference() throws {
        let pointTypeDefinition = try XCTUnwrap(Self.assembly.resolveTypeDefinition(fullName: "Windows.Foundation.Point"))
        XCTAssertEqual(
            try XCTUnwrap(pointTypeDefinition.base).definition.fullName,
            "System.ValueType")
    }

    func testParameterizedInterfaceID() throws {
        let iasyncOperation = try XCTUnwrap(Self.assembly.resolveTypeDefinition(fullName: "Windows.Foundation.IAsyncOperation`1") as? InterfaceDefinition)
        XCTAssertEqual(
            try WindowsMetadata.getInterfaceID(iasyncOperation, genericArgs: [try Self.context.coreLibrary.systemBoolean.bindNode()]),
            UUID(uuidString: "cdb5efb3-5788-509d-9be1-71ccb8a3362a"))
    }
}
