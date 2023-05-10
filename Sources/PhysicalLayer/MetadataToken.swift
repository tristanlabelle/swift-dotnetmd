public struct MetadataToken: Hashable {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(tableIndex: TableIndex, rowIndex: UInt32) {
        precondition(rowIndex < 0x1000000)
        rawValue = (UInt32(tableIndex.rawValue) << 24) | rowIndex
    }

    public init(nullOf tableIndex: TableIndex) {
        rawValue = UInt32(tableIndex.rawValue) << 24
    }

    public init<Row>(row: TableRowIndex<Row>) where Row: TableRow {
        self.init(tableIndex: Row.tableIndex, rowIndex: row.value)
    }

    public var tableIndex: TableIndex { .init(rawValue: UInt8(rawValue >> 24))! }
    public var rowIndex: UInt32 { rawValue & 0xFFFFFF }
    public var isNull: Bool { rowIndex == 0 }
}