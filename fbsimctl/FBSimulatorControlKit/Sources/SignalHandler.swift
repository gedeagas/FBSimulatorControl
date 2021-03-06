/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

import Foundation

@objc class SignalInfo: NSObject, EventReporterSubject {
  let signo: Int32
  let name: String

  init(signo: Int32, name: String) {
    self.signo = signo
    self.name = name
  }

  var jsonSerializableRepresentation: Any { get {
    return [
      "signo" : NSNumber(value: self.signo as Int32),
      "name" : self.name,
    ]
  }}

  override var description: String { get {
    return "\(self.name) \(self.signo)"
  }}

  var subSubjects: [FBEventReporterSubjectProtocol] { get {
    return [self]
  }}
}

let signalPairs: [SignalInfo] = [
  SignalInfo(signo: SIGTERM, name: "SIGTERM"),
  SignalInfo(signo: SIGHUP, name: "SIGHUP"),
  SignalInfo(signo: SIGINT, name: "SIGINT")
]

func ignoreSignal(_: Int32) {}

class SignalHandler {
  let callback: (SignalInfo) -> Void
  var sources: [DispatchSource] = []

  init(callback: @escaping (SignalInfo) -> Void) {
    self.callback = callback
  }

  func register() {
    self.sources = signalPairs.map { info in
      signal(info.signo, ignoreSignal)
      let source = DispatchSource.makeSignalSource(signal: info.signo, queue: DispatchQueue.main)
      source.setEventHandler {
        self.callback(info)
      }
      source.resume()
      return source as! DispatchSource
    }
  }

  func unregister() {
    for source in self.sources {
      source.cancel()
    }
  }

  static var future: FBFuture<SignalInfo> { get {
    // Setup the Signal Handling first, so sending a Signal cannot race with starting the relay.
    let future: FBMutableFuture<SignalInfo> = FBMutableFuture()
    let handler = SignalHandler { info in
      future.resolve(withResult: info)
    }
    handler.register()
    return future.onQueue(DispatchQueue.main, chain: { future in
      handler.unregister()
      return future
    }) as! FBFuture<SignalInfo>
  }}
}
