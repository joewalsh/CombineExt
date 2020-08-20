//
//  AwaitAllTests.swift
//  CombineExtTests
//
//  Created by Joe Walsh on 8/18/20.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if !os(watchOS)
import Combine
import CombineExt
import XCTest

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class AwaitAllTests: XCTestCase {
    private var subscription: AnyCancellable!

    private enum TestError: Error {
        case anError
    }

    func testCollectionAwaitAllWithFinishedEvent() {
        let first = PassthroughSubject<Int, Never>()
        let second = PassthroughSubject<Int, Never>()
        let third = PassthroughSubject<Int, Never>()
        let fourth = PassthroughSubject<Int, Never>()

        var completed = false
        var results = [[Int]]()

        subscription = [first, second, third, fourth]
            .awaitAll()
            .sink(receiveCompletion: { _ in completed = true },
                  receiveValue: { results.append($0) })

        first.send(1)
        second.send(2)

        XCTAssertTrue(results.isEmpty)
        XCTAssertFalse(completed)

        third.send(3)
        fourth.send(4)

        XCTAssertEqual(results, [])
        XCTAssertFalse(completed)

        first.send(5)

        XCTAssertEqual(results, [])
        XCTAssertFalse(completed)

        fourth.send(6)

        XCTAssertEqual(results, [])
        XCTAssertFalse(completed)

        first.send(completion: .finished)

        XCTAssertEqual(results, [])
        XCTAssertFalse(completed)

        [second, third, fourth].forEach {
            $0.send(completion: .finished)
        }
        XCTAssertEqual(results, [[5, 2, 3, 6]])
        XCTAssertTrue(completed)
    }

    func testCollectionAwaitAllWithNoEvents() {
        let first = PassthroughSubject<Int, Never>()
        let second = PassthroughSubject<Int, Never>()

        var completed = false
        var results = [[Int]]()

        subscription = [first, second]
            .awaitAll()
            .sink(receiveCompletion: { _ in completed = true },
                  receiveValue: { results.append($0) })

        XCTAssertTrue(results.isEmpty)
        XCTAssertFalse(completed)
    }

    func testCollectionAwaitAllWithErrorEvent() {
        let first = PassthroughSubject<Int, TestError>()
        let second = PassthroughSubject<Int, TestError>()

        var completion: Subscribers.Completion<TestError>?
        var results = [[Int]]()

        subscription = [first, second]
            .awaitAll()
            .sink(receiveCompletion: { completion = $0 },
                  receiveValue: { results.append($0) })

        first.send(1)
        second.send(2)

        XCTAssertEqual(results, [])
        XCTAssertNil(completion)

        second.send(completion: .failure(.anError))

        XCTAssertEqual(completion, .failure(.anError))
    }

    func testCollectionAwaitAllWithASinglePublisher() {
        let first = PassthroughSubject<Int, Never>()

        var completed = false
        var results = [[Int]]()

        subscription = [first]
            .awaitAll()
            .sink(receiveCompletion: { _ in completed = true },
                  receiveValue: { results.append($0) })

        first.send(1)

        XCTAssertEqual(results, [])
        XCTAssertFalse(completed)

        first.send(completion: .finished)
        
        XCTAssertEqual(results, [[1]])
        XCTAssertTrue(completed)
    }

    func testCollectionAwaitAllWithNoPublishers() {
        var completed = false
        var results = [[Int]]()

        subscription = [AnyPublisher<Int, Never>]()
            .awaitAll()
            .sink(receiveCompletion: { _ in completed = true },
                  receiveValue: { results.append($0) })

        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(completed)
    }

    func testMethodAwaitAllWithFinishedEvent() {
        let first = PassthroughSubject<Int, Never>()
        let second = PassthroughSubject<Int, Never>()

        var completed = false
        var results = [[Int]]()

        subscription = first.awaitAll([second])
            .sink(receiveCompletion: { _ in completed = true },
                  receiveValue: { results.append($0) })

        first.send(1)
        second.send(2)

        XCTAssertEqual(results, [])
        XCTAssertFalse(completed)

        second.send(3)
        second.send(3)

        XCTAssertEqual(results, [])
        XCTAssertFalse(completed)

        first.send(completion: .finished)

        XCTAssertFalse(completed)

        second.send(completion: .finished)
        XCTAssertEqual(results, [[1, 3]])
        XCTAssertTrue(completed)
    }

    func testVariadicMethodAwaitAll() {
        let first = PassthroughSubject<Int, Never>()
        let second = PassthroughSubject<Int, Never>()
        let third = PassthroughSubject<Int, Never>()
        let fourth = PassthroughSubject<Int, Never>()
        let fifth = PassthroughSubject<Int, Never>()

        var results = [[Int]]()

        subscription = first.awaitAll(second, third, fourth, fifth)
            .sink(receiveValue: { results.append($0) })

        first.send(1)
        second.send(2)
        third.send(3)
        fourth.send(4)
        fifth.send(5)

        XCTAssertEqual(results, [])

        second.send(6)
        
        first.send(completion: .finished)
        second.send(completion: .finished)
        third.send(completion: .finished)
        fourth.send(completion: .finished)
        fifth.send(completion: .finished)

        XCTAssertEqual(results, [[1, 6, 3, 4, 5]])
    }
    
    func testArrayAwaitAllAsync() {
        let input = oneThousandInts
        let transform = squareTransform
        let publishers = asyncPublishers(with: input, transform: transform)
        let exp1 = expectation(description: "wait for completion")
        let exp2 = expectation(description: "wait for value")
        let expectedOutput = input.map(transform)

        subscription = publishers
            .awaitAll()
            .sink(receiveCompletion: { (result) in
                switch result {
                case .failure(let error):
                    XCTFail("Publisher failed with error: \(error)")
                case .finished:
                    XCTAssert(true)
                }
                exp1.fulfill()
            }) { (output) in
                XCTAssertEqual(output, expectedOutput, "Result is not the same as the expected")
                exp2.fulfill()
            }
        waitForExpectations(timeout: 5)
    }
    
    func testArrayAwaitAllFailure() {
        let input = oneThousandInts
        let transform = squareTransformFailingOnMod10
        let publishers = asyncPublishers(with: input, transform: transform)
        let exp = expectation(description: "wait for completion")
        subscription = publishers
            .awaitAll()
            .sink(receiveCompletion: { (result) in
                switch result {
                case .failure:
                    XCTAssert(true)
                case .finished:
                    XCTFail("Publisher failed to fail")
                }
                exp.fulfill()
            }) { (output) in
                XCTFail("Publisher failed to fail")
            }
        waitForExpectations(timeout: 5)
    }
    
    func testDictionaryAwaitAllAsync() {
        let input = oneThousandInts
        let transform = squareTransform
        let publishers = asyncPublishers(with: input, transform: transform)
        let publishersDictionary = Dictionary(uniqueKeysWithValues: zip(input, publishers))
        let expectedOutput = input.reduce(into: [Int: Int](minimumCapacity: input.count), { $0[$1] = transform($1) })
        let exp1 = expectation(description: "wait for completion")
        let exp2 = expectation(description: "wait for value")
        subscription = publishersDictionary
            .awaitAll()
            .sink(receiveCompletion: { (result) in
                switch result {
                case .failure(let error):
                    XCTFail("Publisher failed with error: \(error)")
                case .finished:
                    XCTAssert(true)
                }
                exp1.fulfill()
            }) { (output) in
                XCTAssertEqual(output, expectedOutput, "Result is not the same as the expected")
                exp2.fulfill()
            }
        waitForExpectations(timeout: 5)
    }
    
    
    func testDictionaryAwaitAllFailure() {
        let input = oneThousandInts
        let transform = squareTransformFailingOnMod10
        let publishers = asyncPublishers(with: input, transform: transform)
        let publishersDictionary = Dictionary(uniqueKeysWithValues: zip(input, publishers))
        let exp = expectation(description: "wait for completion")
        subscription = publishersDictionary
            .awaitAll()
            .sink(receiveCompletion: { (result) in
                switch result {
                case .failure:
                    XCTAssert(true)
                case .finished:
                    XCTFail("Publisher failed to fail")
                }
                exp.fulfill()
            }) { (output) in
                XCTFail("Publisher failed to fail")
            }
        waitForExpectations(timeout: 5)
    }
    
}
#endif
