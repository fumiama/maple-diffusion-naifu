import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State var mapleDiffusion: MapleDiffusion?
    let dispatchQueue = DispatchQueue(label: "Generation")
    @State var steps: Float = 28
    @State var image: Image?
    @State var _cgim: CGImage?
    @State var _ld_cgim: CGImage?
    @State var prompt: String = ""
    @State var negativePrompt: String = ""
    @State var width: String = "512"
    @State var height: String = "768"
    @State var pw: String = "512"
    @State var ph: String = "768"
    @State var seed: String = "-1"
    @State var guidanceScale: Float = 12
    @State var running: Bool = false
    @State var saved: Bool = true
    @State var progressProp: Float = 1
    @State var progressStage: String = "Ready"

    private func loadModels() {
        dispatchQueue.async {
            running = true
            
            running = false
        }
    }
    
    private func generate() {
        dispatchQueue.async {
            running = true
            defer {
                running = false
                saved = false
            }
            if mapleDiffusion == nil || width != pw || height != ph {
                mapleDiffusion = nil // free memory
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
            guard var sd = Int(seed) else { return }
            if sd <= 0 {
                sd = Int.random(in: 1..<Int.max)
                seed = String(sd)
            }
            prompt = prompt.replacingOccurrences(of: "\n", with: ",").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").replacingOccurrences(of: " ", with: "")
            negativePrompt = negativePrompt.replacingOccurrences(of: "\n", with: ",").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").replacingOccurrences(of: " ", with: "")
            if(prompt.isEmpty || negativePrompt.isEmpty) {
                return
            }
            mapleDiffusion?.generate(prompt: prompt, negativePrompt: negativePrompt, seed: sd, steps: Int(steps), guidanceScale: guidanceScale, imgGuidance: _ld_cgim) { (cgim, p, s) -> () in
                if (cgim != nil) {
                    image = nil
                    image = Image(cgim!, scale: 1.0, label: Text("Generated image"))
                    _cgim = nil
                    _cgim = cgim
                    _ld_cgim = nil
                }
                progressProp = p
                progressStage = s
            }
        }
    }
    
    private func save() {
        saved = false
        defer {
            saved = true
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
    
    private func resetseed() {
        if (!saved) {
            let a = NSAlert()
            a.messageText = "Attention"
            a.informativeText = "Seed Will be Changed without Saving"
            a.addButton(withTitle: "Do Anyway")
            a.addButton(withTitle: "Cancel")
            a.alertStyle = .warning
            saved = a.runModal() == .alertFirstButtonReturn
        }
        if (saved) {
            seed = "-1"
        }
    }
    
    private func load() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [UTType.png]
        if p.runModal() == .OK {
            let d: URL = p.url!
            guard let src = CGImageSourceCreateWithURL(d as CFURL, nil) else { return }
            _ld_cgim = CGImageSourceCreateImageAtIndex(src, 0, nil)
            let w = UInt(width) ?? 512
            let h = UInt(height) ?? 768
            if (_ld_cgim != nil) {
                if (_ld_cgim?.width ?? 0 < w || _ld_cgim?.height ?? 0 < h) {
                    let a = NSAlert()
                    a.messageText = "Warning"
                    a.informativeText = "Image too Small"
                    a.addButton(withTitle: "OK")
                    a.alertStyle = .warning
                    a.runModal()
                    return
                }
                _ld_cgim = _ld_cgim?.cropping(to: CGRect(x: 0, y: 0, width: Int(w), height: Int(h)))
                if(_ld_cgim != nil) {
                    _ld_cgim = resize(_ld_cgim!)
                    if(_ld_cgim != nil) {
                        image = nil
                        image = Image(_ld_cgim!, scale: 1.0, label: Text("Loaded image"))
                    }
                }
            }
        }
    }
    
    private func resize(_ image: CGImage) -> CGImage? {
            let w = UInt(width) ?? 512
            let h = UInt(height) ?? 768
            var ratio: Float = 0.0
            let imageWidth = Float(image.width)
            let imageHeight = Float(image.height)
            let maxWidth: Float = Float(w)/8
            let maxHeight: Float = Float(h)/8
            
            // Get ratio (landscape or portrait)
            if (imageWidth > imageHeight) {
                ratio = maxWidth / imageWidth
            } else {
                ratio = maxHeight / imageHeight
            }
            
            // Calculate new size based on the ratio
            if ratio > 1 {
                ratio = 1
            }
            
            let width = imageWidth * ratio
            let height = imageHeight * ratio
            
        guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: Int(width)*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue).rawValue) else { return nil }
            
            // draw image to context (resizing it)
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: Int(width), height: Int(height)))
            
            // extract resulting image from context
            return context.makeImage()
        }

    var body: some View {
        VStack(alignment: .center) {
#if os(iOS)
            Text("🍁 Maple Diffusion").foregroundColor(.orange).bold().frame(alignment: Alignment.center)
#endif
            HStack{
                let w = UInt(width) ?? 512
                let h = UInt(height) ?? 768
                if (image == nil) {
                    Rectangle().fill(.gray).aspectRatio(Double(w)/Double(h), contentMode: .fit)
                } else {
    #if os(iOS)
                    ShareLink(item: image!, preview: SharePreview(prompt, image: image!)) {
                        image!.resizable().aspectRatio(contentMode: .fit)
                    }
    #else
                    image!.resizable().aspectRatio(contentMode: .fit)
    #endif
                }
            }.frame(height: 384)
            HStack {
                Text("Prompt").bold()
                TextEditor(text: $prompt).frame(height: 32).shadow(color: .secondary, radius: 4).cornerRadius(2)
            }
            HStack {
                Text("Negative Prompt").bold()
                TextEditor(text: $negativePrompt).frame(height: 32).shadow(color: .secondary, radius: 4).cornerRadius(2)
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
            HStack {
                let bgend = (running || !saved || prompt.isEmpty || negativePrompt.isEmpty)
                let brsd = (running || seed == "-1")
                Button(action: generate) {
                    Text("Generate Image")
                        .frame(minWidth: 64, maxWidth: .infinity, minHeight: 32, alignment: .center)
                        .background(bgend ? .gray : .blue)
                        .foregroundColor(.white)
                        .cornerRadius(32)
                }.buttonStyle(.borderless).disabled(bgend)
                Button(action: resetseed) {
                    Text("Reset Seed")
                        .frame(minWidth: 64, maxWidth: .infinity, minHeight: 32, alignment: .center)
                        .background(brsd ? .gray : .blue)
                        .foregroundColor(.white)
                        .cornerRadius(32)
                }.buttonStyle(.borderless).disabled(brsd)
            }
            HStack {
                let bsd = (running || _cgim == nil)
                let bld = (running)
                Button(action: save) {
                    Text("Save Image")
                        .frame(minWidth: 64, maxWidth: .infinity, minHeight: 32, alignment: .center)
                        .background(bsd ? .gray : .blue)
                        .foregroundColor(.white)
                        .cornerRadius(32)
                }.buttonStyle(.borderless).disabled(bsd)
                Button(action: load) {
                    Text("Load Custom Noise")
                        .frame(minWidth: 64, maxWidth: .infinity, minHeight: 32, alignment: .center)
                        .background(bld ? .gray : .blue)
                        .foregroundColor(.white)
                        .cornerRadius(32)
                }.buttonStyle(.borderless).disabled(bld)
            }
        }.padding(16).frame(width: 512)
            //.onAppear(perform: loadModels)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
