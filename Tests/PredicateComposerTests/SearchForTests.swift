//
//  SearchForTests.swift
//  
//
//  Created by Simon Fairbairn on 18/02/2022.
//

import XCTest
@testable import PredicateComposer

class SearchForTests: XCTestCase {

	var exampleObjects: ( notes: [Note], tags: [Tag] )!

	override func setUp() {
		self.exampleObjects = PredicateComposerTests.model.addExamples()
		super.setUp()
	}

	override func tearDown() {
		PredicateComposerTests.model.remove(exampleObjects)
		super.tearDown()
	}

}
