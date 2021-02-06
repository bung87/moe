import unittest

include moepkg/lsp/lspclient

test "Send initialize request":
  var client = initLspClient()

  client.sendInitializeRequest

  echo client.outputStream.readFrame

test "Send DidOpen request":
  var client = initLspClient()

  client.sendInitializeRequest

  const
    uri = ""
    languageId = ""
    version = 1
  client.sendDidOpenRequest(uri, languageId, version)

  echo client.outputStream.readFrame
