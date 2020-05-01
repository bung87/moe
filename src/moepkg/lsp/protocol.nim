type SymbolKind {.pure.} = enum
  File = 1
  Module = 2
  Namespace = 3
  Package = 4
  Class = 5
  Method = 6
  Property = 7
  Field = 8
  Constructor = 9
  Enum = 10
  Interface = 11
  Function = 12
  Variable = 13
  Constant = 14
  String = 15
  Number = 16
  Boolean = 17
  Array = 18
  Object = 19
  Key = 20
  Null = 21
  EnumMember = 22
  Struct = 23
  Event = 24
  Operator = 25
  TypeParameter = 26

type CompletionItemKind {.pure.} = enum
  Text = 1
  Method = 2
  Function = 3
  Constructor = 4
  Field = 5
  Variable = 6
  Class = 7
  Interface = 8
  Module = 9
  Property = 10
  Unit = 11
  Value = 12
  Enum = 13
  Keyword = 14
  Snippet = 15
  Color = 16
  File = 17
  Reference = 18
  Folder = 19
  EnumMember = 20
  Constant = 21
  Struct = 22
  Event = 23
  Operator = 24
  TypeParameter = 25

type ResourceOperationKind = enum
  create
  rename
  delete

type FailureHandlingKind = enum
  abort
  transactional
  undo
  textOnlyTransactional

type SymbolKindObj = ref object
  valueSet: seq[SymbolKind]

type WorkspaceSymbolClientCapabilities = ref object
  dynamicRegistration: bool
  symbolKind: seq[SymbolKindObj]

type DidChangeWatchedFilesClientCapabilities = ref object
  dynamicRegistration: bool

type DidChangeConfigurationClientCapabilities = ref object
  dynamicRegistration: bool

type WorkspaceEditClientCapabilities = ref object
  documentChanges: bool
  resourceOperations: seq[ResourceOperationKind]
  failureHandling: FailureHandlingKind

type ExecuteCommandClientCapabilities = ref object
  dynamicRegistration: bool

type TextDocumentSyncClientCapabilities = ref object
  dynamicRegistration: bool
  willSave: bool
  willSaveWaitUntil: bool
  didSave: bool

type CompletionItemTag = int
type TagSupport = ref object
  valueSet: seq[CompletionItemTag]

type MarkupKind = enum
  plaintext
  markdown

type CompletionItem = ref object
  snippetSupport: bool
  commitCharactersSupport: bool
  documentationFormat: seq[MarkupKind]
  deprecatedSupport: bool
  preselectSupport: bool
  tagSupport: TagSupport

type CompletionItemKindObj = ref object
  valueSet: seq[CompletionItemKind]

type CompletionClientCapabilities = ref object
  dynamicRegistration: bool
  completionItem: CompletionItem
  completionItemKind: CompletionItemKindObj
  contextSupport: bool

type HoverClientCapabilities = ref object
  dynamicRegistration: bool
  contentFormat: seq[MarkupKind]

type ParameterInformation = ref object
  labelOffsetSupport: bool

type SignatureInformation = ref object
  documentationFormat: seq[MarkupKind]
  parameterInformation: ParameterInformation

type SignatureHelpClientCapabilities = ref object
  dynamicRegistration: bool
  signatureInformation: SignatureInformation
  contextSupport: bool

type DeclarationClientCapabilities = ref object
  dynamicRegistration: bool
  linkSupport: bool

type DefinitionClientCapabilities = ref object
  dynamicRegistration: bool
  linkSupport: bool

type TypeDefinitionClientCapabilities = ref object
  dynamicRegistration: bool
  linkSupport: bool

type ImplementationClientCapabilities= ref object
  dynamicRegistration: bool
  linkSupport: bool

type ReferenceClientCapabilities = ref object
  dynamicRegistration: bool

type DocumentSymbolClientCapabilities = ref object
  dynamicRegistration: bool
  symbolKind: SymbolKindObj
  hierarchicalDocumentSymbolSupport: bool

## TODO: Fix?
type CodeActionKind = ref object
  valueSet: seq[string]

type CodeActionLiteralSupport = ref object
  codeActionKind: CodeActionKind
  isPreferredSupport: bool

type CodeActionClientCapabilities = ref object
  dynamicRegistration: bool
  codeActionLiteralSupport: CodeActionLiteralSupport
  codeActionKind:CodeActionKind
  isPreferredSupport: bool

type CodeLensClientCapabilities = ref object
  dynamicRegistration: bool

type DocumentLinkClientCapabilities = ref object
  dynamicRegistration: bool
  tooltipSupport: bool

type DocumentColorClientCapabilities = ref object
  dynamicRegistration: bool

type DocumentFormattingClientCapabilities = ref object
  dynamicRegistration: bool

type DocumentRangeFormattingClientCapabilities = ref object
  dynamicRegistration: bool

type DocumentOnTypeFormattingClientCapabilities = ref object
  dynamicRegistration: bool

type RenameClientCapabilities = ref object
  dynamicRegistration: bool
  prepareSupport: bool

type PublishDiabnosticsClientCapabilities = ref object
  dynamicRegistration: bool
  rangeLimit: int
  lineFoldingOnly: bool

type FoldingRangeClientCapabilities = ref object

type TextDocumentClientCapabilities = ref object
  synchronization: TextDocumentSyncClientCapabilities
  completion: CompletionClientCapabilities
  hover: HoverClientCapabilities
  signatureHelp: SignatureHelpClientCapabilities
  declaration: DeclarationClientCapabilities
  definition: DefinitionClientCapabilities
  typeDefinition: TypeDefinitionClientCapabilities
  implementation: ImplementationClientCapabilities
  references: ReferenceClientCapabilities
  documentHighlight: DocumentSymbolClientCapabilities
  documentSymbol: DocumentSymbolClientCapabilities
  codeAction: CodeActionClientCapabilities
  codeLens: CodeLensClientCapabilities
  documentLink: DocumentLinkClientCapabilities
  colorProvider: DocumentColorClientCapabilities
  formatting: DocumentFormattingClientCapabilities
  rangeFormatting: DocumentRangeFormattingClientCapabilities
  onTypeFormatting: DocumentOnTypeFormattingClientCapabilities
  rename: RenameClientCapabilities
  publishDiagnostics: PublishDiabnosticsClientCapabilities
  foldingRange: FoldingRangeClientCapabilities

type Workspace =  ref object
  applyEdit: bool
  workspaceEdit: WorkspaceEditClientCapabilities
  didChangeConfiguration: DidChangeConfigurationClientCapabilities
  didChangeWatchedFiles: DidChangeWatchedFilesClientCapabilities
  symbol: WorkspaceSymbolClientCapabilities
  executeCommand: ExecuteCommandClientCapabilities
  textDocument: TextDocumentClientCapabilities
  experimental: any

type ClientCapabilities = ref object
  workspace: Workspace

type DocumentUri = string

type WorkspaceFolder = ref object
  uri: DocumentUri
  name: string

type ClientInfo = ref object
  name: string
  version: string

type InitializeParams = ref object
  processId: int or float
  clientInfo: ClientInfo
  rootPath: string
  rootUri: string
  initializationOptions: any
  capabilities: ClientCapabilities
  trace: string
  workspaceFolders: seq[WorkspaceFolder]
