import Foundation

// From https://github.com/palmin/open-in-place/blob/master/OpenInPlace/UrlCoordination.swift
extension URL {
    public func coordinatedRead(_ coordinator : NSFileCoordinator,
                                callback: @escaping ((URL?, Error?) -> ())) {
        
        let error: NSErrorPointer = nil
        coordinator.coordinate(readingItemAt: self, options: [],
                               error: error, byAccessor: { url in
                                if let error = error as? Error {
                                    callback(nil,error)
                                } else {
                                    callback(url,nil)
                                }
        })
        
        // only do callback if there is error, as it will be made during coordination
        if error != nil { callback(nil, error!.pointee! as NSError) }
    }
}
