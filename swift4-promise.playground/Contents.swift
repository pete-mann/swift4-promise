import Foundation

struct Beer: Decodable {
    var id: Int
    var name: String
    var description: String
}

class Promise {
    
    var resolve: (URLResponse, Data) -> Void?
    
    var error: (URLResponse, Error) -> Void?
    
    init() {
        self.resolve = { (urlResponse, data) in print("unhandled resolve") }
        self.error = { (urlResponse, error) in print("unhandled error") }
    }
    
    func then(resolve: @escaping (URLResponse, Foundation.Data) -> Void, error: @escaping (URLResponse, Error) -> Void) {
        self.resolve = resolve
        self.error = error
    }
    
}

class URLLoaderUtility {
    
    static func fetchData(from: URL) -> Promise {
        let promise = Promise()
        
        URLSession.shared.dataTask(with: from) { data, urlResponse, error in
            if let error = error, let urlResponse = urlResponse {
                DispatchQueue.main.async { promise.error(urlResponse, error) }
                return
            }
            if let data = data, let urlResponse = urlResponse {
                DispatchQueue.main.async { promise.resolve(urlResponse, data) }
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
    
    func ready(callback: @escaping (Model, String?) -> Void) {
        if let url = beersURL {
            URLLoaderUtility.fetchData(from: url).then(resolve: { (urlResponse, data) in
                do {
                    self.beers = try JSONDecoder().decode([Beer].self, from: data)
                    callback(self, nil)
                } catch {
                    callback(self, "Could not decode JSON")
                }
            }, error: { (urlResponse, error) in
                callback(self, "Call to remote API failed")
            })
        }
    }
    
}

class Controller {
    
    var model: Model = Model()
    
    init() {
        model.ready { (model, error) in
            if let error = error {
                print(error)
            } else {
                model.beers.forEach { print($0.name, $0.description) }
            }
        }
    }
}

let controller = Controller()
