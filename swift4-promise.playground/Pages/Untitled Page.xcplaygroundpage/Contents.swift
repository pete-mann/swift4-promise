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

struct ResponseError {
    var error: Error
    var urlResponse: URLResponse
}

class Promise {
    
    var callback: (_ response: @escaping (Response) -> (), _ error: @escaping (ResponseError) -> ()) -> ()?

    init(_ callback: @escaping (_ response: @escaping (Response) -> (), _ error: @escaping (ResponseError) -> ()) -> ()) {
        self.callback = callback
    }

    func then(_ resolve: @escaping (Response) -> (), _ error: @escaping (ResponseError) -> ()) -> Promise {
        self.callback(resolve, error)
        return self
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

    init() {}

    func ready(callback: @escaping (Model, String?) -> Void) {
        if let url = beersURL {
            URLLoaderUtility.fetchData(from: url).then({ (response) in
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
