public enum WinRTTypeName: Hashable {
    case object
    case primitive(WinRTPrimitiveType)
    case parameterized(WinRTParameterizedType, args: [WinRTTypeName] = [])

    // https://learn.microsoft.com/en-us/uwp/winrt-cref/winrt-type-system
    // > All types—except for the fundamental types—must be contained within a namespace.
    // > It's not valid for a type to be in the global namespace.
    // WinRT types do not support nesting either.
    case declared(namespace: String, name: String)
}

extension WinRTTypeName: CustomStringConvertible, TextOutputStreamable {
    public var description: String { toString() }

    public func toString(useIInspectable: Bool = false, useAritySuffixes: Bool = false) -> String {
        var output = String()
        write(useIInspectable: useIInspectable, useAritySuffixes: useAritySuffixes, to: &output)
        return output
    }

    public func write(to output: inout some TextOutputStream) {
        write(useIInspectable: false, useAritySuffixes: false, to: &output)
    }

    public func write(useIInspectable: Bool = false, useAritySuffixes: Bool = false, to output: inout some TextOutputStream) {
        switch self {
            case .object:
                output.write(useIInspectable ? "IInspectable" : "Object")
            case let .primitive(primitiveType):
                output.write(primitiveType.name)
            case let .parameterized(type, args: args):
                let name = useAritySuffixes ? type.nameWithAritySuffix : type.nameWithoutAritySuffix
                write(namespace: type.namespace, name: name, genericArgs: args, to: &output)
            case let .declared(namespace, name):
                write(namespace: namespace, name: name, genericArgs: [], to: &output)
        }
    }

    private func write(namespace: String, name: String, genericArgs: [WinRTTypeName], to output: inout some TextOutputStream) {
        output.write(namespace)
        output.write(".")
        output.write(name)
        if !genericArgs.isEmpty {
            output.write("<")
            for (index, genericArg) in genericArgs.enumerated() {
                if index > 0 { output.write(", ") }
                genericArg.write(to: &output)
            }
            output.write(">")
        }
    }
}