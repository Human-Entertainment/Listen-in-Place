import Foundation

// From https://github.com/palmin/open-in-place/blob/master/OpenInPlace/UrlCoordination.swift
extension URL {
    public func coordinatedRead(_ coordinator : NSFileCoordinator,
                                callback: @escaping ((Data?, Error?) -> ())) {
        
        let error: NSErrorPointer = nil
        coordinator.coordinate(readingItemAt: self, options: [],
                               error: error, byAccessor: { url in
                                do {
                                    let text = try Data(contentsOf: url)
                                    callback(text, nil)
                                    
                                } catch {
                                    callback(nil, error)
                                }
        })
        
        // only do callback if there is error, as it will be made during coordination
        if error != nil { callback(nil, error!.pointee! as NSError) }
    }
}
