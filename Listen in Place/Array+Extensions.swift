import Foundation

extension Data {
    var bytes: [Byte] {
        var byteArray = [UInt8](repeating: 0, count: self.count)
        self.copyBytes(to: &byteArray, count: self.count)
        return byteArray
    }
}

protocol ArrayAble: Sequence {
    var count: Int { get }
}

extension ArrayAble where Element == Byte {
    var data: Data {
        Data(self)
    }
    var int: Int {
        var compound = 0
        let ints = self.map { Int($0) }
        for i in 0..<self.count {
            let reverseIndex = self.count - i - 1
            compound += ints[i] << (reverseIndex * 8)
        }
        return compound
    }
    
    var uint32: UInt32 {
        var compound: UInt32 = 0
        let uints = self.map { UInt32($0) }
        for i in 0..<self.count {
            let reverseIndex = self.count - i - 1
            compound += uints[i] << (reverseIndex * 8)
        }
        return compound
    }
}

infix operator ..+<
extension Strideable where Stride: SignedInteger {
    public static func ..+<(minimum: Self, count: Self.Stride) -> Range<Self> {
        minimum..<minimum.advanced(by: count)
    }
}

extension Array: ArrayAble {}
extension ArraySlice: ArrayAble {}
