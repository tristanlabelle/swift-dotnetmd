import WinMD

public final class Method {
    internal unowned let definingTypeImpl: TypeDefinition.MetadataImpl
    private let tableRowIndex: Table<WinMD.MethodDef>.RowIndex

    init(definingTypeImpl: TypeDefinition.MetadataImpl, tableRowIndex: Table<WinMD.MethodDef>.RowIndex) {
        self.definingTypeImpl = definingTypeImpl
        self.tableRowIndex = tableRowIndex
    }

    public var definingType: TypeDefinition { definingTypeImpl.owner }
    internal var database: Database { definingTypeImpl.database }
    private var tableRow: WinMD.MethodDef { database.tables.methodDef[tableRowIndex] }

    public var name: String { database.heaps.resolve(tableRow.name) }
    public var isStatic: Bool { tableRow.flags.contains(.`static`) }
    public var isVirtual: Bool { tableRow.flags.contains(.virtual) }
    public var isAbstract: Bool { tableRow.flags.contains(.abstract) }
    public var isFinal: Bool { tableRow.flags.contains(.final) }
    public var isSpecialName: Bool { tableRow.flags.contains(.specialName) }
    public var isGeneric: Bool { !genericParams.isEmpty }

    public var visibility: Visibility {
        switch tableRow.flags.intersection(.memberAccessMask) {
            case .compilerControlled: return .compilerControlled
            case .private: return .private
            case .assem: return .assembly
            case .famANDAssem: return .familyAndAssembly
            case .famORAssem: return .familyOrAssembly
            case .family: return .family
            case .public: return .public
            default: fatalError()
        }
    }

    public private(set) lazy var genericParams: [GenericMethodParam] = { [self] in
        var result: [GenericMethodParam] = []
        var genericParamRowIndex = database.tables.genericParam.find(primaryKey: MetadataToken(tableRowIndex), secondaryKey: 0)
            ?? database.tables.genericParam.endIndex
        while genericParamRowIndex < database.tables.genericParam.endIndex {
            let genericParam = database.tables.genericParam[genericParamRowIndex]
            guard genericParam.primaryKey == MetadataToken(tableRowIndex) && genericParam.number == result.count else { break }
            result.append(GenericMethodParam(definingMethod: self, tableRowIndex: genericParamRowIndex))
            genericParamRowIndex = database.tables.genericParam.index(after: genericParamRowIndex)
        }
        return result
    }()
}