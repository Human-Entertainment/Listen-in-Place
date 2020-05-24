import SwiftUI

extension View {
    func darkMode() -> some View {
        self.background(Color(UIColor.systemBackground))
            .environment(\.colorScheme, .dark)
    }
}

struct TestView<V: View>: View {
    let view: V
    
    var body: some View {
        Group {
            view.previewDisplayName("Light Mode")
            
            view.darkMode()
                .previewDisplayName("Dark Mode")
        }
    }
}
