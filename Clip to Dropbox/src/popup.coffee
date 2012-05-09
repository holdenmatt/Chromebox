# WARNING: consumer key/secret shouldn't appear in insecure code like this.
# TODO (Dropbox): Upgrade to OAuth 2.0.
CONSUMER_KEY = "87l32mwer3wakeq"
CONSUMER_SECRET = "tq9g12fobgymyqz"
dropbox = new Dropbox CONSUMER_KEY, CONSUMER_SECRET

getDate = () ->
    today = new Date
    year = today.getFullYear()
    month = today.getMonth() + 1    # Months are 0...11
    day = today.getDate()
    if month < 10 then month = "0" + month
    if day < 10 then day = "0" + day
    "#{year}-#{month}-#{day}"

dropbox.authorize().then () ->
    chrome.tabs.getSelected null, (tab) ->
        chrome.pageCapture.saveAsMHTML {tabId: tab.id}, (data) ->
            reader = new FileReader
            reader.onload = (e) ->
                title = tab.title or tab.url.split("?")[0]
                date = getDate()
                title += " - [#{date}]"
                alert title
                params =
                    overwrite: "false"
                headers =
                    "Content-Type": "multipart/related"
                dropbox.put_file title, params, @result, headers

            reader.readAsBinaryString data
