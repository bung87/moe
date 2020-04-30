import unittest
import json
import moepkg/lsp/lspclient

test "Send initialize request":
  var client = initLspClient()

  let res = client.sendInitializeRequest

  check(res == %*{"capabilities":{"textDocumentSync":{"openClose":true,"change":1,"willSave":false,"willSaveWaitUntil":false,"save":{"includeText":true}},"hoverProvider":true,"completionProvider":{"resolveProvider":true,"triggerCharacters":["."," "]},"definitionProvider":true,"referencesProvider":true,"renameProvider":true}})
