import os, osproc, streams, json, strutils
include protocol

const
  jsonRpcversion = "2.0"
  nimlspPath = getHomeDir() & ".nimble/bin/nimlsp"

type LspClient = object
  process: Process
  inputStream: Stream
  outputStream: Stream

proc initInitializeParams(): InitializeParams =
  var 
    workspaceEditClientCapabilities = WorkspaceEditClientCapabilities(
      documentChanges: false,
      resourceOperations: @[],
      failureHandling: FailureHandlingKind.undo,
    )
    didChangeConfigurationClientCapabilities = DidChangeConfigurationClientCapabilities(
      dynamicRegistration: false
    )
    didChangeWatchedFilesClientCapabilities = DidChangeWatchedFilesClientCapabilities(
      dynamicRegistration: false
    )
    workspaceSymbolClientCapabilities = WorkspaceSymbolClientCapabilities(
      dynamicRegistration: false,
      symbolKind: @[]
    )
    executeCommandClientCapabilities = ExecuteCommandClientCapabilities(
      dynamicRegistration: false
    )
    textDocumentSyncClientCapabilities = TextDocumentSyncClientCapabilities(
      dynamicRegistration: false,
      willSave: false,
      willSaveWaitUntil: false,
      didSave: false,
    )

    tagSupport = TagSupport(valueSet: @[])
    completionItem = CompletionItem(
      snippetSupport: false,
      commitCharactersSupport: false,
      documentationFormat: @[],
      deprecatedSupport: false,
      preselectSupport: false,
      tagSupport: tagSupport
    )
    completionItemKindObj = CompletionItemKindObj(
      valueSet: @[]
    )
    completionClientCapabilities = CompletionClientCapabilities(
      dynamicRegistration: false,
      completionItem: completionItem,
      completionItemKind: completionItemKindObj,
      contextSupport: false
    )
    hoverClientCapabilities = HoverClientCapabilities(
      dynamicRegistration: false,
      contentFormat: @[]
    )

    parameterInformation = ParameterInformation(
      labelOffsetSupport: false
    )
    signatureInformation = SignatureInformation(
      documentationFormat: @[],
      parameterInformation: parameterInformation
    )
    signatureHelpClientCapabilities = SignatureHelpClientCapabilities(
      dynamicRegistration: false,
      signatureInformation: signatureInformation,
      contextSupport: false,
    )

    declarationClientCapabilities = DeclarationClientCapabilities(
      dynamicRegistration: false,
      linkSupport: false
    )
    definitionClientCapabilities = DefinitionClientCapabilities(
      dynamicRegistration: false,
      linkSupport: false
    )
    typeDefinitionClientCapabilities = TypeDefinitionClientCapabilities(
      dynamicRegistration: false,
      linkSupport: false
    )
    implementationClientCapabilities = ImplementationClientCapabilities(
      dynamicRegistration: false,
      linkSupport: false
    )
    referenceClientCapabilities = ReferenceClientCapabilities(
      dynamicRegistration: false
    )

    symbolKindObj = SymbolKindObj(
      valueSet: @[]
    )
    documentSymbolClientCapabilities = DocumentSymbolClientCapabilities(
      dynamicRegistration: false,
      symbolKind: symbolKindObj,
      hierarchicalDocumentSymbolSupport: false
    )

    codeActionKind = CodeActionKind(
    valueSet: @[]
    )
    codeActionLiteralSupport = CodeActionLiteralSupport(
      codeActionKind: codeActionKind,
      isPreferredSupport: false
    )

    codeActionClientCapabilities = CodeActionClientCapabilities(
      dynamicRegistration: false,
      codeActionLiteralSupport: codeActionLiteralSupport,
      codeActionKind: codeActionKind,
      isPreferredSupport: false
    )

    codeLensClientCapabilities = CodeLensClientCapabilities(
      dynamicRegistration: false
    )
    documentLinkClientCapabilities = DocumentLinkClientCapabilities(
      dynamicRegistration: false,
      tooltipSupport: false
    )
    documentColorClientCapabilities = DocumentColorClientCapabilities(
    dynamicRegistration: false
    )
    documentFormattingClientCapabilities = DocumentFormattingClientCapabilities(
      dynamicRegistration: false
    )
    documentRangeFormattingClientCapabilities = DocumentRangeFormattingClientCapabilities(
      dynamicRegistration: false
    )
    documentOnTypeFormattingClientCapabilities = DocumentOnTypeFormattingClientCapabilities(
      dynamicRegistration: false
    )
    renameClientCapabilities = RenameClientCapabilities(
      dynamicRegistration: false,
      prepareSupport: false
    )
    publishDiabnosticsClientCapabilities = PublishDiabnosticsClientCapabilities(
      dynamicRegistration: false,
      rangeLimit: 0,
      lineFoldingOnly: false
    )

    textDocumentClientCapabilities = TextDocumentClientCapabilities(
      synchronization: textDocumentSyncClientCapabilities,
      completion: completionClientCapabilities,
      hover: hoverClientCapabilities,
      signatureHelp: signatureHelpClientCapabilities,
      declaration: declarationClientCapabilities,
      definition: definitionClientCapabilities,
      typeDefinition: typeDefinitionClientCapabilities,
      implementation: implementationClientCapabilities,
      references: referenceClientCapabilities,
      documentHighlight: documentSymbolClientCapabilities,
      documentSymbol: documentSymbolClientCapabilities,
      codeAction: codeActionClientCapabilities,
      codeLens: codeLensClientCapabilities,
      documentLink: documentLinkClientCapabilities,
      colorProvider: documentColorClientCapabilities,
      formatting: documentFormattingClientCapabilities,
      rangeFormatting: documentRangeFormattingClientCapabilities,
      onTypeFormatting: documentOnTypeFormattingClientCapabilities,
      rename: renameClientCapabilities,
      publishDiagnostics: publishDiabnosticsClientCapabilities,
      foldingRange: FoldingRangeClientCapabilities(),
    )

    workspace = Workspace(
      applyEdit: false,
      workspaceEdit: workspaceEditClientCapabilities,
      didChangeConfiguration: didChangeConfigurationClientCapabilities,
      didChangeWatchedFiles: didChangeWatchedFilesClientCapabilities,
      symbol: workspaceSymbolClientCapabilities,
      executeCommand: executeCommandClientCapabilities,
      textDocument: textDocumentClientCapabilities,
    )
    capabilities = ClientCapabilities(workspace: workspace)

  let 
    clientInfo = ClientInfo(name: "moe", version: "0.1.9")

  result.processId = 0
  result.clientInfo = clientInfo
  result.rootPath = ""
  result.rootUri = ""
  result.capabilities = capabilities
  result.trace = ""
  result.workspaceFolders = @[]

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
  initializeParams.processId = client.process.processID

  let id = 0

  var req = %*{
    "jsonrpc": jsonRpcversion,
    "id": id,
    "method": "initialize",
    "params": %initializeParams
  }

  client.inputStream.sendJson(req)

proc initLspClient*(): LspClient =
  result = LspClient()

  var process: Process
  process = startProcess(nimlspPath)

  result.process = process
  result.inputStream = process.inputStream
  result.outputStream = process.outputStream
