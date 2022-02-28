# PredicateComposer

Compose and reuse predicates and fetch requests in a convenient and type-safe way. No more will you have to look up those predicate patterns!

## Usage

For searching on a single attribute.

	let search = SearchFor(.attribute("text"), that: .containsCaseInsensitive("test"))
	
	let fetchRequest = Note.fetchRequest()
	fetchRequest.predicate = search.predicate()

For more complex searches:

	let search = SearchFor(.attribute("text"), that: .containsCaseInsensitive("test"))
		.and(SearchFor(.attribute("tags"), that: .haveAllOf( tag1, tag2 ) ) ))
	
	let fetchRequest = Note.fetchRequest()
	fetchRequest.predicate = search.predicate()

Searches can be composed as needed:

	var search = SearchFor(.attribute("text"), that: .containsCaseInsensitive("test"))
	
	if filterFavourites {
		search = search.and( SearchFor(.attribute("isFavourite"), that: .isTrue) )
	}
	
	let fetchRequest = Note.fetchRequest()
	fetchRequest.predicate = search.predicate()

