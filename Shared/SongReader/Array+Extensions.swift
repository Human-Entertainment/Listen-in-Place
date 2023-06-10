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

extension Collection where Element == Byte {
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

//extension Array: ArrayAble {}
extension ArraySlice where Element == Byte {
    func readInt(toNext drop: Int) -> Int {
        let dropPoint = self.count - drop
        return self.dropLast(dropPoint).int
    }
    
    func readData(toNext drop: Int) -> Data {
        let dropPoint = self.count - drop
        return self.dropLast(dropPoint).data
    }
    
    func readString(toNext drop: Int) -> String? {
        let dropPoint = self.count - drop
        let bytes = self.dropLast(dropPoint)
        return String(bytes: bytes, encoding: .utf8)
    }
    
    func readBytes(toNext drop: Int) -> Self {
        let dropPoint = self.count - drop
        let bytes = self.dropLast(dropPoint)
        return bytes
    }
}
