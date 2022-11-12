import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State var mapleDiffusion: MapleDiffusion?
    let dispatchQueue = DispatchQueue(label: "Generation")
    @State var steps: Float = 28
    @State var image: Image?
    @State var _cgim: CGImage?
    @State var prompt: String = ""
    @State var negativePrompt: String = ""
    @State var width: String = "512"
    @State var height: String = "768"
    @State var pw: String = "512"
    @State var ph: String = "768"
    @State var seed: String = "-1"
    @State var guidanceScale: Float = 12
    @State var running: Bool = false
    @State var progressProp: Float = 1
    @State var progressStage: String = "Ready"
    
    func loadModels() {
        dispatchQueue.async {
            running = true
            
            running = false
        }
    }
    
    func generate() {
        dispatchQueue.async {
            running = true
            if mapleDiffusion == nil || width != pw || height != ph {
#if os(iOS)
    mapleDiffusion = MapleDiffusion(w: Int(UInt(width) ?? 512), h: Int(UInt(height) ?? 768), saveMemoryButBeSlower: true)
#else
    mapleDiffusion = MapleDiffusion(w: Int(UInt(width) ?? 512), h: Int(UInt(height) ?? 768), saveMemoryButBeSlower: false)
#endif
                mapleDiffusion?.initModels() { (p, s) -> () in
                    progressProp = p
                    progressStage = s
                }
                pw = width
                ph = height
            }
            progressStage = ""
            progressProp = 0
            guard var sd = Int(seed) else {
                running = false
                return
            }
            if sd <= 0 {
                sd = Int.random(in: 1..<Int.max)
                seed = String(sd)
            }
            mapleDiffusion?.generate(prompt: prompt, negativePrompt: negativePrompt, seed: sd, steps: Int(steps), guidanceScale: guidanceScale) { (cgim, p, s) -> () in
                if (cgim != nil) {
                    image = Image(cgim!, scale: 1.0, label: Text("Generated image"))
                    _cgim = cgim
                }
                progressProp = p
                progressStage = s
            }
            running = false
        }
    }
    
    func save() {
        if _cgim == nil {
            return
        }
        let p = NSSavePanel()
        p.allowedContentTypes = [UTType.png]
        p.canCreateDirectories = true
        p.nameFieldStringValue = prompt.replacingOccurrences(of: " ", with: "")+"-"+seed
        if p.runModal() == .OK {
            let d: URL = p.url!
            guard let dst = CGImageDestinationCreateWithURL(d as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
            CGImageDestinationAddImage(dst, _cgim!, nil)
            CGImageDestinationFinalize(dst)
        }
    }

    var body: some View {
        VStack(alignment: .center) {
#if os(iOS)
            Text("🍁 Maple Diffusion").foregroundColor(.orange).bold().frame(alignment: Alignment.center)
#endif
            let w = UInt(width) ?? 512
            let h = UInt(height) ?? 768
            if (image == nil) {
                Rectangle().fill(.gray).aspectRatio(Double(w)/Double(h), contentMode: .fit)
                    .frame(minHeight: 512)
            } else {
#if os(iOS)
                ShareLink(item: image!, preview: SharePreview(prompt, image: image!)) {
                    image!.resizable().aspectRatio(contentMode: .fit)
                }
#else
                image!.resizable().aspectRatio(contentMode: .fit)
#endif
            }
            HStack {
                Text("Prompt").bold()
                TextField("What you want", text: $prompt)
            }
            HStack {
                Text("Negative Prompt").bold()
                TextField("What you don't want", text: $negativePrompt)
            }
            HStack {
                Text("Size").bold()
                TextField("Width", text: $width).frame(maxWidth: 64)
                Text("x").foregroundColor(.secondary)
                TextField("Height", text: $height).frame(maxWidth: 64)
                Text("Seed").foregroundColor(.secondary)
                TextField("-1: random", text: $seed)
            }
            HStack {
                HStack {
                    Text("Scale").bold()
                    Text(String(format: "%.1f", guidanceScale)).foregroundColor(.secondary)
                }.frame(alignment: .leading)
                Slider(value: $guidanceScale, in: 1...20)
                HStack {
                    Text("Steps").bold()
                    Text("\(Int(steps))").foregroundColor(.secondary)
                }.frame(alignment: .leading)
                Slider(value: $steps, in: 5...64)
            }
            ProgressView(progressStage, value: progressProp, total: 1).foregroundColor(.secondary)
            Button(action: generate) {
                Text("Generate Image")
                    .frame(minWidth: 64, maxWidth: .infinity, minHeight: 32, alignment: .center)
                    .background(running ? .gray : .blue)
                    .foregroundColor(.white)
                    .cornerRadius(32)
            }.buttonStyle(.borderless).disabled(running)
            Button(action: save) {
                Text("Save Image")
                    .frame(minWidth: 64, maxWidth: .infinity, minHeight: 32, alignment: .center)
                    .background(running ? .gray : .blue)
                    .foregroundColor(.white)
                    .cornerRadius(32)
            }.buttonStyle(.borderless).disabled(running)
        }.padding(16)
            //.onAppear(perform: loadModels)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
