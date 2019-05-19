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

The full code is located at the bottom of the article, you are welcome to skip straight to the code.
## Pre-requisites
This guide is focused solving asynchronous operations using callbacks. This is considered to be an advanced topic, as 
such it is required that readers should have an intermediate to advanced knowledge of programming to understand these 
concepts. However do not let this stop you if you wish to read. I will do my best to explain. 

You will need a good understanding of closures, for that I have another article that you may want to read, called 
[Swift 4 Closures & Higher Order Functions](https://github.com/pete-mann/swift4-closures). Head on over there and check 
it out first. We will also do some work using the `Decodable` protocol and `JSONDecoder`.
## Closures
I recently wrote an extensive article about closures, this article will compliment that article by extending it. So if 
you don't know what closures are, please read 
[my article on closures first.](https://github.com/pete-mann/swift4-closures)
## What is a Promise

```
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
```
## What is `URLSession.shared.dataTask`
## What is `DispatchQueue.main.async`
## What is `@escaping`
## The Struct
```
struct Beer: Decodable {
    var id: Int
    var name: String
    var description: String
}
```
## The Model
```
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
```
## The Controller
I like to keep my controllers as small as possible, 
```
class Controller {
    
    var model: Model = Model()
    
    init() {
        model.ready { model in
            model.beers.forEach { print($0.name, $0.description) }
        }
    }
}
```
## The Loader Utility
```
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

```