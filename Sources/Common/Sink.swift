//
//  Sink.swift
//  CombineExt
//
//  Created by Shai Mishali on 14/03/2020.
//

import Combine

/// A generic sink using an underlying demand buffer to balance
/// the demand of a downstream subscriber for the events of an
/// upstream publisher
class Sink<Upstream: Publisher, Downstream: Subscriber> {
    typealias TransformFailure = (Upstream.Failure) -> Downstream.Failure?
    typealias TransformOutput = (Upstream.Output) -> Downstream.Input?

    private var buffer: DemandBuffer<Downstream>
    private var upstreamSubscription: Subscription?
    private let transformOutput: TransformOutput
    private let transformFailure: TransformFailure
    
    /// Initialize a new sink subscribing to the upstream publisher and
    /// fulfilling the demand of the downstream subscriber using a backpresurre
    /// demand-maintaining buffer.
    ///
    /// - parameter upstream: The upstream publisher
    /// - parameter downstream: The downstream subscriber
    /// - parameter transformOutput: Transform the upstream publisher's output type to the downstream's input type
    /// - parameter transformFailure: Transform the upstream failure type to the downstream's failure type
    init(upstream: Upstream,
         downstream: Downstream,
         transformOutput: @escaping TransformOutput,
         transformFailure: @escaping TransformFailure) {
        self.buffer = DemandBuffer(subscriber: downstream)
        self.transformOutput = transformOutput
        self.transformFailure = transformFailure
        upstream.subscribe(self)
    }
    
    func demand(_ demand: Subscribers.Demand) {
        let newDemand = buffer.demand(demand)
        upstreamSubscription?.requestIfNeeded(newDemand)
    }
    
    deinit { upstreamSubscription.kill() }
}

// MARK: - Subscriber Conformance
extension Sink: Subscriber {
    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
    }

    func receive(_ input: Upstream.Output) -> Subscribers.Demand {
        guard let input = transformOutput(input) else { return .none }
        return buffer.buffer(value: input)
    }

    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        switch completion {
        case .finished:
            buffer.complete(completion: .finished)
        case .failure(let error):
            guard let error = transformFailure(error) else { return }
            buffer.complete(completion: .failure(error))
        }
        
        upstreamSubscription.kill()
    }
}