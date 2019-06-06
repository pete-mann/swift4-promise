# Swift 4 Closures & Higher Order Functions, basic Promises
## Introduction
Recently I had to write a model view controller program in Swift 4, that program was used to load data from a remote API,
decode and store the data in a model. The view was strictly not allowed to know anything about the implementation of 
data fetching, where the data came from or how it got it. To tackle this problem, I did some research and found that 
a popular approach was to use callbacks to handle the resolution of requests to a remote API.

This guide will focus on fetching data. Fetching data introduces asynchronous operations into our code, handling this 
specific problem requires some sort of callback mechanism so that the caller can be notified when the asynchronous job 
is done. To do this we will be using the `Promise` pattern, this is similar to `Future` pattern.

This guide is a small program that you can run in a Swift Playground. Through out this guide I will address the code in 
logical sections being:
* `Model` class
* `Controller` class
* `Promise` class
* `URLLoaderUtility` utility
* Data `Struct`

This guide will use the [Punk API](https://punkapi.com/documentation/v2) to pull JSON data into our program.

The full code is located at the bottom of the article, you are welcome to skip straight to the code.

### What this guide is not
The code in guide is not a comprehensive `Promise` library like [PromiseKit](https://github.com/mxcl/PromiseKit). Nor 
is it perfect and tested production code. The code does not attempt to provide all of the functionality of promises, 
what we are aiming for is a succinct example of what a promise essentially _is_ and how they can benefit your code.
## Pre-requisites
This guide is focused solving asynchronous operations using callbacks. This is considered to be an advanced topic, as 
such it is required that readers should have an intermediate to advanced knowledge of programming to understand these 
concepts. However do not let this stop you if you wish to read. I will do my best to explain. 

You will need a good understanding of closures, for that I have another article that you may want to read, called 
[Swift 4 Closures & Higher Order Functions](https://github.com/pete-mann/swift4-closures). Head on over there and check 
it out first. We will also do some work using the `Decodable` protocol and `JSONDecoder`.
## Closures
I recently wrote an extensive article about closures, closures are used regularly in this article, I suggest reading 
up on closures if you don't already know about them. So if you don't know what closures are, check out my guide on using
[Swift 4 Closures & Higher Order Functions.](https://github.com/pete-mann/swift4-closures)

Since both the `Controller` and `Model` depend on the `Promise`, this guide will start by describing what a `Promise` 
is. So let's get into it.
## What is a Promise
A `Promise` as the name suggests is a guarantee of sorts that the caller will be provided with something as a 
placeholder in lieu of the final result. This is common for asynchronous operations. This is a basic `Promise`, by no 
means is this comprehensive. Normally a `Promise` object should include methods for `.reject()`, `.defer()` and possibly
more. Also promises are chainable which is something I have not coded in this guide. 

Promises afford an easy to use paradigm for handling asynchronous requests. The concept is simple, instead of the 
`Controller` relying on the `URLLoaderUtility` by registering a callback on the `URLLoaderUtility` to be notified when 
the data is ready, we can obfuscate this operation by moving it into the `Model`. This makes sense since our 
`Controller` should be nice and small and should not know anything about how the data is loaded from the remote API. 
Remember this was the brief.

But how can the `Controller` be notified if it does not know which class is loading the data? This is where the 
`Promise` is useful. Returning a `Promise` from the `URLLoaderUtility` means we can use the inversion of control (IoC) 
principle to decouple the `URLLoaderUtility` from the `Model`. Yes the `Model` still needs to know about the 
`URLLoaderUtility` but the dependency is only one way, not two. Therefore this reduces the coupling of our classes. A 
trade off here is that both classes `URLLoaderUtility` and `Model` now have another class to depend on. However as the 
program scales this trade off will be worth it.

So what does the `Promise` actually do? Well the publisher will tell the `Promise` that the asynchronous task is 
complete, where the subscriber being the `Model` is waiting to be notified of the task completion. So the `Promise` 
works like a message broker, or proxy for relaying actions between the publisher and subscriber.

The `Model` calls the `.then()` method of the `Promise` - passing in a callback method for success and error. When the 
asynchronous task is over it the `URLLoaderUtility` will determine if it was successful or not and call the appropriate 
method that was passed from the `Model` to the `Promise` in the `.then()` method. Both of these success and failure 
callbacks passed into the `Promise` from the `Model` receive some context about the asynchronous HTTP operation, being 
the headers and body of the request. From there the the `Model` can decide on what to do next. 
```
struct Response {
    var data: Data
    var urlResponse: URLResponse
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
```
## What problem does Promise solve?
Promises solve a few problems, the problems stem from asynchronous code that is executed within callbacks. These 
problems are known as "callback hell" where an asynchronous request depends on the result of another asynchronous 
request. This is common and may be unavoidable as an API consumer. When you have two fuctions that depend upon eachother 
like this, you typically end up with some type of spaghetti code that includes a nested asynchronous function. In turn 
the code will be difficult to read, difficult to change and all the while will likely have a lot of callback indenting 
also referred to as the lesser known "triangle of doom" or "pyramid of doom". This can be illustrated with the following
code.

In this example we have an asynchronous request that depends on the resolution of another asynchronous request. In this 
example we will be focusing on the `requestData` method. I want to point out the obvious problems of readability, 
understandability, extensibility, all created because of the indentation or nesting of callbacks in the `requestData` 
method. Remember that this is only two levels deep, we could exacerbate this problem by adding a few more nesting 
callbacks. What if one of the callbacks fails, well in that instance we need to add some recovery code to try and 
recover from the failure, probably also nested in here. What if the nesting was double the example that and you were 
asked to change the inner most part or one of the mid to outer methods? Not fun. There must be an easier way. Well yes 
there is and I promise to show you, the dad jokes are free.
```
func requestData(from: URL, _ callback: @escaping (Data?, Error?) -> ()) {
    URLSession.shared.dataTask(with: from) { data, _, error in
        if let error = error {
            DispatchQueue.main.async { callback(nil, error) }
            return
        }
        if let data = data {
            DispatchQueue.main.async { callback(data, nil) }
            return
        }
    }.resume()
}

var beersURL = URL(string: "https://api.punkapi.com/v2/beers")!

requestData(from: beersURL) { (data, error) in
    if let data = data {
        do {
            let beers = try JSONDecoder().decode([Beer].self, from: data)
            if let beerURL = URL(string: "https://api.punkapi.com/v2/beers/\(beers[0].id)") {
                requestData(from: beerURL) { (data, error) in
                    if let data = data {
                        do {
                            let beer = try JSONDecoder().decode([Beer].self, from: data)
                            print(beer)
                        } catch {
                            print("Could not decode beer JSON")
                        }
                    }
                    
                    if let error = error {
                        print(error)
                    }
                }
            }
        } catch {
            print("Could not decode beers JSON")
        }
    }
    
    if let error = error {
        print(error)
    }
}
```
## What is `URLSession.shared.dataTask`
[the `dataTask` method](https://developer.apple.com/documentation/foundation/urlsession/1411554-datatask)
## What is `DispatchQueue.main.async`
## What is `@escaping`
## The Struct
The `Beer Struct` is basically a blue print for the `Beer` JSON object that will be received from the remote API. We 
want to decode an array of these objects, and to do that we need a `Struct`. It's pretty straight forward, just three
properties. However the data from the API is much more extensive, we're only concerned with getting some basic 
data for the purpose of an example.
```
struct FavouriteBeer: Codable {
    var id: Int
}

struct Beer: Codable {
    let id: Int
    let name: String
    let tagline: String
}
```
## The Model
The `Model` is 
```
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
```
## The Controller
Generally I like to keep my controllers as small as possible, and for the purpose of this example there is no view. 
However consider that this `Controller` is a `ViewController`, in that case it could be many many lines long. Therefore
we don't want unnecessary code here, especially if it is creating dependencies that can be reduced through design 
choices. So the `Controller` only depends on the Model. 

Now the `Model` depends on the result of an asynchronous task, so in turn does the `Controller`. Therefore we again use
the higher order function `.ready(Model, String?)` on the `Model` by passing in a closure and waiting for the task to
finish. Upon completion we have the opportunity to handle the result in the view, for example if there is a recoverable
error we may show this to the user here. 
```
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
```
## The Loader Utility
The `URLLoaderUtility` 
```
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
```
## Full code
```
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
```