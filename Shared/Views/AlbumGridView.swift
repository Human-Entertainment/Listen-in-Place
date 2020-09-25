//
//  AlbumGridView.swift
//  iOS
//
//  Created by Bastian Inuk Christensen on 25/09/2020.
//  Copyright © 2020 Bastian Inuk Christensen. All rights reserved.
//

import SwiftUI

struct AlbumGridView: View {
    let columnsRules = [ GridItem(.adaptive(minimum: 50)) ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columnsRules) {
                ForEach(0..<100) { value in
                    // 5
                    Rectangle()
                        .foregroundColor(Color.green)
                        .frame(height: 50)
                        .overlay(
                            // 6
                            Text("\(value)").foregroundColor(.white)
                        )
                }
            }.padding(.all, 10)
        }
    }
}

struct AlbumGridView_Previews: PreviewProvider {
    static var previews: some View {
        AlbumGridView()
    }
}
