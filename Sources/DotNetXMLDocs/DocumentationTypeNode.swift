public enum DocumentationTypeNode: Hashable {
    case bound(DocumentationTypeReference)
    indirect case array(of: DocumentationTypeNode)
    indirect case pointer(to: DocumentationTypeNode)
    case genericParam(index: Int, kind: GenericParamKind)

    public enum GenericParamKind: Hashable {
        case type
        case method
    }
}

extension DocumentationTypeNode {
    public static func bound(
            namespace: String? = nil,
            nameWithoutGenericSuffix: String,
            genericity: DocumentationTypeReference.Genericity = .bound([])) -> Self {
        .bound(DocumentationTypeReference(
            namespace: namespace,
            nameWithoutGenericSuffix: nameWithoutGenericSuffix,
            genericity: genericity))
    }
}