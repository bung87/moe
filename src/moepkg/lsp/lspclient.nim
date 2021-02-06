import os, osproc, streams, json, strutils, options
include protocol

const
  jsonRpcversion = "2.0"
  nimlspPath = getHomeDir() & ".nimble/bin/nimlsp"

type LspClient = object
  process: Process
  inputStream: Stream
  outputStream: Stream

proc initInitializeParams(): JsonNode =
  result = create(RequestMessage, "2.0", 0, "initialize", some(
    create(InitializeParams,
      workDoneToken = some(""),
      clientInfo = some(create(ClientInfo, name = "moe", version = some("0.2.0"))),
      processId = getCurrentProcessId(),
      rootPath = none(string),
      rootUri = "/home/fox/git/moe",
      initializationOptions = none(JsonNode),
      capabilities = create(ClientCapabilities,
        workspace = none(WorkspaceClientCapabilities),
        textDocument = none(TextDocumentClientCapabilities),
        window = none(WindowClientCapabilities),
        experimental = none(JsonNode)
      ),
      trace = none(string),
      workspaceFolders = none(seq[WorkspaceFolder])
    ).JsonNode)
  ).JsonNode

proc didOpenParams(uri, languageId: string, version: int): JsonNode =
  let text = if fileExists(uri): readFile(uri) else: ""

  result = create(RequestMessage, "2.0", 0, "textDocument/didOpen",
    some(create(DidOpenTextDocumentParams,
      textDocument = create(TextDocumentItem,
        uri = uri,
        languageId = languageId,
        version = version,
        text = text
      )
    ).JsonNode)
  ).JsonNode

proc sendFrame(s: Stream, frame: string) =
  s.write "Content-Length: " & $frame.len & "\r\n\r\n" & frame
  s.flush

proc sendJson(s: Stream, data: JsonNode) =
  var frame = newStringOfCap(1024)
  toUgly(frame, data)
  echo frame
  s.sendFrame(frame)
  echo "send"

proc readFrame*(s: Stream): string =
  let
    frame = string s.readLine
    len = parseInt((frame.splitWhitespace)[1])
  result = s.readStr(len)

proc sendInitializeRequest*(client: var LspClient) =
  var initializeParams = initInitializeParams()

  let id = 0

  var req = %*{
    "jsonrpc": jsonRpcversion,
    "id": id,
    "method": "initialize",
    "params": %initializeParams
  }

  client.inputStream.sendJson(req)

proc sendDidOpenRequest*(client: var LspClient,
                         uri, languageId: string,
                         version: int) =

  let id = 0

  var req = %*{
    "jsonrpc": jsonRpcversion,
    "id": id,
    "method": "textDocument/didOpen",
    "params": %didOpenParams(uri, languageId, version)
  }

  client.inputStream.sendJson(req)

proc initLspClient*(): LspClient =
  result = LspClient()

  var process: Process
  process = startProcess(nimlspPath)

  result.process = process
  result.inputStream = process.inputStream
  result.outputStream = process.outputStream
