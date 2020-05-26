import SwiftUI

typealias URLS = ([URL]) -> ()
typealias voidFunc = () -> ()

struct DocumentPickerButton<Label: View>: View {
    @State
    var showPicker = false
    
    private let documentTypes: [String]
    private let onOpen: URLS
    private let onCancel: voidFunc
    private let view: () -> (Label)
    
    init(documentTypes: [String],
         onOpen: @escaping ([URL]) -> (),
         onCancel: @escaping () -> () = {},
         @ViewBuilder view: @escaping () -> (Label))
    {
        self.documentTypes = documentTypes
        self.onOpen = onOpen
        self.onCancel = onCancel
        self.view = view
    }
    
    var body: some View {
        Button(action: {self.showPicker.toggle() }) {
            view()
        }
        .sheet(isPresented: self.$showPicker) {
            DocumentPickerController(documentTypes: self.documentTypes,
                                     onOpen: self.onOpen,
                                     onCancel: self.onCancel)
        }
    }
}

fileprivate struct DocumentPickerController: UIViewControllerRepresentable {
    
    typealias UIViewControllerType = DocumentPicker
    let picker: UIViewControllerType
    
    init(documentTypes: [String],
         onOpen:  @escaping URLS,
         onCancel: @escaping voidFunc = {} ) {
        self.picker = UIViewControllerType(documentTypes: documentTypes, in: .open)
        let delagate = DocumentDelagate()
        delagate.onOpen = onOpen
        delagate.onCancel = onCancel
        picker.documentDelegate = delagate
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
    
    
    func makeUIViewController(context: Context) -> UIViewControllerType {
        picker
    }
    
}

fileprivate class DocumentPicker: UIDocumentPickerViewController {
    var documentDelegate: UIDocumentPickerDelegate? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self.documentDelegate
    }
}

fileprivate class DocumentDelagate: UIView ,UIDocumentPickerDelegate {
    var onOpen: URLS = { print($0) }
    var onCancel: voidFunc = {}
    
    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        onOpen(urls)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onCancel()
    }
    
}
