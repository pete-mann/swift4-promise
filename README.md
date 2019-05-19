# Swift 4 Promises
## Introduction
Recently I had to write a model view controller program in Swift 4, that program was used to load data from a remote API,
decode and store the data in a model. The view was strictly not allowed to know anything about the implementation of 
data fetching, where the data came from or how it got it. To tackle this problem, I did some research and found that 
a popular approach was to use callbacks to handle the resolution of requests to a remote API.

This guide will focus on fetching data. Fetching data introduces asynchronous operations into our code, handling this 
specific problem requires some sort of callback mechanism so that the caller can be notified when the asynchronous job 
is done. 

This guide is a small program that you can run in a Swift Playground. Through out this guide I will address the code in 
logical sections being:
* `Model` class
* `Controller` class
* `Promise` class
* `URLLoaderUtility` utility
* Data `Struct`

This guide will use the [Punk API](https://punkapi.com/documentation/v2) to pull JSON data into our program.

The full code is located at the bottom of the article, you are welcome to skip straight to the code.
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
The concept is simple, instead of the `Controller` relying on the `URLLoaderUtility` by registering a callback on the 
`URLLoaderUtility` to be notified when the data is ready, we can obfuscate this operation by moving it into the `Model`.
This makes sense since our `Controller` should be nice and small and should not know anything about how the data is 
loaded from the remote API. Remember this was the brief.

But how can the `Controller` be notified if it does not know which class is loading the data? This is where the 
`Promise` is useful. Returning a `Promise` from the `URLLoaderUtility` means we can use the inversion of control (IoC) 
principle to decouple the `URLLoaderUtility` from the `Model`. Yes the `Model` still needs to know about the 
`URLLoaderUtility` but the dependency is only one way, not two. Therefore this reduces the coupling of our classes. A 
trade off here is that both classes `URLLoaderUtility` and `Model` now have another class to depend on. However as the 
program scales this trade off will be worth it.

So what does the `Promise` actually do? Well the publisher will tell the `Promise` that the asynchronous task is 
complete, where the subscriber being the `Model` is waiting to be notified of the task completion. So the `Promise` 
works like a message broker.

The `Model` calls the `.then()` method of the `Promise` - passing in methods for success and failure (error). When the 
asynchronous task is over it the `URLLoaderUtility` will determine if it was successful or not and call the appropriate 
method that was passed from the `Model` to the `Promise` in the `.then()`. Both of these success and failure callbacks 
passed into the `Promise` from the `Model` receive some context about the asynchronous HTTP operation, being the 
headers and body of the request. From there the the `Model` can decide on what to do next. 

This is a basic `Promise`, by no means is this comprehensive.
```
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
```
## What is `URLSession.shared.dataTask`
## What is `DispatchQueue.main.async`
## What is `@escaping`
## The Struct
The `Beer Struct` is basically a blue print for the `Beer` JSON object that will be received from the remote API. We 
want to decode an array of these objects, and to do that we need a `Struct`. It's pretty straight forward, just three
properties. However the data from the API is much more extensive, we're only concerned with getting some basic 
data for the purpose of an example.
```
struct Beer: Decodable {
    var id: Int
    var name: String
    var description: String
}
```
## The Model
The `Model` is 
```
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
                model.beers.forEach { print($0.name, $0.description) }
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
```
## Full code
```
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
```