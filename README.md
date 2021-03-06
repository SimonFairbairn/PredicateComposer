# PredicateComposer

Compose and reuse predicates and fetch requests in a convenient and type-safe way.

## Usage

1. Set up a new enumeration for the entity you want to query on and conform to the `PredicateComposing` protocol:

		enum EntityComposer : PredicateComposing {

			func requirements() -> PredicateComposer? {
				return nil
			}
		}
		
2. Add a case for each type of predicate you want to create:

		enum EntityComposer : PredicateComposing {
			case searchString(String)

			func requirements() -> PredicateComposer? {
				return nil
			}
		}
		
3. Fill in the `requirements()` method, returing an array of one or more `PredicateStruct` types together with an indicator of how you want to combine them (`and` or `or`):

		enum EntityComposer : PredicateComposing {
			case searchString(String)

			func requirements() -> PredicateComposer? {
				switch self {
				case .searchString(let search):
					return PredicateComposer( predicates: [ PredicateStruct(attribute: "text", predicateType: .containsCaseInsentive, arguments: search) ] )
				}
			}
		}

4. Create a new `CoreDataPredicateComposer`, specify it to your Core Data entity, and pass in the requirement: 

		let search = CoreDataPredicateComposer<Entity>( EntityComposer.searchString(String) )
		
5. Get and execute the fetch request:

		let results = try context.execute(search.fetchRequest())
		
6. Alternatively, get just the predicate and use it anywhere you need a Core Data predicate (e.g. `@FetchRequest` in SwiftUI):

		@FetchRequest(entity: Entity.entity(), sortDescriptors: [], predicate:CoreDataPredicateComposer<Entity>(EntityComposer.searchString(String)).predicate)

## Advanced Usage

If your entities share similar attributes (e.g. an `id` or a `name` attribute), then predicates can easily be reused:


	enum UniversalPredicateComposer : PredicateComposing {
		case entityNamed( String )
		
		func requirements() -> PredicateComposer? {
			switch self {
			case .entityNamed(let name):
				return PredicateComposer( predicates: [ PredicateStruct(attribute: "name", predicateType: .beginsWithCaseInsensitive, arguments: search) ] )
			}
		}
	}
	
	let notesFetchRequest = CoreDataPredicateComposer<Note>( UniversalPredicateComposer.entityNamed( "Note name to search for" ) ).fetchRequest()
	let tagsFetchRequest = CoreDataPredicateComposer<Tag>( UniversalPredicateComposer.entityNamed( "Tag name to search for" ) ).fetchRequest()
	

## PredicateStruct

The `PredicateStruct` type is set up to limit the number of strings needed when setting up a predicate. Pass it the attribute you want to filter on, the type of predicate to use, and any optional arguments needed to fulfill that predicate.

Available predicate types:

		public enum PredicateType : String {
			case contains
			case containsCaseInsentive
			case equals
			case inArray
			case subquery
		}

## Examples

If we have two entities (`Note` and `Tag`), with a to-many relationship between them, we could create the following predicates on the `Note` entity:  


	enum NoteComposer : PredicateComposing {
		case searchString(String)
		case exactMatch(Note)
		case allMatching([Note])
		case tags([Tag], SearchType)
		case alternativeSearch([String])

		func requirements() -> (predicates:[PredicateStruct], combination: SearchType)? {
			switch self {
			case .searchString(let search):
				// 1.
				if search.isEmpty {
					return nil
				}
				return (predicates: [PredicateStruct(attribute: "text", predicateType: .containsCaseInsentive, arguments: search)], combination: .and)
			case .exactMatch(let example):
				// 2.
				return (predicates:[PredicateStruct(attribute: "self", predicateType: .equals, arguments: example)], combination: .and)
			case .allMatching(let notes):
				// 3.
				return (predicates:[PredicateStruct(attribute: "self", predicateType: .inArray, arguments: notes)], combination: .and)
			case .tags(let tags, let searchType):
				// 4.
				return (predicates:[
	PredicateStruct(attribute: "tags", predicateType: .manyToManySearch, arguments: tags, searchType: searchType)
	], combination: .and)
			case .alternativeSearch( let strings):
				// 5.
				return (predicates: strings.map({ PredicateStruct(attribute: "text", predicateType: .containsCaseInsentive, arguments: $0) }), combination: .or)
			}
		}
	}

1. Case-insensitive search on the `text` attribute of the `Note` entity, but only if the search string is not empty.
2. Exact match of the given `Note` object.
3. All notes that appear in the passed `Note` array.
4. If the passed `searchType` is `.and`, then the results will be any notes that are tagged with every tag in the passed `Tag` array. If the `searchType` is `.or`, then the results will be any notes that feature at least one of the tags in the passed `Tag` array (this uses a subquery as it is many-to-many operation).

This fourth type can be a little confusing, as a many to many search also needs to know how it should match the items within the search (`and` if it should match notes that have *all* the included tags, or `or` if it should match the notes with *any* included tags). 

However, the predicates can also be combined in the same way, so you can have a predicate that says: Match notes that have all of the included tags (an `and` search type on the many to many relationship) OR match notes where the text contains "foo".

The general rule is that a `.manyToManySearch` should also specify its `SearchType` to make it clear how that inner search should be conducted 

5. Searches for notes where the text contains any of the strings in the passed array.
