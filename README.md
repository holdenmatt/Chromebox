## Chromebox: Search your Dropbox files from the Chrome search box (omnibox).

### Install

Download and open [Chromebox.crx](https://github.com/holdenmatt/Chromebox/raw/master/Chromebox.crx).

### Usage

Authorize Chromebox when you first install it.

To search your Dropbox files, just type "dbox" in the Chrome search box followed by search terms.

Type "dbox" and hit Enter to open Dropbox in a new tab.

### Uninstall

Go to chrome://extensions and remove the Chromebox extension.


## Dropbox-sdk.js: a JavaScript client SDK for the Dropbox API.

- Handles OAuth, token storage, response parsing, etc.

- Requires cross-domain AJAX calls, so only intended in e.g. Chrome extensions
where this can be enabled.

Install coffeescript:
```
$ npm install -g coffee-script
```

Build/watch:
```
$ cd Dropbox-sdk.js
$ coffee -o libs/ -cw src/
```
