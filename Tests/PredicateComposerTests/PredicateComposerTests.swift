import XCTest
import CoreData
@testable import PredicateComposer

final class PredicateComposerTests: BaseTestCase {

    func test_PredicateComposer_stringSearchForTest_oneResult() throws {

		// Given
		let request = Note.fetchRequest()
		let search = SearchFor(.attribute("text"), that: .containsCaseInsensitive("test"))
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual(results.count, 1, "There should be exactly one result, \(results.count) found")
    }

	func test_PredicateComposer_stringSearchForRandomString_zeroResults() throws {

		// Given
		let search = SearchFor(.attribute("text"), that: .containsCaseInsensitive("a missing string"))

		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual( 0, results.count, "There should be exactly zero results, \(results.count) found")
	}

	func test_PredicateComposer_equalsCaseMatches_oneResult() throws {

		// Given
		let exampleObjectText = exampleObjects.notes[1].text!

		let search = SearchFor(.entity, that: .equals(exampleObjects.notes[1]))

		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: false)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual( 1, results.count, "There should be exactly one results, \(results.count) found")
		XCTAssertEqual(
			results.first?.text,
			exampleObjectText,
			"The retured results should have the string of the searched for object. Instead it has \(results.first?.text ?? "")"
		)

	}

	func test_PredicateComposer_arrayMatchLastTwoObjects_twoResults() throws {

		// Given
		let search1 = SearchFor(.entity, that: .isInArray(Array(exampleObjects.notes[1...2])))

		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search1.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual( 2, results.count, "There should be exactly two results, \(results.count) found")
		try XCTSkipIf(results.count != 2)
		XCTAssertEqual(
			results[0],
			exampleObjects.notes[1],
			"The first result should equal the second object added to the database"
		)
		XCTAssertEqual(
			results[1],
			exampleObjects.notes[2],
			"The second result should equal the third object added to the database"
		)
	}

	func test_PredicateComposer_tag1Ortag2_twoResults() throws {

		// Given
		let search = SearchFor(.attribute("tags"), that: .haveAtLeastOneOf(exampleObjects.tags))

		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual( 3, results.count, "There should be exactly three results, \(results.count) found")

		try XCTSkipIf(results.count != 3)

		XCTAssertEqual(
			results[0],
			exampleObjects.notes[0],
			"The first result should equal the first object added to the database"
		)
		XCTAssertEqual(
			results[1],
			exampleObjects.notes[1],
			"The second result should equal the second object added to the database"
		)
		XCTAssertEqual(
			results[2],
			exampleObjects.notes[3],
			"The third result should equal the fourth object added to the database"
		)
	}

	func test_PredicateComposer_noTag_zeroResults() throws {

		// Given
		let search = SearchFor(.attribute("tags"), that: .haveAtLeastOneOf([]))

		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual( 1, results.count, "There should be exactly one results, \(results.count) found")
		try XCTSkipIf(results.count != 1)
		XCTAssertEqual(
			results[0],
			exampleObjects.notes[2],
			"The first result should equal the third object added to the database"
		)
	}

	func test_PredicateComposer_lonelyTagOr_zeroResults() throws {

		// Given
		let search = SearchFor(.attribute("tags"), that: .haveAtLeastOneOf([exampleObjects.tags[2]]))

		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual( 0, results.count, "There should be exactly zero results, \(results.count) found")
	}

	func test_PredicateComposer_tag1AndTag2_oneResult() throws {

		// Given
		let search = SearchFor(.attribute("tags"), that: .haveAllOf([exampleObjects.tags[0], exampleObjects.tags[1]]))

		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual(1, results.count, "There should be exactly one result, \(results.count) found")
		try XCTSkipIf(results.count != 1)
		XCTAssertEqual(
			results[0],
			exampleObjects.notes[0],
			"The first result should equal the first object added to the database"
		)
	}

	func test_PredicateComposer_tag1AndTag2OrStringMatch_twoResults() throws {

		// Given
		let search = PredicateComposer(.or([
			SearchFor(.attribute("tags"), that: .haveAllOf([exampleObjects.tags[0], exampleObjects.tags[1]])),
			SearchFor(.attribute("text"), that: .containsCaseInsensitive("without"))
		]))

		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual(2, results.count, "There should be exactly two results, \(results.count) found")
		try XCTSkipIf(results.count != 2)
		XCTAssertEqual(
			results[0],
			exampleObjects.notes[0],
			"The first result should equal the first object added to the database"
		)
		let text = try XCTUnwrap(results[1].text)
		XCTAssert(text.contains("without"), "The second result should equal the third object added to the database: \(text)")
	}

	func test_PredicateComposer_tag2_oneResult() throws {

		// Given
		let search = SearchFor(.attribute("tags"), that: .haveAllOf([exampleObjects.tags[3]]))
		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual(1, results.count, "There should be exactly one result, \(results.count) found")
		try XCTSkipIf(results.count != 1)
		XCTAssertEqual(
			results[0],
			exampleObjects.notes[3],
			"The first result should equal the first object added to the database"
		)
	}

	func test_PredicateComposer_tag1_twoResult() throws {
		// Given
		let search = SearchFor(.attribute("tags"), that: .haveAllOf([exampleObjects.tags[0]]))
		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual(2, results.count, "There should be exactly two results, \(results.count) found")
		try XCTSkipIf(results.count != 2)
		XCTAssertEqual(
			results[0],
			exampleObjects.notes[0],
			"The first result should equal the first object added to the database"
		)
		XCTAssertEqual(
			results[1],
			exampleObjects.notes[1],
			"The second result should equal the second object added to the database"
		)
	}

	func test_PredicateComposer_note1AndNote3_twoResults() throws {

		// Given
		let search = PredicateComposer(.or([
			SearchFor(.attribute("text"), that: .containsCaseInsensitive("test")),
			SearchFor(.attribute("text"), that: .containsCaseInsensitive("nothingburger"))
		]))
		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual(2, results.count, "There should be exactly two results, \(results.count) found")
		try XCTSkipIf(results.count != 2)
		XCTAssertEqual(
			results[0],
			exampleObjects.notes[0],
			"The first result should equal the first object added to the database"
		)
		XCTAssertEqual(
			results[1],
			exampleObjects.notes[1],
			"The second result should equal the second object added to the database"
		)
	}

	func test_PredicateComposer_emptyPredicate_noCrash() throws {
		// Given
		let search = PredicateComposer()

		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual(
			exampleObjects.notes.count,
			results.count,
			"There should be exactly the same number of results as notes, \(results.count) found"
		)
	}

	func test_PredicateComposer_beginsWith_() throws {

		// Given
		let search = SearchFor(.attribute("text"), that: .beginsWithCaseInsensitive("NOTHING"))

		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual(1, results.count, "There should be exactly one note, \(results.count) found")
		try XCTSkipIf(results.count != 1)
		XCTAssertEqual(
			results[0].text,
			exampleObjects.notes[1].text,
			"The first result's text should equal the second object added to the database's text ('nothingburger')"
		)
	}

	func test_PredicateComposer_isTrue_oneResult() throws {

		// Given
		let search = SearchFor(.attribute("isCompleted"), that: .isTrue)

		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual(1, results.count, "There should be exactly one note, \(results.count) found")
		try XCTSkipIf(results.count != 1)
		XCTAssertTrue(results[0].isCompleted)
	}

	func test_PredicateComposer_isFalse_threeResults() throws {

		// Given
		let search = SearchFor(.attribute("isCompleted"), that: .isFalse)

		let request = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		request.predicate = search.predicate()

		// When
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)

		// Then
		XCTAssertEqual(3, results.count, "There should be three note, \(results.count) found")
		try XCTSkipIf(results.count != 3)
		XCTAssertFalse(results[0].isCompleted)
		XCTAssertFalse(results[1].isCompleted)
		XCTAssertFalse(results[2].isCompleted)
	}
}
