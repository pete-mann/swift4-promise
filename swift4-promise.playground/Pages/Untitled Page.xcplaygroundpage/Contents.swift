import Foundation

struct FavouriteBeer: Codable {
    var id: Int
}

struct Beer: Codable {
    let id: Int
    let name: String
    let tagline: String
}

struct Response {
    var data: Data
    var urlResponse: URLResponse
}

struct Responses {
    var responses: [Response]
}

struct ResponseError {
    var error: Error
    var urlResponse: URLResponse
}

class Promise {

    var singleAsyncOp: ((_ response: @escaping (Response) -> (), _ error: @escaping (ResponseError) -> ()) -> ())?
    
    var multiAsyncOp: ((_ response: @escaping ([Response]) -> (), _ error: @escaping (ResponseError) -> ()) -> ())?
    
    init(_ callback: @escaping (_ response: @escaping (Response) -> (), _ error: @escaping (ResponseError) -> ()) -> ()) {
        self.singleAsyncOp = callback
    }
    
    init(_ callback: @escaping (_ response: @escaping ([Response]) -> (), _ error: @escaping (ResponseError) -> ()) -> ()) {
        self.multiAsyncOp = callback
    }

    func then(_ onResolve: @escaping (Response) -> (), _ onError: @escaping (ResponseError) -> ()) {
        if let callback = self.singleAsyncOp {
            callback(onResolve, onError)
        }
    }
    
    func then(_ onResolve: @escaping ([Response]) -> (), _ onError: @escaping (ResponseError) -> ()) {
        if let multiAsyncOp = self.multiAsyncOp {
            multiAsyncOp(onResolve, onError)
        }
    }

    static func all(_ promises: Promise ...) -> Promise {
        
        let outerPromise = Promise({ (resolve: @escaping ([Response]) -> (), error: @escaping (ResponseError) -> ()) in
            var resolutions = [Int : Response]()
            
            promises.enumerated().forEach { tuple in
                tuple.element.then({ (response: Response) -> () in
                    resolutions[tuple.offset] = response
                    if(resolutions.count == promises.count) {
                        resolve(resolutions.sorted(by: { l, r in
                            l.key < r.key
                        }).map { (element) -> Response in
                            element.value
                        })
                    }
                }, { (responseError: ResponseError) -> () in
                    error(responseError)
                })
            }
            
        })
        
        return outerPromise
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

class HTTPService {
    
    static let PUNKAPI: String = "https://api.punkapi.com/v2/beers"
    
    static func getBeers(page: Int, name: String?, abv: Double?) -> Promise {
        var nameQuery = ""
        var ABVQuery = ""
        if let name = name {
            nameQuery = "&beer_name=\(name)"
            nameQuery.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        }
        if let abv = abv {
            ABVQuery = "&abv_gt=\(abv)&abv_lt=\(abv)"
        }
        if let url = URL(string: "\(self.PUNKAPI)?per_page=80\(nameQuery)\(ABVQuery)") {
            return URLLoaderUtility.fetchData(from: url)
        } else {
            fatalError("Can not create getBeers URL")
        }
    }
    
    static func getFavouriteBeers(ids: String) -> Promise {
        let urlString = "\(self.PUNKAPI)?ids=\(ids)".addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
        if let urlString = urlString,
            let url = URL(string: urlString) {
            return URLLoaderUtility.fetchData(from: url)
        } else {
            fatalError("Can not create getFavouriteBeers URL")
        }
        
    }
    
}

class Model {
    
    var beers: [Beer] = [Beer]()
    
    var favouriteBeers: [Beer] = [Beer]()
    
    var favouritesById: [FavouriteBeer] = [FavouriteBeer]()
    
    var page: Int = 1

    func ready(callback: @escaping (Model, String?) -> Void) {
        self.favouritesById.append(FavouriteBeer(id: 99))
        self.favouritesById.append(FavouriteBeer(id: 100))
        
        Promise.all(
            HTTPService.getBeers(page: self.page, name: nil, abv: nil),
            HTTPService.getFavouriteBeers(ids: getFavouriteIds())
        ).then({ (responses: [Response]) in
            do {
                self.beers = try JSONDecoder().decode([Beer].self, from: responses[0].data)
                self.favouriteBeers = try JSONDecoder().decode([Beer].self, from: responses[1].data)
                callback(self, nil)
            } catch {
                callback(self, "Could not decode JSON")
            }
        }, { (responseError) in
            callback(self, "Call to remote API failed")
        })
    }
    
    func getFavouriteIds() -> String {
        return self.favouritesById.reduce("") { (accumulator: String, current: FavouriteBeer) -> String in
            return (accumulator == "") ? "\(current.id)" : "\(accumulator)|\(current.id)"
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
                model.favouriteBeers.forEach {
                    beer in print(beer.id)
                }
                model.beers.forEach {
                    beer in print(beer.id)
                }
            }
        }
    }
    
}

let controller = Controller()
