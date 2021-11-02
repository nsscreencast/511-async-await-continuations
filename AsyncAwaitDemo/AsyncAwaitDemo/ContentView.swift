import SwiftUI
import AVFoundation

struct ThumbnailService {
    struct InvalidImage: Error { }
    struct UnexpectedResponse: Error { }
    
    func downloadThumbnail(_ url: URL) async throws -> UIImage {
        let session = URLSession.shared
        
        await Task.sleep(NSEC_PER_SEC)
        
        let (data, response) = try await session.data(from: url, delegate: nil)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UnexpectedResponse()
        }
        
        guard let image = UIImage(data: data) else {
            throw InvalidImage()
        }
        
        let thumbSize = CGSize(width: 600, height: 600)
        let thumbRect = AVMakeRect(aspectRatio: image.size, insideRect: CGRect(origin: .zero, size: thumbSize))
        
        return try await withCheckedThrowingContinuation { continuation in
            image.prepareThumbnail(of: thumbRect.size) { image in
                guard let image = image else {
                    continuation.resume(throwing: InvalidImage())
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }
}

@MainActor
final class ViewModel: ObservableObject {
    @Published
    var output: [String] = []
    
    @Published
    var image: UIImage?
    
    @Published
    var running = false
    
    func run() async {
        running = true
        outputMessage("Running...")
        
        do {
            let url = URL(string: "https://nsscreencast-uploads.imgix.net/production/series/image/57/Async_Series_Artwork.png?w=600&dpr=2")!
            
            self.image = try await ThumbnailService().downloadThumbnail(url)
            
        } catch {
            outputMessage("Ooops, got an error!")
        }
        
        outputMessage("Done!")
        running = false
    }
    
    private var lock = NSLock()
    private func outputMessage(_ string: String) {
        lock.lock()
        defer { lock.unlock() }
        output.append(string)
    }
}


struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()
    
    var body: some View {
        ScrollView {
            Image(uiImage: viewModel.image ?? UIImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 150)
                .background(Color.gray)
                .animation(.default, value: viewModel.image)
                .padding(.bottom)
            
            VStack(alignment: .leading) {
                ForEach(viewModel.output, id: \.self) { string in
                    Text(string)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .font(.headline.monospaced())
        .padding(.vertical, 40)
        .padding(.horizontal, 10)
        .background(Color(white: 0.1).edgesIgnoringSafeArea(.all))
        .overlay(
            ZStack(alignment: .topTrailing) {
                Color.clear
                ProgressView()
                        .progressViewStyle(.circular)
                        .colorScheme(.dark)
                        .opacity(viewModel.running ? 1 : 0)
            }.padding()
        )
        .task {
            await viewModel.run()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
