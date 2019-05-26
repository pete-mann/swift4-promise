import Foundation

struct Beer: Decodable {
    var id: Int
    var name: String
    var description: String
}

struct Response {
    var data: Data
    var urlResponse: URLResponse
}

struct Responses {
    var data: [Response]
}

struct ResponseError {
    var error: Error
    var urlResponse: URLResponse
}

class Promise {

    var callback: (_ response: @escaping (Response) -> (), _ error: @escaping (ResponseError) -> ()) -> ()
    
    var callback2: (_ response: @escaping (Responses) -> (), _ error: @escaping (ResponseError) -> ()) -> ()

    init(_ callback: @escaping (_ response: @escaping (Response) -> (), _ error: @escaping (ResponseError) -> ()) -> ()) {
        self.callback = callback
        self.callback2 = { (resolve: @escaping (Responses) -> (), error: @escaping (ResponseError) -> ()) in print("Unhandled responses") }
    }
    
    
    init(_ callback: @escaping (_ response: @escaping (Responses) -> (), _ error: @escaping (ResponseError) -> ()) -> ()) {
        self.callback2 = callback
        self.callback = { (resolve: @escaping (Response) -> (), error: @escaping (ResponseError) -> ()) in print("Unhandled response") }
    }

    func then(_ onResolve: @escaping (Response) -> (), _ onError: @escaping (ResponseError) -> ()) {
        self.callback(onResolve, onError)
    }
    
    
    func then(_ onResolve: @escaping (Responses) -> (), _ onError: @escaping (ResponseError) -> ()) {
        self.callback2(onResolve, onError)
    }

    static func all(_ promises: Promise ...) -> Promise {
        
        let promise = Promise({ (resolve: @escaping (Responses) -> (), error: @escaping (ResponseError) -> ()) in
            
            var resolutions = [Response]()
            
            var resolvedCount = 0
            
            let resolveCB = { (response: Response) -> () in
                resolvedCount += 1
                resolutions.append(response)
                
                if(resolvedCount == promises.count) {
                    resolve(Responses(data: resolutions))
                }
                
            }
            
            let errorCB = { (responseError: ResponseError) -> () in
                error(responseError)
            }
            
            
            promises.forEach { promise in promise.then(resolveCB, errorCB) }
        })
        
        return promise
    }

}

class URLLoaderUtility {

    static func fetchData(from: URL) -> Promise {
        return Promise({ (resolve: @escaping (Response) -> (), error: @escaping (ResponseError) -> ()) in
            URLSession.shared.dataTask(with: from) { data, urlResponse, e in
                if let e = e, let urlResponse = urlResponse {
                    DispatchQueue.main.async { error(ResponseError(error: e, urlResponse: urlResponse)) }
                    return
                }
                if let data = data, let urlResponse = urlResponse {
                    DispatchQueue.main.async { resolve(Response(data: data, urlResponse: urlResponse)) }
                    return
                }
                }.resume()
        })
    }

}

class Model {

    let beersURL = URL(string: "https://api.punkapi.com/v2/beers")

    var beers: [Beer] = [Beer]()

    func ready(callback: @escaping (Model, String?) -> Void) {
        if let url = beersURL {
            URLLoaderUtility.fetchData(from: url).then({ (response: Response) in
                do {
                    self.beers = try JSONDecoder().decode([Beer].self, from: response.data)
                    callback(self, nil)
                } catch {
                    callback(self, "Could not decode JSON")
                }
            }, { (responseError) in
                callback(self, "Call to remote API failed")
            })
        }
    }
    
    func test() {
        if let url = beersURL {
            Promise.all(URLLoaderUtility.fetchData(from: url), URLLoaderUtility.fetchData(from: url)).then({ (response: Responses) in
                print(response)
            }, {error in
                
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
                model.test()
            }
        }
    }
}

let controller = Controller()
