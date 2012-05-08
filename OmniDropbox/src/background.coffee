dropbox = new Dropbox
dropbox.authorize().then () ->

    chrome.omnibox.setDefaultSuggestion
        description: "Search Dropbox"

    # Fired every time the user updates the omnibox text.
    chrome.omnibox.onInputChanged.addListener (text, suggest) ->
        if text
            dropbox.search "",
                query: text
                file_limit: 5
            .then (results) ->
                suggestions = []
                textPattern = new RegExp text, "g"
                for result in results
                    console.log result
                    # Strip leading "/"
                    path = result.path.replace /^\//, ""
                    result.mime_type
                    result.modified
                    # Emphasize matching text
                    description = path.replace textPattern,
                        (match) -> "<match>#{match}</match>"
                    # Append file size
                    description += " - <dim>#{result.size}</dim>"
                    suggestions.push
                        content: path
                        description: description

                suggest suggestions

    # Fired when the user accepts the omnibox input.
    chrome.omnibox.onInputEntered.addListener (text) ->
        alert('You just typed "' + text + '"')
