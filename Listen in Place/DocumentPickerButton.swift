import SwiftUI

struct DocumentPickerButton: View {
    @State
    var showPicker = false
    
    var body: some View {
        Button(action: {self.showPicker.toggle() }) {
            Image(systemName: "plus.circle.fill")
            .resizable()
        }
        .sheet(isPresented: self.$showPicker) {
            DocumentPickerController()
                .accentColor(.orange)
        }
    }
}

struct DocumentPickerController: UIViewControllerRepresentable {
    
    typealias UIViewControllerType = DocumentPicker
    let picker = UIViewControllerType(documentTypes: ["public.mp3"], in: .open)
    
    let delagate = DocumentDelagate()
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
    
    func makeUIViewController(context: Context) -> UIViewControllerType {
        picker.delegate = self.delagate
        return picker
    }
    
}

class DocumentPicker: UIDocumentPickerViewController {
    let documentDelegate = DocumentDelagate()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self.documentDelegate
    }
}

class DocumentDelagate: UIView ,UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        print("Reading URLS")
        urls.forEach { url in
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to open the file")
                return
            }
            print(url)
            defer { url.stopAccessingSecurityScopedResource() }
            
            guard let bookmark = try? url.bookmarkData() else {
                return
            }
            
            let defaults = UserDefaults.standard
            
            var array = defaults.array(forKey: "Songs") as? [Data]
            array?.append(bookmark)
            defaults.set(array, forKey: "Songs")
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Document picker was cancelled")
    }
    
}
