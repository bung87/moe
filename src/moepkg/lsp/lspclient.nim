import os, osproc, streams, json, options
import jsonschema
import baseprotocol

include messages

const
  jsonRpcversion = "2.0"
  nimlspPath = getHomeDir() & "/.nimble/bin/nimlsp"

type LspClient = object
  process: Process
  inputStream: Stream
  outputStream: Stream

proc sendInitializeRequest*(client: var LspClient): JsonNode =
  let
    capabilities = create(ClientCapabilities,
      workspace = none(WorkspaceClientCapabilities),
      textDocument = none(TextDocumentClientCapabilities),
      experimental = none(JsonNode)
    )

    processId = processID(client.process)
    rootPath = none(string)
    rootUri = "./"
    initializationOptions = none(JsonNode)
    workspaceFolders = none(seq[WorkspaceFolder])
    trace = none(string)

  const id = 0
  var req = create(RequestMessage, jsonRpcversion, id, "initialize", some(
    create(InitializeParams,
      processId,
      rootPath,
      rootUri,
      initializationOptions,
      capabilities,
      trace,
      workspaceFolders
    ).JsonNode)
  ).JsonNode

  client.inputStream.sendJson(req)

  # debug
  #echo "InitializeRequest"
  #echo req
  #echo ""

  var frame = client.outputStream.readFrame
  var message = frame.parseJson

  if message.isValid(ResponseMessage):
    let data = ResponseMessage(message)
    let resultMessage= data["result"]
    result = parseJson($resultMessage.get)

proc initLspClient*(): LspClient =
  result = LspClient()

  var process = startProcess(nimlspPath)

  result.process = process
  result.inputStream = process.inputStream()
  result.outputStream = process.outputStream()

var client = initLspClient()
echo client.sendInitializeRequest
