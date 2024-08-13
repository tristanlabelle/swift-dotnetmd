@testable import WindowsMetadata
import XCTest

final class WindowsKitTests: XCTestCase {
    public func testReadApplicationPlatformXml() throws {
        let kits = try WindowsKit.getInstalled()
        try XCTSkipIf(kits.isEmpty, "No Windows Kits found")

        let applicationPlatform = try kits[0].readApplicationPlatform()
        XCTAssertNotNil(applicationPlatform.apiContracts["Windows.Foundation.UniversalApiContract"])
    }

    public func testReadExtensionManifestXml() throws {
        let kits = try WindowsKit.getInstalled()
        try XCTSkipIf(kits.isEmpty, "No Windows Kits found")

        let desktopExtension = try XCTUnwrap(kits[0].extensions.first { $0.name == "WindowsDesktop" })
        let manifest = try desktopExtension.readManifest()
        XCTAssertEqual(manifest.productFamilyName, "Windows.Desktop")
    }
}