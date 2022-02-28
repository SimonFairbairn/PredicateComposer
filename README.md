# PredicateComposer

Compose and reuse predicates for Core Data fetch requests in a convenient and type-safe way. 

No more looking up complex predicate patterns!

## Usage

For searching on a single attribute.

	import PredicateComposer

	let search = SearchFor(.attribute("text"), that: .containsCaseInsensitive("test"))
	
	let fetchRequest = Note.fetchRequest()
	fetchRequest.predicate = search.predicate()

For more complex searches:

	import PredicateComposer

	let search = SearchFor(.attribute("text"), that: .containsCaseInsensitive("test"))
		.or(SearchFor(.attribute("tags"), that: .haveAllOf( tag1, tag2 ) ) )).and(SearchFor(.entityRelationshipWithAttribute("revision", "date"), that: .isLessThan(Date())))
	
	let fetchRequest = Note.fetchRequest()
	fetchRequest.predicate = search.predicate()


Searches can be composed as needed:

	import PredicateComposer

	var search = SearchFor(.attribute("text"), that: .containsCaseInsensitive("test"))
	
	if filterFavourites {
		search = search.and( SearchFor(.attribute("isFavourite"), that: .isTrue) )
	}
	
	let fetchRequest = Note.fetchRequest()
	fetchRequest.predicate = search.predicate()
