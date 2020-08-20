//
//  AwaitAll.swift
//  CombineExt
//
//  Created by Joe Walsh on 8/18/20.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if canImport(Combine)
import Combine
import Foundation

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Publisher {
    /// Projects `self` and a `Collection` of `Publisher`s onto a type-erased publisher that waits for all the publishers to finish and publishes an array of the inner publisher's values. If any of the inner publishers fails, the returned publisher will fail.
    ///
    /// - Parameter others: A `Collection`-worth of other publishers with matching output and failure types to combine with.
    ///
    /// - Returns: A publisher that waits until `self` and all `others` have finished and emits the results as an array.
      func awaitAll<Others: Collection>(_ others: Others)
          -> AnyPublisher<[Output], Failure>
          where Others.Element: Publisher, Others.Element.Output == Output, Others.Element.Failure == Failure {
        let allPublishers = [eraseToAnyPublisher()] + Array(others.map { $0.eraseToAnyPublisher() })
        return allPublishers.awaitAll()
      }

      /// Projects `self` and a `Collection` of `Publisher`s onto a type-erased publisher that waits for all the publishers to finish and publishes an array of the inner publisher's values. If any of the inner publishers fails, the returned publisher will fail.
      ///
      /// - Parameter others: A `Collection`-worth of other publishers with matching output and failure types to combine with.
      ///
      /// - Returns: A publisher that waits until `self` and all `others` have finished and emits the results as an array.
      func awaitAll<Other: Publisher>(_ others: Other...)
          -> AnyPublisher<[Output], Failure>
          where Other.Output == Output, Other.Failure == Failure {
        awaitAll(others)
      }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Collection where Element: Publisher {
    /// Projects a `Collection` of `Publisher`s onto a type-erased publisher that waits for all the publishers to finish and publishes an array of the inner publisher's values. If any of the inner publishers fails, the returned publisher will fail.
    ///
    /// - Returns: A publisher that waits until all publishers have finished and emits the results in an array in the same order as this collection.
    func awaitAll() -> AnyPublisher<[Element.Output], Element.Failure> {
        guard !isEmpty else {
            return Empty().eraseToAnyPublisher()
        }
        return enumerated()
            .map { offset, element in
                // include index in the downstream output
                element.map { ($0, offset) }
            }
            .merge()
            .reduce(into: [Element.Output?](repeating: nil, count: count)) {
                // re-assemble by index
                $0[$1.1] = $1.0
            }
            .map {
                let result = $0.compactMap { $0 }
                assert(result.count == self.count)
                return result
            }
            .eraseToAnyPublisher()
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Dictionary where Value: Publisher {
    /// Combines publishers in this collection and delivers all elements as a dictionary with the results mapped to the same keys.
    /// If any of the publishers in the collection fails, the returned publisher also fails.
    ///
    /// - Returns: A publisher that waits until all publishers have finished and emits the results as a dictionary with the output values mapped to the keys in this dictionary.
    func awaitAll() -> AnyPublisher<[Key: Value.Output], Value.Failure> {
        guard !isEmpty else {
            return Empty().eraseToAnyPublisher()
        }
        return map { key, value in
                // include key in the downstream output
                value.map { ($0, key) }
            }
            .merge()
            .reduce(into: [Key: Value.Output](minimumCapacity: count)) {
                $0[$1.1] = $1.0
            }
            .eraseToAnyPublisher()
    }
}
#endif
