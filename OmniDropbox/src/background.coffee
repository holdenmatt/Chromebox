dropbox = new Dropbox "dropbox"
dropbox.authorize().then () ->

    chrome.omnibox.setDefaultSuggestion
        description: "Search Dropbox"

    # Search Dropbox whenever the omnibox text includes the "dropbox" keyword.
    chrome.omnibox.onInputChanged.addListener (text, suggest) ->
        if text
            textPattern = new RegExp text, "g"
            dropbox.search "/",
                query: text
                file_limit: 5
            .then (results) ->
                suggestions = []
                for result in results
                    # Strip leading "/"
                    path = result.path.replace /^\//, ""
                    # Emphasize matching text
                    description = path.replace textPattern,
                        (match) -> "<match>#{match}</match>"
                    # Style file path as a URL
                    description = "<url>" + description + "</url>"
                    # Append file size for files only
                    if not result.is_dir
                        description += " - <dim>#{result.size}</dim>"
                    suggestions.push
                        content: path
                        description: description

                suggest suggestions

    # Open the /shares link when an item is selected.
    chrome.omnibox.onInputEntered.addListener (text) ->
        dropbox.shares(text)
        .then (response) ->
            if response.url
                window.open response.url
