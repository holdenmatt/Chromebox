###
Dropbox-sdk.js

A Dropbox SDK for Javascript.

Intended for use in e.g. Chrome extensions, where cross-domain AJAX calls
can be enabled.

Copyright 2012 Matt Holden (holden.matt@gmail.com)
###

ROOT_PATH = window.location.href.replace /[^\/]+\.html/, ""

URL =
    requestToken: "https://api.dropbox.com/1/oauth/request_token"
    authorize:    "https://www.dropbox.com/1/oauth/authorize"
    accessToken:  "https://api.dropbox.com/1/oauth/access_token"
    callback:      ROOT_PATH + "libs/oauth_callback.html"

# Save / retrieve / remove values in localStorage.
LocalStorage =
    set: (values) ->
        for own key, value of values
            localStorage.setItem key, value

    get: (keys...) ->
        values = [localStorage.getItem key for key in keys]
        if values.length == 1 then values[0] else values

    remove: (keys...) ->
        for key in keys
            localStorage.removeItem key


# Keep a list of all client instances.
OAuthClients = []

# Resolve any pending OAuthClient authorize calls.  This is needed to
# resolve background page callbacks from the oauth_callback page.
window.resolvePendingClients = () ->
    [token, token_secret] = LocalStorage.get "oauth_token", "oauth_token_secret"
    for client in OAuthClients
        if client.deferred?.state() == "pending"
            client.oauth.setAccessToken token, token_secret
            client.deferred.resolve()

# Fetch and store an OAuth access token and secret.
class OAuthClient
    constructor: (consumerKey, consumerSecret) ->
        if consumerKey? and consumerSecret?
            # Save values, so we can get them later in the OAuth flow.
            LocalStorage.set
                consumerKey: consumerKey
                consumerSecret: consumerSecret
        else
            # Get values saved earlier in the flow.
            [consumerKey, consumerSecret] = LocalStorage.get "consumerKey", "consumerSecret"
            if not (consumerKey? and consumerSecret?)
                throw new Error "Missing required consumerKey/consumerSecret"

        @oauth = new OAuth
            consumerKey: consumerKey
            consumerSecret: consumerSecret
            requestTokenUrl: URL.requestToken
            authorizationUrl: URL.authorize
            accessTokenUrl: URL.accessToken

        OAuthClients.push this

    # Return a jQuery.Deferred promise to authorize use of the Dropbox API.
    # Use .then to add success callbacks, and .fail for errbacks.
    # If we have a saved access token, then authorize succeeds.
    # Otherwise we start the OAuth dance by fetching a request token and
    # redirecting to the authorize page.
    authorize: () =>
        @deferred = new jQuery.Deferred

        [token, token_secret] = LocalStorage.get "oauth_token", "oauth_token_secret"
        if token? and token_secret?
            @oauth.setAccessToken token, token_secret
            @deferred.resolve()
        else
            success = () =>
                [token, token_secret] = @oauth.getAccessToken()
                LocalStorage.set
                    request_token: token
                    request_token_secret: token_secret

                # Open the authorize page with our callback.
                callback = encodeURIComponent URL.callback
                @oauth.setCallbackUrl URL.callback
                url = URL.authorize + "?oauth_token=#{token}&oauth_callback=#{callback}"
                window.open url

            error = (response) ->
                throw new Error "Failed to fetch a request token: " + response

            @oauth.fetchRequestToken success, error

        @deferred.promise()

    # Exchange our request token/secret for a persistent access token/secret.
    # Private: this is called by the oauth_callback page after authorization.
    _fetchAccessToken: () =>
        [token, token_secret] = LocalStorage.get "request_token", "request_token_secret"
        if not (token? and token_secret?)
            throw new Error "Failed to retrieve a saved request token"

        closeTab = () ->
            chrome.tabs.getSelected null, (tab) -> chrome.tabs.remove tab.id

        success = () =>
            [token, token_secret] = @oauth.getAccessToken()
            LocalStorage.set
                oauth_token: token
                oauth_token_secret: token_secret
            closeTab()

            # Resolve any background page OAuthClients.
            chrome.extension.getBackgroundPage()?.resolvePendingClients()


        error = (response) =>
            throw new Error "Failed to fetch an access token: " + response
            closeTab()

        @oauth.setAccessToken token, token_secret
        @oauth.fetchAccessToken success, error


class Dropbox extends OAuthClient

    API_VERSION: "1"
    API_HOST: "api.dropbox.com"
    API_CONTENT_HOST: "api-content.dropbox.com"

    # Set the root for this client ("dropbox" or "sandbox").
    constructor: (consumerKey, consumerSecret, @root = "sandbox") ->
        super consumerKey, consumerSecret

    # Wrapper to make a single API request and return a Promise for
    # the parsed JSON object or failed response.
    #
    # Args:
    #   method - An HTTP method (e.g. "PUT").
    #   target - The target URL with leading slash (e.g. '/metadata').
    #   params - Request parameters.
    #   body   - Request body.
    #   headers - Additional HTTP headers.
    #
    # Returns:
    #   A jQuery.Deferred promise.
    #
    request: (method, target, params = {}, body, headers) =>
        deferred = new jQuery.Deferred

        # Use the correct host for this target.
        host = @API_HOST
        if /^\/files|^\/thumbnails/.test target
            host = @API_CONTENT_HOST

        # Escape the path as a URI component (but leave '/' unchanged).
        target = encodeURIComponent(target)
            .replace(/%2F/g, "/")
            .replace(/^\/+|\/+$/g, "")  # Strip leading/trailing '/'

        if body?
            # Encode URL parameters if a separate request body is given.
            data = body
            qs = toQueryString params
            if qs then target += "?" + qs
        else
            data = params

        url = "https://#{host}/#{@API_VERSION}/#{target}"
        @oauth.request
            method: method
            url: url
            data: data
            headers: headers
            success: (response) ->
                headers = response?.responseHeaders
                contentType = headers?["Content-Type"]
                metadata = headers?["x-dropbox-metadata"]

                # Parse response text if JSON.
                value = response.text
                if contentType in ["application/json", "text/javascript"]
                    value = JSON.parse value

                # Parse metadata as JSON if present (e.g. /files and /thumbnails).
                metadata = response?.responseHeaders?["x-dropbox-metadata"]
                metadata = if metadata? then JSON.parse metadata

                if metadata?
                    deferred.resolve value, metadata
                else
                    deferred.resolve value
            failure: (response) ->
                console.log "Request failed: ", response
                deferred.reject response

        deferred.promise()

    # Return information about the user's account.
    account_info: () =>
        @request "GET", "/account/info"

    # Download a file, along with its metadata.
    get_file: (path = "", params = {}) =>
        @request "GET", "/files/#{@root}/#{path}", params

    # Upload a file.
    put_file: (path = "", params = {}, content = "", headers = {}) =>
        target = "/files_put/#{@root}/#{path}"
        @request "PUT", target, params, content, headers

    metadata: (path = "", params = {}) =>
        @request "GET", "/metadata/#{@root}/#{path}", params

    delta: (params = {}) =>
        @request "POST", "/delta", params

    revisions: (path = "", params = {}) =>
        @request "GET", "/revisions/#{@root}/#{path}", params

    restore: (path = "", params = {}) =>
        @request "POST", "/restore/#{@root}/#{path}", params

    search: (path = "", params = {}) =>
        @request "GET", "/search/#{@root}/#{path}", params

    shares: (path = "") =>
        @request "POST", "/shares/#{@root}/#{path}"

    media: (path = "") =>
        @request "POST", "/media/#{@root}/#{path}"

    # Get a thumbnail for an image, along with metadata.
    thumbnails: (path = "", params = {}) =>
        @request "GET", "/thumbnails/#{@root}/#{path}", params

    # Create and return a copy_ref to a file.
    copy_ref: (path = "") =>
        @request "GET", "/copy_ref/#{@root}/#{path}"

    # Copy a file or folder to a new location.
    file_copy: (from, to, params) =>
        @request "POST", "/fileops/copy",
            root: @root
            from_path: from
            to_path: to

    # Copy a file or folder specified by a copy_ref.
    file_copy_by_ref: (from, to, params) =>
        @request "POST", "/fileops/copy",
            root: @root
            from_copy_ref: from
            to_path: to

    # Create a folder.
    file_create_folder: (path) =>
        @request "POST", "/fileops/create_folder",
            root: @root
            path: path

    # Delete a file or folder.
    file_delete: (path) =>
        @request "POST", "/fileops/delete",
            root: @root
            path: path

    # Move a file or folder to a new location.
    file_move: (from, to, params = {}) =>
        @request "POST", "/fileops/move",
            root: @root
            from_path: from
            to_path: to


toQueryString = (params) ->
    encode = OAuth.urlEncode
    encoded = []
    for own key, value of params
        if key? and value?
            encoded.push encode(key) + "=" + encode(value)

    encoded.join "&"



# If this is the oauth_callback page, fetch the access token.
if /\/oauth_callback.html\?/.test window.location.href
    new Dropbox()._fetchAccessToken();


window.Dropbox = Dropbox
