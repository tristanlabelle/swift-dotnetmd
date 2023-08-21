import DotNetMetadataFormat

/// An unbound type definition, which may have generic parameters.
public class TypeDefinition: CustomDebugStringConvertible {
    internal typealias Kind = TypeDefinitionKind

    public static let nestedTypeSeparator: Character = "/"
    public static let genericParamCountSeparator: Character = "`"

    public let assembly: Assembly
    public let tableRowIndex: TypeDefTable.RowIndex

    fileprivate init(assembly: Assembly, tableRowIndex: TypeDefTable.RowIndex) {
        self.assembly = assembly
        self.tableRowIndex = tableRowIndex
    }

    internal static func create(assembly: Assembly, tableRowIndex: TypeDefTable.RowIndex) -> TypeDefinition {
        // Figuring out the kind requires checking the base type,
        // but we must be careful to not look up any other `TypeDefinition`
        // instances since they might not have been created yet.
        // For safety, implement this at the physical layer.
        let tableRow = assembly.moduleFile.typeDefTable[tableRowIndex]
        let kind = assembly.moduleFile.getTypeDefinitionKind(tableRow, isMscorlib: assembly.name == Mscorlib.name)

        switch kind {
            case .class: return ClassDefinition(assembly: assembly, tableRowIndex: tableRowIndex)
            case .interface: return InterfaceDefinition(assembly: assembly, tableRowIndex: tableRowIndex)
            case .delegate: return DelegateDefinition(assembly: assembly, tableRowIndex: tableRowIndex)
            case .struct: return StructDefinition(assembly: assembly, tableRowIndex: tableRowIndex)
            case .enum: return EnumDefinition(assembly: assembly, tableRowIndex: tableRowIndex)
        }
    }

    public var context: MetadataContext { assembly.context }
    internal var moduleFile: ModuleFile { assembly.moduleFile }
    private var tableRow: TypeDefTable.Row { moduleFile.typeDefTable[tableRowIndex] }

    public var kind: TypeDefinitionKind { fatalError() }
    public var isValueType: Bool { kind.isValueType }
    public var isReferenceType: Bool { kind.isReferenceType }

    public var name: String { moduleFile.resolve(tableRow.typeName) }

    public var nameWithoutGenericSuffix: String {
        let name = name
        guard let index = name.firstIndex(of: Self.genericParamCountSeparator) else { return name }
        return String(name[..<index])
    }

    public var namespace: String? {
        let tableRow = tableRow
        // Normally, no namespace is represented by a zero string heap index
        guard tableRow.typeNamespace.value != 0 else { return nil }
        let value = moduleFile.resolve(tableRow.typeNamespace)
        return value.isEmpty ? nil : value
    }

    public private(set) lazy var fullName: String = {
        if let enclosingType {
            assert(namespace == nil)
            return "\(enclosingType.fullName)\(Self.nestedTypeSeparator)\(name)"
        }
        return makeFullTypeName(namespace: namespace, name: name)
    }()

    internal var metadataAttributes: DotNetMetadataFormat.TypeAttributes { tableRow.flags }

    public var nameKind: NameKind { metadataAttributes.nameKind }
    public var visibility: Visibility { metadataAttributes.visibility }
    public var isPublic: Bool { visibility == .public }
    public var isNested: Bool { metadataAttributes.isNested }
    public var isAbstract: Bool { metadataAttributes.contains(TypeAttributes.abstract) }
    public var isSealed: Bool { metadataAttributes.contains(TypeAttributes.sealed) }
    public var layoutKind: LayoutKind { metadataAttributes.layoutKind }

    public var debugDescription: String { "\(fullName) (\(assembly.name) \(assembly.version))" }

    public private(set) lazy var layout: TypeLayout = {
        switch metadataAttributes.layoutKind {
            case .auto: return .auto
            case .sequential:
                let layout = getClassLayout()
                return .sequential(pack: layout.pack == 0 ? nil : Int(layout.pack), minSize: Int(layout.size))
            case .explicit:
                return .explicit(minSize: Int(getClassLayout().size))
        }

        func getClassLayout() -> (pack: UInt16, size: UInt32) {
            if let classLayoutRowIndex = moduleFile.classLayoutTable.findAny(primaryKey: tableRowIndex.metadataToken.tableKey) {
                let classLayoutRow = moduleFile.classLayoutTable[classLayoutRowIndex]
                return (pack: classLayoutRow.packingSize, size: classLayoutRow.classSize)
            }
            else {
                return (pack: 0, size: 0)
            }
        }
    }()

    public private(set) lazy var enclosingType: TypeDefinition? = {
        guard let nestedClassRowIndex = moduleFile.nestedClassTable.findAny(primaryKey: MetadataToken(tableRowIndex).tableKey) else { return nil }
        guard let enclosingTypeDefRowIndex = moduleFile.nestedClassTable[nestedClassRowIndex].enclosingClass else { return nil }
        return assembly.resolve(enclosingTypeDefRowIndex)
    }()

    /// The list of generic parameters on this type definition.
    /// By CLS rules, generic parameters on the enclosing type should be redeclared
    /// in the nested type, i.e. given "Enclosing<T>.Nested<U>" in C#, the metadata
    /// for "Nested" should have generic parameters T (redeclared) and U.
    public private(set) lazy var genericParams: [GenericTypeParam] = {
        moduleFile.genericParamTable.findAll(primaryKey: tableRowIndex.metadataToken.tableKey).map {
            GenericTypeParam(definingType: self, tableRowIndex: $0)
        }
    }()

    public var genericArity: Int { genericParams.count }

    public private(set) lazy var base: BoundType? = assembly.resolveOptionalBoundType(tableRow.extends)

    public private(set) lazy var baseInterfaces: [BaseInterface] = {
        moduleFile.interfaceImplTable.findAll(primaryKey: tableRowIndex.metadataToken.tableKey).map {
            BaseInterface(inheritingType: self, tableRowIndex: $0)
        }
    }()

    public private(set) lazy var methods: [Method] = {
        getChildRowRange(parent: moduleFile.typeDefTable,
            parentRowIndex: tableRowIndex,
            childTable: moduleFile.methodDefTable,
            childSelector: { $0.methodList }).map {
            Method.create(definingType: self, tableRowIndex: $0)
        }
    }()

    public private(set) lazy var fields: [Field] = {
        getChildRowRange(parent: moduleFile.typeDefTable,
            parentRowIndex: tableRowIndex,
            childTable: moduleFile.fieldTable,
            childSelector: { $0.fieldList }).map {
            Field(definingType: self, tableRowIndex: $0)
        }
    }()

    public private(set) lazy var properties: [Property] = {
        guard let propertyMapRowIndex = assembly.findPropertyMap(forTypeDef: tableRowIndex) else { return [] }
        return getChildRowRange(parent: moduleFile.propertyMapTable,
            parentRowIndex: propertyMapRowIndex,
            childTable: moduleFile.propertyTable,
            childSelector: { $0.propertyList }).map {
            Property.create(definingType: self, tableRowIndex: $0)
        }
    }()

    public private(set) lazy var events: [Event] = {
        guard let eventMapRowIndex: EventMapTable.RowIndex = assembly.findEventMap(forTypeDef: tableRowIndex) else { return [] }
        return getChildRowRange(parent: moduleFile.eventMapTable,
            parentRowIndex: eventMapRowIndex,
            childTable: moduleFile.eventTable,
            childSelector: { $0.eventList }).map {
            Event(definingType: self, tableRowIndex: $0)
        }
    }()

    public private(set) lazy var attributes: [Attribute] = {
        assembly.getAttributes(owner: .typeDef(tableRowIndex))
    }()

    public private(set) lazy var nestedTypes: [TypeDefinition] = {
        moduleFile.nestedClassTable.findAllNested(enclosing: tableRowIndex).map {
            let nestedTypeRowIndex = moduleFile.nestedClassTable[$0].nestedClass!
            return assembly.resolve(nestedTypeRowIndex)
        }
    }()

    internal func getAccessors(owner: HasSemantics) -> [(method: Method, attributes: MethodSemanticsAttributes)] {
        moduleFile.methodSemanticsTable.findAll(primaryKey: owner.metadataToken.tableKey).map {
            let row = moduleFile.methodSemanticsTable[$0]
            let method = methods.first { $0.tableRowIndex == row.method }!
            return (method, row.semantics)
        }
    }

    public func isMscorlib(namespace: String, name: String) -> Bool {
        assembly is Mscorlib && self.namespace == namespace && self.name == name
    }

    public func isMscorlib(fullName: String) -> Bool {
        assembly is Mscorlib && self.fullName == fullName
    }

    public func findMethod(
        name: String,
        public: Bool? = nil,
        static: Bool? = nil,
        genericArity: Int? = nil,
        arity: Int? = nil,
        paramTypes: [TypeNode]? = nil,
        inherited: Bool = false) -> Method? {

        findMember(
            getter: { $0.methods },
            name: name,
            public: `public`,
            static: `static`,
            predicate: {
                if let genericArity { guard $0.genericArity == genericArity else { return false } }
                if let arity { guard (try? $0.arity) == arity else { return false } }
                if let paramTypes {
                    guard let params = try? $0.params,
                        params.map(\.type) == paramTypes else { return false }
                }
                return true
            },
            inherited: inherited)
    }

    public func findConstructor(
        public: Bool? = nil,
        arity: Int? = nil,
        paramTypes: [TypeNode]? = nil,
        inherited: Bool = false) -> Constructor? {

        findMethod(
            name: Constructor.name,
            public: `public`,
            arity: arity,
            paramTypes: paramTypes,
            inherited: inherited) as? Constructor
    }

    public func findField(
        name: String, 
        public: Bool? = nil,
        static: Bool? = nil,
        inherited: Bool = false) -> Field? {

        findMember(
            getter: { $0.fields },
            name: name,
            public: `public`,
            static: `static`,
            inherited: inherited)
    }

    public func findProperty(
        name: String,
        public: Bool? = nil,
        static: Bool? = nil,
        inherited: Bool = false) -> Property? {

        findMember(
            getter: { $0.properties },
            name: name,
            public: `public`,
            static: `static`,
            inherited: inherited)
    }

    public func findEvent(
        name: String,
        public: Bool? = nil,
        static: Bool? = nil,
        inherited: Bool = false) -> Event? {

        findMember(
            getter: { $0.events },
            name: name,
            public: `public`,
            static: `static`,
            inherited: inherited)
    }

    private func findMember<M: Member>(
        getter: (TypeDefinition) -> [M],
        name: String,
        public: Bool? = nil,
        static: Bool? = nil,
        predicate: ((M) -> Bool)? = nil,
        inherited: Bool = false) -> M? {

        var result: M? = nil
        gatherMembers(
            getter: getter,
            name: name,
            public: `public`,
            static: `static`,
            predicate: predicate,
            inherited: inherited) {
                if result == nil {
                    result = $0
                    return true
                }
                else {
                    // Disallow multiple matches
                    result = nil
                    return false
                }
            }

        return result
    }

    private func gatherMembers<M: Member>(
        getter: (TypeDefinition) -> [M],
        name: String? = nil,
        public: Bool? = nil,
        static: Bool? = nil,
        predicate: ((M) -> Bool)? = nil,
        inherited: Bool = false,
        action: (M) -> Bool) {

        var typeDefinition = self
        while true {
            for member in getter(typeDefinition) {
                if let name { guard member.name == name else { continue } }
                if let `public` { guard (member.visibility == .public) == `public` else { continue } }
                if let `static` { guard member.isStatic == `static` else { continue } }
                if let predicate { guard predicate(member) else { continue } }
                guard action(member) else { return }
            }

            guard inherited, let base = typeDefinition.base else { return }
            typeDefinition = base.definition
        }
    }
}

public final class ClassDefinition: TypeDefinition {
    public override var kind: TypeDefinitionKind { .class }

    public var finalizer: Method? { findMethod(name: "Finalize", static: false, arity: 0) }
}

public final class InterfaceDefinition: TypeDefinition {
    public override var kind: TypeDefinitionKind { .interface }
}

public final class DelegateDefinition: TypeDefinition {
    public override var kind: TypeDefinitionKind { .delegate }

    public var invokeMethod: Method { findMethod(name: "Invoke", public: true, static: false)! }
    public var arity: Int { get throws { try invokeMethod.arity } }
}

public final class StructDefinition: TypeDefinition {
    public override var kind: TypeDefinitionKind { .struct }
}

public final class EnumDefinition: TypeDefinition {
    public override var kind: TypeDefinitionKind { .enum }

    public var backingField: Field {
        // The backing field may be public but will have specialName and rtSpecialName
        findField(name: "value__", static: false)!
    }

    public var underlyingType: TypeDefinition { get throws { try backingField.type.asDefinition! } }

    public private(set) lazy var isFlags: Bool = {
        attributes.contains { (try? $0.type)?.isMscorlib(namespace: "System", name: "FlagsAttribute") == true }
    }()
}

extension TypeDefinition: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
    public static func == (lhs: TypeDefinition, rhs: TypeDefinition) -> Bool { lhs === rhs }
}

public func makeFullTypeName(namespace: String?, name: String) -> String {
    if let namespace { return "\(namespace).\(name)" }
    else { return name }
}

public func makeFullTypeName(namespace: String?, enclosingName: String, nestedNames: [String]) -> String {
    var result: String
    if let namespace { result = "\(namespace).\(enclosingName)" }
    else { result = enclosingName }

    for nestedName in nestedNames {
        result.append(TypeDefinition.nestedTypeSeparator)
        result += nestedName
    }

    return result
}