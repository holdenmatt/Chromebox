#
# Dropbox.coffee
#
# A Dropbox API client for Javascript.
# Intended for use in e.g. Chrome extensions.
#


# NOTE: Your consumer key/secret should never appear in client code like this.
# TODO: This needs to be fixed.
CONSUMER_KEY = "5y95sf8dgsiov5q"
CONSUMER_SECRET = "xq3uvt45e1imrzi"

ROOT_PATH = window.location.href.replace /[^\/]+\.html/, ""

URL =
    requestToken: "https://api.dropbox.com/1/oauth/request_token"
    authorize:    "https://www.dropbox.com/1/oauth/authorize"
    accessToken:  "https://api.dropbox.com/1/oauth/access_token"
    callback:      ROOT_PATH + "oauth_callback.html"


# Build a URL with given path and query parameters.
buildUrl = (path, params) ->
    encode = OAuth.urlencode
    qs = [encode(key) + "=" + encode(value or "") for own key, value of params].join("&")
    if qs then path + "?" + qs else path

# Escape a path string as a URI component (but leave '/' alone).
escapePath = (path = "") ->
    path = encodeURIComponent(path)
        .replace(/%2F/g, "/")
        .replace(/^\/+|\/+$/g, "")  # Strip leading/trailing '/'


# Save tokens persistently in localStorage.
Tokens =
    TOKEN: "oauth_token"
    TOKEN_SECRET: "oauth_token_secret"

    get: () ->
        return [
            localStorage.getItem(Tokens.TOKEN)
            localStorage.getItem(Tokens.TOKEN_SECRET)
        ]

    set: (token, token_secret) ->
        localStorage.setItem(Tokens.TOKEN, token)
        localStorage.setItem(Tokens.TOKEN_SECRET, token_secret)

    exist: () ->
        tokens = Tokens.get()
        return tokens[0]? and tokens[1]?

    clear: () ->
        localStorage.removeItem(Tokens.TOKEN)
        localStorage.removeItem(Tokens.TOKEN_SECRET)


# Fetch and store an OAuth access token and secret.
class OAuthClient
    constructor: () ->
        @oauth = new OAuth
            consumerKey: CONSUMER_KEY
            consumerSecret: CONSUMER_SECRET
            requestTokenUrl: URL.requestToken
            authorizationUrl: URL.authorize
            accessTokenUrl: URL.accessToken

    showError: (message) ->
        alert "Error: #{message}"

    # If we have a saved access token, call a callback immediately.
    # Otherwise start the OAuth dance by fetching a request token and
    # redirecting to the authorize page.
    authorize: (callback) =>

        success = () =>
            [token, token_secret] = @oauth.getAccessToken()
            Tokens.set token, token_secret

            callback = encodeURIComponent URL.callback
            @oauth.setCallbackUrl URL.callback
            url = URL.authorize + "?oauth_token=#{token}&oauth_callback=#{callback}"
            window.open url

        error = (response) =>
            console.log response
            @showError "Failed to fetch a request token"

        if Tokens.exist()
            [token, token_secret] = Tokens.get()
            @oauth.setAccessToken token, token_secret
            callback()
        else
            @oauth.fetchRequestToken success, error

    # Exchange our request token/secret for a persistent access token/secret.
    # Private: this is called by the oauth_callback page after authorization.
    _fetchAccessToken: () =>

        closeSelectedTab = () ->
            chrome.tabs.getSelected null, (tab) ->
                chrome.tabs.remove tab.id

        success = () =>
            [token, token_secret] = @oauth.getAccessToken()
            Tokens.set token, token_secret
            closeSelectedTab()

        error = (response) =>
            console.log response
            @showError "Failed to fetch an access token"
            closeSelectedTab()

        if Tokens.exist()
            [token, token_secret] = Tokens.get()
            @oauth.setAccessToken token, token_secret
            @oauth.fetchAccessToken success, error
        else
            @showError "Failed to retrieve a saved access token"


class Dropbox extends OAuthClient

    API_VERSION: "1"
    API_HOST: "api.dropbox.com"
    API_CONTENT_HOST: "api-content.dropbox.com"

    # Set the root for this client ("dropbox" or "sandbox").
    constructor: (@root = "sandbox") ->
        super

    # Wrapper to make a single API request and return a Promise for
    # the parsed JSON object or failed response.
    #
    # Args:
    #   method - An HTTP method (e.g. "PUT").
    #   target - The target URL with leading slash (e.g. '/metadata').
    #   data - Request data or parameters.
    #   headers - Additional HTTP headers.
    #
    # Returns:
    #   A jQuery.Deferred promise.
    #
    request: (method, target, data = {}, headers = {}) =>
        deferred = new jQuery.Deferred

        # Use the correct host for this target.
        host = @API_HOST
        if /^\/files|\/thumbnails/.test target
            host = @API_CONTENT_HOST

        target = escapePath target
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
                deferred.reject response

        return deferred.promise()

    # Return information about the user's account.
    account_info: () =>
        @request "GET", "/account/info"

    # Download a file, along with its metadata.
    get_file: (path = "", params = {}) =>
        @request "GET", "/files/#{@root}/#{path}", params

    # Upload a file.
    # TODO: make this work with a screenshot; how to handle content-type?
    put_file: (path = "", params = {}, fileData) =>
        target = buildUrl "/files_put/#{@root}/#{path}", params
        headers =
            "Content-Type": "text/plain"

        @request "PUT", target, fileData, headers

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

window.Dropbox = Dropbox
