import osproc, streams, json, jsonschema, options
#import messages, baseprotocol
import baseprotocol

include messages

const
  jsonRpcversion = "2.0"
  nimlspPath = "/home/fox/.nimble/bin/nimlsp"

type LspClient = object
  processID: int
  inputStream: Stream
  outputStream: Stream

proc sendInitializeRequest(client: var LspClient) =
  let
    capabilities = create(ClientCapabilities,
      workspace = none(WorkspaceClientCapabilities),
      textDocument = none(TextDocumentClientCapabilities),
      experimental = none(JsonNode)
    )

    processId = client.processID
    rootPath = none(string)
    rootUri = "./"
    initializationOptions = none(JsonNode)
    workspaceFolders = none(seq[WorkspaceFolder])
    trace = none(string)

  var req = create(RequestMessage, jsonRpcversion, 0, "initialize", some(
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
  echo "InitializeRequest"
  echo req
  echo ""

  var frame = client.outputStream.readFrame
  var message = frame.parseJson

  if message.isValid(ResponseMessage):
    let data = ResponseMessage(message)
    # debug
    echo "Reponce"
    echo data["result"]
    echo ""

proc initLspClient*(): LspClient =
  result = LspClient()

  var process = startProcess(nimlspPath)

  result.processID = process.processID
  result.inputStream = process.inputStream()
  result.outputStream = process.outputStream()

var client = initLspClient()
client.sendInitializeRequest
