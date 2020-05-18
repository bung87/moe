import unittest

include moepkg/lsp/lspclient

test "Send initialize request":
  var client = initLspClient()

  client.sendInitializeRequest

  echo client.outputStream.readFrame
