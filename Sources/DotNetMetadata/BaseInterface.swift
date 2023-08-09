import DotNetMetadataFormat

public final class BaseInterface {
    internal unowned let inheritingTypeImpl: TypeDefinition.MetadataImpl
    internal let tableRowIndex: InterfaceImplTable.RowIndex

    init(inheritingTypeImpl: TypeDefinition.MetadataImpl, tableRowIndex: InterfaceImplTable.RowIndex) {
        self.inheritingTypeImpl = inheritingTypeImpl
        self.tableRowIndex = tableRowIndex
    }

    public var inheritingType: TypeDefinition { inheritingTypeImpl.owner }
    internal var assemblyImpl: MetadataAssemblyImpl { inheritingTypeImpl.assemblyImpl }
    internal var moduleFile: ModuleFile { inheritingTypeImpl.moduleFile }
    private var tableRow: InterfaceImplTable.Row { moduleFile.interfaceImplTable[tableRowIndex] }
    public var interface: BoundType { assemblyImpl.resolveOptionalBoundType(tableRow.interface, typeContext: inheritingType)! }

    public private(set) lazy var attributes: [Attribute] = {
        assemblyImpl.getAttributes(owner: .interfaceImpl(tableRowIndex))
    }()
}