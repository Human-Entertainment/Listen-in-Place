extension Collection {
    static func >(lhs: Self, rhs: Int) -> Bool {
        lhs.count > rhs
    }
    
    static func >(lhs: Int, rhs: Self) -> Bool {
        lhs > rhs.count
    }
    
    static func <(lhs: Self, rhs: Int) -> Bool {
        lhs.count < rhs
    }
    
    static func <(lhs: Int, rhs: Self) -> Bool {
        lhs < rhs.count
    }
}
