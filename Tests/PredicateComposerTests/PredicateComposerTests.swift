import XCTest
import CoreData
@testable import PredicateComposer

enum NoteComposer : PredicateComposing {
	case searchString(String)
	case exactMatch(Note)
	case allMatching([Note])
	case tags([Tag],SearchType)
	case alternativeSearch([String])
	
	func requirements() -> (predicates:[PredicateStruct], combination: SearchType) {
		switch self {
		case .searchString(let search):
			return (predicates: [PredicateStruct(attribute: "text", predicateType: .containsCaseInsentive, arguments: search)], combination: .and)
		case .exactMatch(let example):
			return (predicates:[PredicateStruct(attribute: "self", predicateType: .equals, arguments: example)], combination: .and)
		case .allMatching(let notes):
			return (predicates:[PredicateStruct(attribute: "self", predicateType: .inArray, arguments: notes)], combination: .and)
		case .tags(let tags, let searchType):
			return (predicates:[
						PredicateStruct(attribute: "tags", predicateType: .subquery, arguments: tags, searchType: searchType)
			], combination: .and)
		case .alternativeSearch( let strings):
			return (predicates: strings.map({ PredicateStruct(attribute: "text", predicateType: .containsCaseInsentive, arguments: $0) }), combination: .or)
		}
	}
}


final class PredicateComposerTests: XCTestCase {
	
	static var model = CoreDataContainer()
		
    func test_PredicateComposer_stringSearchFortest_oneResult() {
	
		let exampleObjects = PredicateComposerTests.model.addExamples()
		
		let predicate = CoreDataPredicateComposer<Note>(requirements: [NoteComposer.searchString( "test" )] )
		let request = predicate.fetchRequest()
	
		do {
			let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)
			XCTAssertEqual(results.count, 1, "There should be exactly one result, \(results.count) found")
		} catch {
			XCTFail("Error fetching results: \(error)")
		}
		addTeardownBlock {

			PredicateComposerTests.model.remove(exampleObjects)
		}
    }

	func test_PredicateComposer_stringSearchForRandomString_zeroResults() throws {
		let exampleObjects = PredicateComposerTests.model.addExamples()
		
		var object = CoreDataPredicateComposer<Note>()
		object.add(NoteComposer.searchString("a missing string"))

		let request = object.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)
		XCTAssertEqual( 0,results.count, "There should be exactly zero results, \(results.count) found")
		addTeardownBlock {
			PredicateComposerTests.model.remove(exampleObjects)
		}
	}
	
	func test_PredicateComposer_equalsCaseMatches_oneResult() throws {
		let exampleObject = PredicateComposerTests.model.addExamples()
		
		var object = CoreDataPredicateComposer<Note>()
		object.add(NoteComposer.exactMatch(exampleObject.notes[1]))
		
		let request = object.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: false)]

		let string = exampleObject.notes[1].text!
		
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)
		XCTAssertEqual( 1,results.count, "There should be exactly one results, \(results.count) found")
		XCTAssertEqual(results.first?.text, string, "The retured results should have the string of the searched for object. Instead it has \(results.first?.text ?? "")")
		
		addTeardownBlock {
			PredicateComposerTests.model.remove(exampleObject)
		}
	}
	
	func test_PredicateComposer_arrayMatchLastTwoObjects_twoResults() throws {
		let exampleObjects = PredicateComposerTests.model.addExamples()
		
		var object = CoreDataPredicateComposer<Note>()
		object.add(NoteComposer.allMatching( Array(exampleObjects.notes[1...2]) ))
		
		let request = object.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)
		XCTAssertEqual( 2,results.count, "There should be exactly two results, \(results.count) found")
		
		XCTAssertEqual(results[0], exampleObjects.notes[1], "The first result should equal the second object added to the database")
		XCTAssertEqual(results[1], exampleObjects.notes[2], "The second result should equal the third object added to the database")
		
		addTeardownBlock {
			PredicateComposerTests.model.remove(exampleObjects)
		}
	}
	
	func test_PredicateComposer_tag1Ortag2_twoResults() throws {
		let exampleObjects = PredicateComposerTests.model.addExamples()
		
		var object = CoreDataPredicateComposer<Note>()
		object.add(NoteComposer.tags(exampleObjects.tags, .or))
		
		let request = object.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)
		XCTAssertEqual( 3,results.count, "There should be exactly three results, \(results.count) found")
		
		XCTAssertEqual(results[0], exampleObjects.notes[0], "The first result should equal the first object added to the database")
		XCTAssertEqual(results[1], exampleObjects.notes[1], "The second result should equal the second object added to the database")
		XCTAssertEqual(results[2], exampleObjects.notes[3], "The third result should equal the fourth object added to the database")
		
		addTeardownBlock {
			PredicateComposerTests.model.remove(exampleObjects)
		}
	}
	
	
	func test_PredicateComposer_lonelyTagOr_zeroResults() throws {
		let exampleObjects = PredicateComposerTests.model.addExamples()
		
		var object = CoreDataPredicateComposer<Note>()
		object.add(NoteComposer.tags([exampleObjects.tags[2]], .or))
		
		let request = object.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)
		XCTAssertEqual( 0,results.count, "There should be exactly zero results, \(results.count) found")
		
		addTeardownBlock {
			PredicateComposerTests.model.remove(exampleObjects)
		}
	}
	
	func test_PredicateComposer_tag1AndTag2_oneResult() throws {
		let exampleObjects = PredicateComposerTests.model.addExamples()
		
		var object = CoreDataPredicateComposer<Note>()
		object.add(NoteComposer.tags([exampleObjects.tags[0], exampleObjects.tags[1]], .and))
		
		let request = object.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)
		XCTAssertEqual(1, results.count, "There should be exactly one result, \(results.count) found")
		
		XCTAssertEqual(results[0], exampleObjects.notes[0], "The first result should equal the first object added to the database")
		
		addTeardownBlock {
			PredicateComposerTests.model.remove(exampleObjects)
		}
	}

	func test_PredicateComposer_note1AndNote3_twoResults() throws {
		let exampleObjects = PredicateComposerTests.model.addExamples()
		
		let object = CoreDataPredicateComposer<Note>(requirements: [NoteComposer.alternativeSearch(["test", "nothingburger"])])
		
		let request = object.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "added", ascending: true)]
		
		let results = try PredicateComposerTests.model.persistentContainer.viewContext.fetch(request)
		XCTAssertEqual(2, results.count, "There should be exactly two results, \(results.count) found")
		
		XCTAssertEqual(results[0], exampleObjects.notes[0], "The first result should equal the first object added to the database")
		XCTAssertEqual(results[1], exampleObjects.notes[1], "The second result should equal the second object added to the database")
		
		addTeardownBlock {
			PredicateComposerTests.model.remove(exampleObjects)
		}
	}
	
}
