#  Simple Networking

A crazy simple wrapper to iOS Foundation's URLSession.
There's a good chance you should consider using URLSession directly, since external dependencies are a bad idea,
or AlamoFire, if you're crazy enough to think they're not.

## Usage

Much of the design of SimpleNetworking came from the desired way of consuming it.
Specifically, I wanted to be able to configure global things once, and then easily add calls with their response
handlers wherever I wanted.

### Configuring SimpleNetworking

All requests are executed on an instance of `SimpleNetworking`.
You can and probably should create a singleton for each third party API you're reaching out to.

```swift
fileprivate var _manager = SimpleNetworking!
extension SimpleNetworking {
  class var shared: SimpleNetworking {
    if _manager == nil {
      _manager = SimpleNetworking(baseURL: URL("https://my.api")!)
    }
    return _manager
  }
}

// then elsewhere...
SimpleNetworking.shared.get("/path")...
```

By default, SimpleNetworking will create an ephemeral URLSession per instance of SimpleNetworking.
You can alternatively create your own and pass it in when initializing:

```swift
let manager = SimpleNetworking(baseURL: myURL, session: mySession)
```

### Simple GET Requests

SimpleNetworking currently only supports GET requests because that's all I need it to do.

```swift
SimpleNetworking.shared.get("/path") {(request) in
  return request.on(error: {(error) in
      print("error: \(error)")
    })
    .on(success: {(response) in
      print("response: \(response.json!)")
    })
}
```

Alternatively, you can build the request yourself, and execute it on an instance of `SimpleNetworking`:

```swift
SimpleNetworking.get("/path")
  .on(error: {(error) in
    print("error: \(error)")
  })
  .on(success: {(response) in
    print("response: \(response.json!)")
  })
  .execute(on: SimpleNetworking.shared)

// or

let request = SimpleNetworking.get("/path")
// ...
request.execute(on: SimpleNetworking.shared)
```

You can add as many handlers as you want, and the request won't be tried until you call execute
with an instance of SimpleNetworking.

#### Request Handlers

You'll most likely only need to handle error or success, as demonstrated above. 

However, you can also
handle cases by specific HTTP status codes. This is particularly helpful if you want to easily
retry a request upon receiving a specific status code, such as unauthorized if your session has expired.

HTTP status handlers are called first, and must return a boolean for whether to continue.

```swift
SimpleNetworking.shared.get("/path") {(req) in
  return req.on(httpStatus: 401, {(request, response) in
    print("got unauthorized: \(response)")
    SimpleNetworking.shared.defaultHeaders["Authorization"] = myAuthHeaderValue
    request.retry(on: SimpleNetworking.shared)
    return false
  })
}
```

Error handlers will be passed a `SimpleNetworkingError`, indicating what failed.
Your error handler can optionally include a second parameter which will be an optional response. This will be nil if the error happened before the request was made.

### Subclassing `SimpleNetworking`

If you're using an API that uses status codes correctly, you may want to add global handlers for certain status codes.
For example, if your API returns a 401 when your auth token has expired, you may want to attempt `n` retries
after getting a new auth token:

```swift
class MyAPIManager: SimpleNetworking {
  var token: String? {
    didSet { self.headers["X-Authorization"] = token }
  }

  func authenticate(_ callback: @escaping () -> Void) {
    self.get("/auth") {(request) in
      return request.accept(.json)
        .on(success: {[weak self] (response) in
          guard let self = self else { return }
          self.token = response.json?["token"] as? String
          callback()
        })
    }
  }

  override func execute(request: SimpleRequest) {
    if request.httpStatusHandlers[401] == nil {
      request.on(httpStatus: 401, {(request, _) in
        self.authenticate() { request.retry() }
        return false
      })
    }
    super.execute(request: request)
  }
}
```

This not only gives you a convenient means for getting an authentication token, but also will automatically
update it every time the remote returns a 401 indicating your auth token is no good.
(You'd probably also want to only execute the request if you already have an auth token.)

## Contributing

Feel free to submit a pull request!

If you need an xcode project to run this in, simply run:

```bash
swift package generate-xcodeproj
```

### Testing

Run unit tests against the application either in an xcodeproj you created by running
`swift package generate-xcodeproj`, or by running `swift build` and `swift test`.
