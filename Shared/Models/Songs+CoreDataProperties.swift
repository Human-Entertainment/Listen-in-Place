//
//  Songs+CoreDataProperties.swift
//  macOS
//
//  Created by Bastian Inuk Christensen on 28/08/2020.
//  Copyright © 2020 Bastian Inuk Christensen. All rights reserved.
//
//

import Foundation
import CoreData


extension Songs {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Songs> {
        return NSFetchRequest<Songs>(entityName: "Songs")
    }

    @NSManaged public var bookmark: Data?
    @NSManaged public var queue: Queue?

}

extension Songs : Identifiable {

}
