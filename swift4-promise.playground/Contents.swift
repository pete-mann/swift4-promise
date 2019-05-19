import Foundation

struct Beer: Decodable {
    var id: Int
    var name: String
    var description: String
}

class Promise {
    
    var resolve: (Data) -> Void?
    
    var error: (Error) -> Void?
    
    init() {
        self.resolve = { (data) in print("unhandled resolve") }
        self.error = { (error) in print("unhandled error") }
    }
    
    func then(resolve: @escaping (Foundation.Data) -> Void, error: @escaping (Error) -> Void) {
        self.resolve = resolve
        self.error = error
    }
    
}

class URLLoaderUtility {
    
    static func fetchData(from: URL) -> Promise {
        let promise = Promise()
        
        URLSession.shared.dataTask(with: from) { data, ulrResponse, error in
            if let error = error {
                DispatchQueue.main.async { promise.error(error) }
                return
            }
            if let data = data {
                DispatchQueue.main.async { promise.resolve(data) }
                return
            }
        }.resume()
        
        return promise
    }
    
}

class Model {
    
    let beersURL = URL(string: "https://api.punkapi.com/v2/beers")
    
    var beers: [Beer] = [Beer]()
    
    init() {}
    
    func ready(callback: @escaping (Model) -> Void) {
        if let url = beersURL {
            URLLoaderUtility.fetchData(from: url).then(resolve: { (data) in
                do {
                    self.beers = try JSONDecoder().decode([Beer].self, from: data)
                    callback(self)
                } catch {
                    fatalError("Can't decode JSON")
                }
            }, error: { (error) in
                print(error)
            })
        }
    }
    
}

class Controller {
    
    var model: Model = Model()
    
    init() {
        model.ready { model in
            model.beers.forEach { print($0.name, $0.description) }
        }
    }
}

let controller = Controller()
