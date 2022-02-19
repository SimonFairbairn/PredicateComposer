//
//  File.swift
//  
//
//  Created by Simon Fairbairn on 23/08/2020.
//

import CoreData
@testable import PredicateComposer

final class CoreDataContainer {
	let persistentContainer: NSPersistentContainer
	public init(testData: Bool = false, deleteExisting: Bool = false) {
		self.persistentContainer = {
			guard let url = Bundle.module.url(forResource: "Example", withExtension: "momd") else {
				fatalError("Couldn't load bundle!")
			}
			guard let model = NSManagedObjectModel(contentsOf: url) else {
				fatalError("Couldn't load model!")
			}
			let container = NSPersistentContainer(name: "Example", managedObjectModel: model)
			let description = NSPersistentStoreDescription()
			description.type = NSInMemoryStoreType
			container.persistentStoreDescriptions = [description]
			container.loadPersistentStores(completionHandler: { (_, error) in

				if let error = error as NSError? {
					fatalError("Unresolved error \(error), \(error.userInfo)")
				}

			})
			return container
		}()
	}

	func saveContext() {
		let context = persistentContainer.viewContext
		if context.hasChanges {
			do {
				try context.save()
			} catch {
				let nserror = error as NSError
				fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
			}
		}
	}

	func remove( _ objects: (notes: [Note], tags: [Tag]) ) {
		for obj in objects.notes {
			self.persistentContainer.viewContext.delete(obj)
		}
		for obj in objects.tags {
			self.persistentContainer.viewContext.delete(obj)
		}

		self.saveContext()
	}

	private func addExample( with string: String, isCompleted: Bool = false ) -> Note {
		let newExample = Note(context: self.persistentContainer.viewContext)
		newExample.text = string
		newExample.isCompleted = isCompleted
		newExample.added = Date()
		self.saveContext()
		return newExample
	}

	private func addTag( with string: String ) -> Tag {
		let newExample = Tag(context: self.persistentContainer.viewContext)
		newExample.name = string
		self.saveContext()
		return newExample
	}

	func addExamples() -> (notes: [Note], tags: [Tag]) {
		let strings = [
			"A test string to search on",
			"nothingburger",
			"without tags",
			"Tag 2"
		]
		let examples = strings.map({ self.addExample(with: $0, isCompleted: $0.contains("test string")) })

		let tags = [
			"Tag 1",
			"Tag 2",
			"Lonely Tag",
			"Tag 3"
		]
		let tagMOs = tags.map({ self.addTag(with: $0 )})

		examples[0].addToTags(NSSet(array: [tagMOs[0], tagMOs[1]] )) // Tag 1, Tag 2
		examples[1].addToTags(tagMOs[0]) // Tag 1
		examples[3].addToTags(NSSet(array: [tagMOs[1], tagMOs[3]] )) // Tag 2, Tag 3

		return (notes: examples, tags: tagMOs)
	}
}
