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
}

extension Array: ArrayAble {}
extension ArraySlice: ArrayAble {}
