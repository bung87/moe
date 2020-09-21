import highlite, tables, times
import gapbuffer, unicodeext

type Mode* = enum
  normal,
  insert,
  visual,
  visualBlock,
  replace,
  ex,
  filer,
  bufManager,
  logViewer,
  help,
  recentFile,
  quickRun,
  history,
  diff,
  config

type SelectArea* = object
  startLine*: int
  startColumn*: int
  endLine*: int
  endColumn*: int

type BufferStatus* = object
  buffer*: GapBuffer[seq[Rune]]
  characterEncoding*: CharacterEncoding
  language*: SourceLanguage
  selectArea*: SelectArea
  isSearchHighlight*: bool
  path*: seq[Rune]
  openDir: seq[Rune]
  positionRecord*: Table[int, tuple[line, column, expandedColumn: int]]
  countChange*: int
  cmdLoop*: int
  mode* : Mode
  prevMode* : Mode
  lastSaveTime*: DateTime

proc initBufferStatus*(path: seq[Rune], mode: Mode): BufferStatus {.inline.} =
  BufferStatus(path: path, mode: mode, lastSaveTime: now())

proc isVisualMode*(mode: Mode): bool {.inline.} =
  mode == Mode.visual or mode == Mode.visualBlock

proc isFilerMode*(mode, prevMode: Mode): bool {.inline.} =
  (mode == Mode.filer) or (mode == Mode.ex and prevMode == Mode.filer)

proc isHistoryManagerMode*(mode, prevMode: Mode): bool {.inline.} =
  (mode == Mode.history) or (mode == Mode.ex and prevMode == Mode.history)

proc isDiffViewerMode*(mode, prevMode: Mode): bool {.inline.} =
  (mode == Mode.diff) or (mode == Mode.ex and prevMode == Mode.diff)

proc isConfigMode*(mode, prevMode: Mode): bool {.inline.} =
  (mode == Mode.config) or (mode == Mode.ex and prevMode == Mode.config)
