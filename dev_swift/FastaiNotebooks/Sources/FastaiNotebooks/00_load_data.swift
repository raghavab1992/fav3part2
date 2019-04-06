/*
THIS FILE WAS AUTOGENERATED! DO NOT EDIT!
file to edit: 00_load_data.ipynb

*/
        
import Foundation
import Just
import Path

public func shellCommand(_ launchPath: String, _ arguments: [String]) -> String?
{
    let task = Process()
    task.executableURL = URL.init(fileURLWithPath:launchPath)
    task.arguments = arguments

    let pipe = Pipe()
    task.standardOutput = pipe
    do {try task.run()} catch {print("Unexpected error: \(error).")}

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: String.Encoding.utf8)

    return output
}

public func downloadFile(_ url: String, dest: String?=nil, force: Bool=false){
    let dest_name = (dest ?? (Path.cwd/url.split(separator: "/").last!).string)
    let url_dest = URL.init(fileURLWithPath: (dest ?? (Path.cwd/url.split(separator: "/").last!).string))
    if (force || !Path(dest_name)!.exists){
        print("Downloading \(url)...")
        if let cts = Just.get(url).content{
            do    {try cts.write(to: URL.init(fileURLWithPath:dest_name))}
            catch {print("Can't write to \(url_dest).\n\(error)")}
        } else {print("Can't reach \(url)")}
    }
}

import TensorFlow

protocol ConvertableFromByte {
    init(_ d:UInt8)
}

extension Float : ConvertableFromByte{}
extension Int32 : ConvertableFromByte{}

func loadMNIST<T:ConvertableFromByte & TensorFlowScalar>(training: Bool, labels: Bool, path: Path) -> Tensor<T> {
    let split = training ? "train" : "t10k"
    let kind = labels ? "labels" : "images"
    let batch = training ? Int32(60000) : Int32(10000)
    let shape: TensorShape = labels ? [batch] : [batch, 28, 28]
    let rank = shape.rank
    let dropK = labels ? 8 : 16
    let baseUrl = "http://yann.lecun.com/exdb/mnist/"
    let fname = split + "-" + kind + "-idx\(rank)-ubyte"
    let file = path/fname
    if !file.exists {
        downloadFile("\(baseUrl)\(fname).gz", dest:(path/"\(fname).gz").string)
        _ = shellCommand("/bin/gunzip", ["-fq", (path/"\(fname).gz").string])
    }
    let data = try! Data.init(contentsOf: URL.init(fileURLWithPath: file.string)).dropFirst(dropK)
    if labels { return Tensor(data.map(T.init)) }
    else      { return Tensor(data.map(T.init)).reshaped(to: shape)}
}

public func loadMNIST(path:Path) -> (
    Tensor<Float>,
    Tensor<Int32>,
    Tensor<Float>,
    Tensor<Int32>
) {
    return (
        loadMNIST(training: true, labels: false, path: path) / 255.0,
        loadMNIST(training: true, labels: true, path: path),
        loadMNIST(training: false, labels: false, path: path) / 255.0,
        loadMNIST(training: false, labels: true, path: path)
    )
}

import Dispatch
public func time(_ function: () -> ()) {
    let start = DispatchTime.now()
    function()
    let end = DispatchTime.now()
    let nanoseconds = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
    let milliseconds = nanoseconds / 1e6
    print("\(milliseconds) ms")
}

public func time(repeating: Int, _ function: () -> ()) {
    function()
    var times:[Double] = []
    for _ in 1...repeating{
        let start = DispatchTime.now()
        function()
        let end = DispatchTime.now()
        let nanoseconds = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
        let milliseconds = nanoseconds / 1e6
        times.append(milliseconds)
    }
    print("\(times.reduce(0.0, +)/Double(times.count)) ms")
}

public func notebookToScript(fname: String){
    let url_fname = URL.init(fileURLWithPath: fname)
    let last = fname.lastPathComponent
    let out_fname = (url_fname.deletingLastPathComponent().appendingPathComponent("FastaiNotebooks", isDirectory: true)
                     .appendingPathComponent("Sources", isDirectory: true)
                     .appendingPathComponent("FastaiNotebooks", isDirectory: true).appendingPathComponent(last)
                     .deletingPathExtension().appendingPathExtension("swift"))
    do{
        let data = try Data.init(contentsOf: url_fname)
        let jsonData = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String: Any]
        let cells = jsonData["cells"] as! [[String:Any]]
        var module = """
/*
THIS FILE WAS AUTOGENERATED! DO NOT EDIT!
file to edit: \(fname.lastPathComponent)

*/
        
"""
        for cell in cells{
            if let source = cell["source"] as? [String]{
                if source.isEmpty {continue}
                if source[0].range(of: #"^\s*//\s*export\s*$"#, options: .regularExpression) != nil{
                    module.append("\n" + source[1...].joined() + "\n")
                }
            }
        }
        try? module.write(to: out_fname, atomically: false, encoding: .utf8)
    } catch {print("Can't read the content of \(fname)")}
}

public func exportNotebooks(_ path: Path){
    for entry in try! path.ls(){
        if entry.kind == Entry.Kind.file{
            if entry.path.basename().range(of: #"^\d*_.*ipynb$"#, options: .regularExpression) != nil { 
                print("Converting \(entry.path.basename())")
                notebookToScript(fname: entry.path.basename())
            }
        }
    }
}
