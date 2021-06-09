import strutils, sequtils, os, osproc, random, strformat, options
import editorstatus, ui, gapbuffer, unicodeext, undoredostack, window,
       bufferstatus, movement, messages, settings, register, commandline

proc correspondingCloseParen(c: char): char =
  case c
  of '(': return ')'
  of '{': return '}'
  of '[': return ']'
  of '"': return  '\"'
  of '\'': return '\''
  else: doAssert(false, fmt"Invalid parentheses: {c}")

proc isOpenParen(ch: char): bool {.inline.} = ch in {'(', '{', '[', '\"', '\''}

proc isCloseParen(ch: char): bool {.inline.} = ch in {')', '}', ']', '\"', '\''}

proc nextRuneIs(bufStatus: var BufferStatus,
                windowNode: WindowNode,
                c: Rune): bool =

  let
    currentLine = windowNode.currentLine
    currentColumn = windowNode.currentColumn

  if bufStatus.buffer[currentLine].len > currentColumn:
    result = bufStatus.buffer[currentLine][currentColumn] == c

proc insertCharacter*(bufStatus: var BufferStatus,
                      windowNode: WindowNode,
                      autoCloseParen: bool, c: Rune) =

  let oldLine = bufStatus.buffer[windowNode.currentLine]
  var newLine = bufStatus.buffer[windowNode.currentLine]

  template insert = newLine.insert(c, windowNode.currentColumn)

  template moveRight = inc(windowNode.currentColumn)

  template inserted =
    if oldLine != newLine: bufStatus.buffer[windowNode.currentLine] = newLine
    inc(bufStatus.countChange)
    bufStatus.isUpdate = true

  if autoCloseParen and canConvertToChar(c):
    let ch = c.toChar
    if isCloseParen(ch) and bufStatus.nextRuneIs(windowNode, c):
      moveRight()
      inserted()
    elif isOpenParen(ch):
      insert()
      moveRight()
      newLine.insert(correspondingCloseParen(ch).ru, windowNode.currentColumn)
      inserted()
    else:
      insert()
      moveRight()
      inserted()
  else:
    insert()
    moveRight()
    inserted()

proc deleteParen*(bufStatus: var BufferStatus,
                  currentLine, currentColumn: int,
                  currentChar: Rune) =

  let buffer = bufStatus.buffer

  if isOpenParen(currentChar):
    var depth = 1
    let
      openParen = currentChar
      closeParen = correspondingCloseParen(openParen)
    for i in currentLine ..< buffer.len:
      for j in currentColumn ..< buffer[i].len:
        if buffer[i][j] == openParen: inc(depth)
        elif buffer[i][j] == closeParen: dec(depth)
        if depth == 0:
          var line = bufStatus.buffer[i]
          line.delete(j)
          bufStatus.buffer[i] = line
          return
  elif isCloseParen(currentChar):
    var depth = 1
    let
      closeParen = currentChar
      openParen = correspondingOpenParen(closeParen)
    for i in countdown(currentLine, 0):
      let startColumn = if i == currentLine: currentColumn - 1
                        else: buffer[i].high
      for j in countdown(startColumn, 0):
        if buffer[i][j] == closeParen: inc(depth)
        elif buffer[i][j] == openParen: dec(depth)
        if depth == 0:
          var line = bufStatus.buffer[i]
          line.delete(j)
          bufStatus.buffer[i] = line
          return

proc currentLineDeleteCharacterBeforeCursor(bufStatus: var BufferStatus,
                                            windowNode: WindowNode,
                                            autoDeleteParen: bool) =

  if windowNode.currentLine == 0 and windowNode.currentColumn == 0: return

  dec(windowNode.currentColumn)
  let
    currentChar = bufStatus.buffer[windowNode.currentLine][windowNode.currentColumn]
    oldLine     = bufStatus.buffer[windowNode.currentLine]
  var newLine   = bufStatus.buffer[windowNode.currentLine]
  newLine.delete(windowNode.currentColumn)

  if oldLine != newLine:
    bufStatus.buffer[windowNode.currentLine] = newLine

  if autoDeleteParen:
    bufStatus.deleteParen(windowNode.currentLine,
                          windowNode.currentColumn,
                          currentChar)

  if(bufStatus.mode == Mode.insert and
     windowNode.currentColumn > bufStatus.buffer[windowNode.currentLine].len):
    windowNode.currentColumn = bufStatus.buffer[windowNode.currentLine].len

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc currentLineDeleteLineBreakBeforeCursor*(bufStatus: var BufferStatus,
                                             windowNode: WindowNode,
                                             autoDeleteParen : bool) =

  if windowNode.currentLine == 0 and windowNode.currentColumn == 0: return

  windowNode.currentColumn = bufStatus.buffer[windowNode.currentLine - 1].len

  let oldLine = bufStatus.buffer[windowNode.currentLine - 1]
  var newLine = bufStatus.buffer[windowNode.currentLine - 1]
  newLine &= bufStatus.buffer[windowNode.currentLine]
  bufStatus.buffer.delete(windowNode.currentLine, windowNode.currentLine)
  if oldLine != newLine: bufStatus.buffer[windowNode.currentLine - 1] = newLine

  dec(windowNode.currentLine)

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc countSpaceBeginOfLine(line: seq[Rune], tabStop, currentColumn: int): int =
  for i in 0 ..< min(line.len, currentColumn):
    if isWhiteSpace(line[i]): result.inc
    else: break

proc keyBackspace*(bufStatus: var BufferStatus,
                   windowNode: WindowNode,
                   autoDeleteParen: bool,
                   tabStop: int) =

  if windowNode.currentColumn == 0:
    currentLineDeleteLineBreakBeforeCursor(bufStatus,
                                           windowNode,
                                           autoDeleteParen)
  else:
    let
      currentLine = windowNode.currentLine
      currentColumn = windowNode.currentColumn

      line = bufStatus.buffer[currentLine]
      numOfSpsce = line.countSpaceBeginOfLine(tabStop, currentColumn)
      numOfDelete = if numOfSpsce == 0 or currentColumn > numOfSpsce: 1
                    elif numOfSpsce mod tabStop != 0:
                      numOfSpsce mod tabStop
                    else:
                      tabStop

    for i in 0 ..< numOfDelete:
      currentLineDeleteCharacterBeforeCursor(bufStatus,
                                             windowNode,
                                             autoDeleteParen)

proc deleteBeforeCursorToFirstNonBlank*(bufStatus: var BufferStatus,
                                        windowNode: WindowNode) =

  if windowNode.currentColumn == 0: return
  let firstNonBlank = getFirstNonBlankOfLineOrFirstColumn(bufStatus, windowNode)

  for _ in firstNonBlank..max(0, windowNode.currentColumn-1):
    currentLineDeleteCharacterBeforeCursor(bufStatus, windowNode, false)

proc insertIndent(bufStatus: var BufferStatus,
                  windowNode: WindowNode,
                  tabStop: int) =

  # Auto indent if finish a previous line with ':'
  if bufStatus.buffer[windowNode.currentLine].len > 0 and
     bufStatus.buffer[windowNode.currentLine][^1] == ru':':
    let oldLine = bufStatus.buffer[windowNode.currentLine + 1]
    var newLine = bufStatus.buffer[windowNode.currentLine + 1]
    newLine &= repeat(' ', tabStop).toRunes
    if oldLine != newLine:
      bufStatus.buffer[windowNode.currentLine + 1] = newLine

  else:
    let
      count = countRepeat(
        bufStatus.buffer[windowNode.currentLine],
        Whitespace,
        0)
      indent = min(count, windowNode.currentColumn)

    let oldLine = bufStatus.buffer[windowNode.currentLine + 1]
    var newLine = bufStatus.buffer[windowNode.currentLine + 1]
    newLine &= repeat(' ', indent).toRunes
    if oldLine != newLine:
      bufStatus.buffer[windowNode.currentLine + 1] = newLine

proc keyEnter*(bufStatus: var BufferStatus,
               windowNode: WindowNode,
               autoIndent: bool,
               tabStop: int) =

  proc isWhiteSpaceLine(line: seq[Rune]): bool =
    result = true
    for r in line:
      if not isWhiteSpace(r): return false

  proc deleteAllCharInLine(line: var seq[Rune]) =
    for i in 0 ..< line.len: line.delete(0)

  bufStatus.buffer.insert(ru"", windowNode.currentLine + 1)

  if autoIndent:
    bufStatus.insertIndent(windowNode, tabStop)

    var startOfCopy = max(
      countRepeat(bufStatus.buffer[windowNode.currentLine], Whitespace, 0),
      windowNode.currentColumn)
    startOfCopy += countRepeat(bufStatus.buffer[windowNode.currentLine],
                               Whitespace, startOfCopy)

    block:
      let oldLine = bufStatus.buffer[windowNode.currentLine + 1]
      var newLine = bufStatus.buffer[windowNode.currentLine + 1]

      let
        line = windowNode.currentLine
        startCol = startOfCopy
        endCol = bufStatus.buffer[windowNode.currentLine].len
      newLine &= bufStatus.buffer[line][startCol ..< endCol]

      if oldLine != newLine:
        bufStatus.buffer[windowNode.currentLine + 1] = newLine

    block:
      let
        first = windowNode.currentColumn
        last = bufStatus.buffer[windowNode.currentLine].high
      if first <= last:
        let oldLine = bufStatus.buffer[windowNode.currentLine]
        var newLine = bufStatus.buffer[windowNode.currentLine]
        newLine.delete(first, last)
        if oldLine != newLine:
          bufStatus.buffer[windowNode.currentLine] = newLine

    inc(windowNode.currentLine)
    windowNode.currentColumn =
      countRepeat(bufStatus.buffer[windowNode.currentLine], Whitespace, 0)

    # Delete all characters in the previous line if only whitespaces.
    if windowNode.currentLine > 0 and
       isWhiteSpaceLine(bufStatus.buffer[windowNode.currentLine - 1]):

      let oldLine = bufStatus.buffer[windowNode.currentLine - 1]
      var newLine = bufStatus.buffer[windowNode.currentLine - 1]
      newLine.deleteAllCharInLine
      if newLine != oldLine:
        bufStatus.buffer[windowNode.currentLine - 1] = newLine
  else:
    block:
      let oldLine = bufStatus.buffer[windowNode.currentLine + 1]
      var newLine = bufStatus.buffer[windowNode.currentLine + 1]

      let
        line = windowNode.currentLine
        startCol = windowNode.currentColumn
        endCol = bufStatus.buffer[windowNode.currentLine].len
      newLine &= bufStatus.buffer[line][startCol ..< endCol]

      if oldLine != newLine:
        bufStatus.buffer[windowNode.currentLine + 1] = newLine

    block:
      let oldLine = bufStatus.buffer[windowNode.currentLine]
      var newLine = bufStatus.buffer[windowNode.currentLine]
      newLine.delete(windowNode.currentColumn,
                     bufStatus.buffer[windowNode.currentLine].high)
      if oldLine != newLine: bufStatus.buffer[windowNode.currentLine] = newLine

    inc(windowNode.currentLine)
    windowNode.currentColumn = 0
    windowNode.expandedColumn = 0

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc insertTab*(bufStatus: var BufferStatus,
               windowNode: WindowNode,
               tabStop: int,
               autoCloseParen: bool) {.inline.} =

  for i in 0 ..< tabStop:
    insertCharacter(bufStatus, windowNode, autoCloseParen, ru' ')

proc insertCharacterBelowCursor*(bufStatus: var BufferStatus,
                              windowNode: WindowNode) =

  let
    currentLine = windowNode.currentLine
    currentColumn = windowNode.currentColumn
    buffer = bufStatus.buffer

  if currentLine == bufStatus.buffer.high: return
  if currentColumn > buffer[currentLine + 1].high: return

  let
    copyRune = buffer[currentLine + 1][currentColumn]
    oldLine = buffer[currentLine]
  var newLine = buffer[currentLine]

  newLine.insert(copyRune, currentColumn)
  if newLine != oldLine:
    bufStatus.buffer[currentLine] = newLine
    inc windowNode.currentColumn

proc insertCharacterAboveCursor*(bufStatus: var BufferStatus,
                              windowNode: WindowNode) =

  let
    currentLine = windowNode.currentLine
    currentColumn = windowNode.currentColumn
    buffer = bufStatus.buffer

  if currentLine == 0: return
  if currentColumn > buffer[currentLine - 1].high: return

  let
    copyRune = buffer[currentLine - 1][currentColumn]
    oldLine = buffer[currentLine]
  var newLine = buffer[currentLine]

  newLine.insert(copyRune, currentColumn)
  if newLine != oldLine:
    bufStatus.buffer[currentLine] = newLine
    inc windowNode.currentColumn

# delete current word
proc deleteWord*(bufStatus: var BufferStatus,
                 windowNode: var WindowNode,
                 loop: int,
                 registers: var Registers,
                 registerName: string) =

  var deletedBuffer: seq[Rune]

  for i in 0 ..< loop:
    if bufStatus.buffer.len == 1 and
       bufStatus.buffer[windowNode.currentLine].len < 1: return
    elif bufStatus.buffer.len > 1 and
         windowNode.currentLine < bufStatus.buffer.high and
         bufStatus.buffer[windowNode.currentLine].len < 1:
      bufStatus.buffer.delete(windowNode.currentLine, windowNode.currentLine + 1)

      if windowNode.currentLine > bufStatus.buffer.high:
        windowNode.currentLine = bufStatus.buffer.high
    elif windowNode.currentColumn == bufStatus.buffer[windowNode.currentLine].high:
      let oldLine = bufStatus.buffer[windowNode.currentLine]
      var newLine = bufStatus.buffer[windowNode.currentLine]
      deletedBuffer = @[oldLine[windowNode.currentColumn]]
      newLine.delete(windowNode.currentColumn)

      if oldLine != newLine:
        bufStatus.buffer[windowNode.currentLine] = newLine

      if windowNode.currentColumn > 0: dec(windowNode.currentColumn)
    else:
      let
        currentLine = windowNode.currentLine
        currentColumn = windowNode.currentColumn
        startWith = if bufStatus.buffer[currentLine].len == 0: ru'\n'
                    else: bufStatus.buffer[currentLine][currentColumn]
        isSkipped = if unicodeext.isPunct(startWith): unicodeext.isPunct elif
                       unicodeext.isAlpha(startWith): unicodeext.isAlpha elif
                       unicodeext.isDigit(startWith): unicodeext.isDigit
                    else: nil

      if isSkipped == nil:
        (windowNode.currentLine, windowNode.currentColumn) =
          bufStatus.buffer.next(currentLine, currentColumn)
      else:
        while true:
          inc(windowNode.currentColumn)
          if windowNode.currentColumn >= bufStatus.buffer[windowNode.currentLine].len:
            break
          if not isSkipped(bufStatus.buffer[windowNode.currentLine][windowNode.currentColumn]):
            break

      while true:
        if windowNode.currentColumn > bufStatus.buffer[windowNode.currentLine].high:
          break
        let curr =
          bufStatus.buffer[windowNode.currentLine][windowNode.currentColumn]
        if isPunct(curr) or isAlpha(curr) or isDigit(curr): break
        inc(windowNode.currentColumn)

      let oldLine = bufStatus.buffer[currentLine]
      var
        newLine = bufStatus.buffer[currentLine]
      for i in currentColumn ..< windowNode.currentColumn:
        deletedBuffer.add newLine[currentColumn]
        newLine.delete(currentColumn)
      if oldLine != newLine:
        bufStatus.buffer[currentLine] = newLine

      windowNode.expandedColumn = currentColumn
      windowNode.currentColumn = currentColumn

  if registerName.len > 0:
    registers.addRegister(deletedBuffer, registerName)
  else:
    const
      isLine = false
      isDelete = true
    registers.addRegister(deletedBuffer, isLine, isDelete)

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc deleteWord(bufStatus: var BufferStatus,
                windowNode: var WindowNode,
                loop: int,
                registers: var Registers) =

  const registerName = ""
  bufStatus.deleteWord(windowNode, loop, registers, registerName)

proc deleteWordBeforeCursor*(bufStatus: var BufferStatus,
                             windowNode: var WindowNode,
                             registers: var Registers,
                             registerName: string,
                             loop, tabStop: int) =

  if windowNode.currentLine == 0 and windowNode.currentColumn == 0: return

  if windowNode.currentColumn == 0:
    let isAutoDeleteParen = false
    bufStatus.keyBackspace(windowNode, isAutoDeleteParen, tabStop)
  else:
    bufStatus.moveToBackwardWord(windowNode)
    bufStatus.deleteWord(windowNode, loop, registers, registerName)

proc deleteWordBeforeCursor*(bufStatus: var BufferStatus,
                             windowNode: var WindowNode,
                             registers: var Registers,
                             loop, tabStop: int) =

  const registerName = ""
  bufStatus.deleteWordBeforeCursor(
    windowNode,
    registers,
    registerName,
    loop,
    tabStop)

proc countSpaceOfBeginningOfLine(line: seq[Rune]): int =
  for r in line:
    if r != ru' ': break
    else: result.inc

proc addIndent*(bufStatus: var BufferStatus,
                windowNode: WindowNode,
                tabStop: int) =

  let oldLine = bufStatus.buffer[windowNode.currentLine]
  var newLine = bufStatus.buffer[windowNode.currentLine]

  let
    numOfSpace = countSpaceOfBeginningOfLine(oldLine)
    numOfInsertSpace = if numOfSpace mod tabStop != 0: numOfSpace mod tabStop
                       else: tabStop

  newLine.insert(newSeqWith(numOfInsertSpace, ru' '), 0)
  if oldLine != newLine:
    bufStatus.buffer[windowNode.currentLine] = newLine
    windowNode.currentColumn = 0
    inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc deleteIndent*(bufStatus: var BufferStatus,
                   windowNode: WindowNode,
                   tabStop: int) =

  let
    oldLine = bufStatus.buffer[windowNode.currentLine]
    numOfSpace = countSpaceOfBeginningOfLine(oldLine)
    numOfDeleteSpace = if numOfSpace > 0 and numOfSpace mod tabStop != 0:
                         numOfSpace mod tabStop
                       elif numOfSpace > 0:
                         tabStop
                       else:
                         0

  if numOfDeleteSpace > 0:
    var newLine = bufStatus.buffer[windowNode.currentLine]

    for i in 0 ..< numOfDeleteSpace: newLine.delete(0, 0)

    if oldLine != newLine:
      bufStatus.buffer[windowNode.currentLine] = newLine
      inc(bufStatus.countChange)
      bufStatus.isUpdate = true

proc deleteCharactersBeforeCursorInCurrentLine*(bufStatus: var BufferStatus,
                                                windowNode: var WindowNode) =

  if windowNode.currentColumn == 0: return

  let
    currentLine = windowNode.currentLine
    currentColumn = windowNode.currentColumn
    oldLine = bufStatus.buffer[currentLine]
  var newLine = bufStatus.buffer[currentLine]

  newLine.delete(0, currentColumn - 1)

  if newLine != oldLine: bufStatus.buffer[currentLine] = newLine

proc addIndentInCurrentLine*(bufStatus: var BufferStatus,
                             windowNode: WindowNode,
                             tabStop: int) =

  bufStatus.addIndent(windowNode, tabStop)
  windowNode.currentColumn += tabStop

proc deleteIndentInCurrentLine*(bufStatus: var BufferStatus,
                                windowNode: WindowNode,
                                tabStop: int) =

  let oldLine = bufStatus.buffer[windowNode.currentLine]

  bufStatus.deleteIndent(windowNode, tabStop)

  if oldLine != bufStatus.buffer[windowNode.currentLine] and
     windowNode.currentColumn >= tabStop:
    windowNode.currentColumn -= tabStop

proc deleteCharacter*(bufStatus: var BufferStatus,
                      line, colmun: int,
                      autoDeleteParen: bool) =

  let
    currentLine = line
    currentColumn = colmun

  if currentLine >= bufStatus.buffer.high and
     currentColumn > bufStatus.buffer[currentLine].high: return

  if currentColumn == bufStatus.buffer[currentLine].len:
    let oldLine = bufStatus.buffer[line]
    var newLine = bufStatus.buffer[line]
    newLine.insert(bufStatus.buffer[currentLine + 1], currentColumn)
    if oldLine != newLine:
      bufStatus.buffer[line] = newLine

    bufStatus.buffer.delete(currentLine + 1, currentLine + 1)
  else:
    let
      currentChar = bufStatus.buffer[currentLine][currentColumn]
      oldLine = bufStatus.buffer[line]
    var newLine = bufStatus.buffer[line]
    newLine.delete(currentColumn)
    if oldLine != newLine: bufStatus.buffer[currentLine] = newLine

    if autoDeleteParen and currentChar.isParen:
      bufStatus.deleteParen(line,
                            colmun,
                            currentChar)

# Delete characters in the line
proc deleteCharacters*(bufStatus: var BufferStatus,
                       registers: var Registers,
                       registerName: string,
                       autoDeleteParen: bool,
                       line, colmun, loop: int) =

  if line >= bufStatus.buffer.high and
     colmun > bufStatus.buffer[line].high: return

  let oldLine = bufStatus.buffer[line]
  var newLine = bufStatus.buffer[line]

  var
    currentColumn = colmun

    deletedBuffer: seq[Rune]

  for i in 0 ..< loop:
    if newLine.len == 0: break

    let deleteChar = newLine[currentColumn]
    newLine.delete(currentColumn)

    deletedBuffer.add deleteChar

    if currentColumn > newLine.high: currentColumn = newLine.high

    if autoDeleteParen and deleteChar.isParen:
      bufStatus.deleteParen(
        line,
        colmun,
        deleteChar)

  if oldLine != newLine:
    bufStatus.buffer[line] = newLine

    const
      isLine = false
      isDelete = true

    if registerName.len > 0:
      registers.addRegister(deletedBuffer, registerName)
    else:
      registers.addRegister(deletedBuffer, isLine, isDelete)

# No yank buffer
proc deleteCharacters*(bufStatus: var BufferStatus,
                       autoDeleteParen: bool,
                       line, colmun, loop: int) =

  if line >= bufStatus.buffer.high and
     colmun > bufStatus.buffer[line].high: return

  let oldLine = bufStatus.buffer[line]
  var newLine = bufStatus.buffer[line]

  var
    currentColumn = colmun

    deletedBuffer: seq[Rune]

  for i in 0 ..< loop:
    if newLine.len == 0: break

    let deleteChar = newLine[currentColumn]
    newLine.delete(currentColumn)

    deletedBuffer.add deleteChar

    if currentColumn > newLine.high: currentColumn = newLine.high

    if autoDeleteParen and deleteChar.isParen:
      bufStatus.deleteParen(
        line,
        colmun,
        deleteChar)

  if oldLine != newLine:
    bufStatus.buffer[line] = newLine

# TODO: Delete deleteCurrentCharacter()
proc deleteCurrentCharacter*(bufStatus: var BufferStatus,
                             windowNode: WindowNode,
                             autoDeleteParen: bool) =

  let oldLine = bufStatus.buffer[windowNode.currentLine]

  deleteCharacter(bufStatus,
                  windowNode.currentLine,
                  windowNode.currentColumn,
                  autoDeleteParen)

  if oldLine != bufStatus.buffer[windowNode.currentLine]:
    if bufStatus.buffer[windowNode.currentLine].len < 1:
      windowNode.currentColumn = 0
      windowNode.expandedColumn = 0
    elif bufStatus.buffer[windowNode.currentLine].len > 0 and
         windowNode.currentColumn > bufStatus.buffer[windowNode.currentLine].high and
         bufStatus.mode != Mode.insert:
      windowNode.currentColumn = bufStatus.buffer[windowNode.currentLine].len - 1
      windowNode.expandedColumn = bufStatus.buffer[windowNode.currentLine].len - 1

    inc(bufStatus.countChange)
    bufStatus.isUpdate = true

proc openBlankLineBelow*(bufStatus: var BufferStatus, windowNode: WindowNode) =
  let
    indent = sequtils.repeat(
      ru' ',
      countRepeat(bufStatus.buffer[windowNode.currentLine],
      Whitespace,
      0))

  bufStatus.buffer.insert(indent, windowNode.currentLine + 1)
  inc(windowNode.currentLine)
  windowNode.currentColumn = indent.len

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc openBlankLineAbove*(bufStatus: var BufferStatus, windowNode: WindowNode) =
  let
    indent = sequtils.repeat(ru' ',
                             countRepeat(bufStatus.buffer[windowNode.currentLine],
                             Whitespace,
                             0))

  bufStatus.buffer.insert(indent, windowNode.currentLine)
  windowNode.currentColumn = indent.len

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

# Delete lines and store lines to the register
proc deleteLines*(bufStatus: var BufferStatus,
                  registers: var Registers,
                  windowNode: WindowNode,
                  registerName: string,
                  startLine, loop: int) =

  let endLine = min(startLine + loop, bufStatus.buffer.high)

  # Store lines to the register before delete them
  block:
    let buffer = bufStatus.buffer

    var deleteLines: seq[seq[Rune]]

    for i in startLine .. endLine: deleteLines.add(buffer[i])

    const isLine = true
    if registerName.len > 0:
      registers.addRegister(deleteLines, isLine, registerName)
    else:
      const isDelete = true
      registers.addRegister(deleteLines, isLine, isDelete)

  bufStatus.buffer.delete(startLine, endLine)

  if bufStatus.buffer.len == 0: bufStatus.buffer.insert(ru"", 0)

  if startLine < windowNode.currentLine: dec(windowNode.currentLine)
  if windowNode.currentLine >= bufStatus.buffer.len:
    windowNode.currentLine = bufStatus.buffer.high

  windowNode.currentColumn = 0
  windowNode.expandedColumn = 0

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc deleteCharacterUntilEndOfLine*(bufStatus: var BufferStatus,
                                    registers: var Registers,
                                    registerName: string,
                                    windowNode: WindowNode,
                                    autoDeleteParen: bool) =

  let
    currentLine = windowNode.currentLine
    startColumn = windowNode.currentColumn
    loop = bufStatus.buffer[currentLine].len - startColumn

  bufStatus.deleteCharacters(
    registers,
    registerName,
    autoDeleteParen,
    currentLine,
    startColumn,
    loop)

proc deleteCharacterBeginningOfLine*(bufStatus: var BufferStatus,
                                     registers: var Registers,
                                     windowNode: var WindowNode,
                                     registerName: string,
                                     autoDeleteParen: bool) =

  let
    currentLine = windowNode.currentLine
    startColumn = 0
    loop = windowNode.currentColumn

  bufStatus.deleteCharacters(
    registers,
    registerName,
    autoDeleteParen,
    currentLine,
    startColumn,
    loop)

  windowNode.currentColumn = 0
  windowNode.expandedColumn = 0

# Delete characters after blank in the current line
proc deleteCharactersAfterBlankInLine*(bufStatus: var BufferStatus,
                                       registers: var Registers,
                                       windowNode: var WindowNode,
                                       registerName: string,
                                       autoDeleteParen: bool) =

  let
    currentLine = windowNode.currentLine
    firstNonBlankCol = getFirstNonBlankOfLineOrFirstColumn(bufStatus, windowNode)
    loop = bufStatus.buffer[currentLine].len - firstNonBlankCol

  bufStatus.deleteCharacters(
    registers,
    registerName,
    autoDeleteParen,
    currentLine,
    firstNonBlankCol,
    loop)

  windowNode.currentColumn = firstNonBlankCol
  windowNode.expandedColumn = firstNonBlankCol

proc deleteTillPreviousBlankLine*(bufStatus: var BufferStatus,
                                  windowNode: WindowNode) =

  let
    currentLine = windowNode.currentLine
    blankLine = bufStatus.findPreviousBlankLine(currentLine)

  bufStatus.buffer.delete(blankLine + 1, currentLine)
  windowNode.currentLine = max(0, blankLine)
  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc deleteTillNextBlankLine*(bufStatus: var BufferStatus,
                              windowNode: WindowNode) =

  let currentLine = windowNode.currentLine
  var blankLine = bufStatus.findNextBlankLine(currentLine)
  if blankLine < 0: blankLine = bufStatus.buffer.len

  bufStatus.buffer.delete(currentLine, blankLine - 1)
  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc genDelimiterStr(buffer: string): string =
  while true:
    for _ in 0 .. 10: add(result, char(rand(int('A') .. int('Z'))))
    if buffer != result: break

proc sendToClipboad*(registers: Registers,
                     platform: Platform,
                     tool: ClipboardToolOnLinux) =

  let r = registers.noNameRegister

  if r.buffer.len < 1: return

  var buffer = ""
  if r.buffer.len == 1:
    buffer = $r.buffer
  else:
    for i in 0 ..< r.buffer.len:
      if i == 0: buffer = $r.buffer[0]
      else: buffer &= "\n" & $r.buffer[i]

  if buffer.len < 1: return

  let delimiterStr = genDelimiterStr(buffer)

  case platform
    of linux:
      ## Check if X server is running
      let (_, exitCode) = execCmdEx("xset q")
      if exitCode == 0:
        let cmd = if tool == ClipboardToolOnLinux.xclip:
                    "xclip -r <<" & "'" & delimiterStr & "'" & "\n" & buffer & "\n" & delimiterStr & "\n"
                  else:
                    "xsel <<" & "'" & delimiterStr & "'" & "\n" & buffer & "\n" & delimiterStr & "\n"
        discard execShellCmd(cmd)
    of wsl:
      let cmd = "clip.exe <<" & "'" & delimiterStr & "'" & "\n" & buffer & "\n"  & delimiterStr & "\n"
      discard execShellCmd(cmd)
    of mac:
      let cmd = "pbcopy <<" & "'" & delimiterStr & "'" & "\n" & buffer & "\n"  & delimiterStr & "\n"
      discard execShellCmd(cmd)
    else: discard

# name is the register name
proc yankLines*(bufStatus: BufferStatus,
                registers: var Registers,
                commandLine: var CommandLine,
                messageLog: var seq[seq[Rune]],
                notificationSettings: NotificationSettings,
                first, last: int,
                name: string,
                isDelete: bool) =

  var yankedBuffer: seq[seq[Rune]]
  for i in first .. last:
    yankedBuffer.add bufStatus.buffer[i]

  if name.len > 0:
    registers.addRegister(yankedBuffer, name)
  else:
    const isLine = true
    registers.addRegister(yankedBuffer, isLine, isDelete)

  commandLine.writeMessageYankedLine(
    yankedBuffer.len,
    notificationSettings,
    messageLog)

proc yankLines*(bufStatus: BufferStatus,
                registers: var Registers,
                commandLine: var CommandLine,
                messageLog: var seq[seq[Rune]],
                notificationSettings: NotificationSettings,
                first, last: int,
                isDelete: bool) =

  const name = ""
  bufStatus.yankLines(registers,
                      commandLine,
                      messageLog,
                      notificationSettings,
                      first, last,
                      name,
                      isDelete)


proc yankLines*(bufStatus: BufferStatus,
                registers: var Registers,
                commandLine: var CommandLine,
                messageLog: var seq[seq[Rune]],
                notificationSettings: NotificationSettings,
                first, last: int,
                name: string) =

  const isDelete = false
  bufStatus.yankLines(registers,
                      commandLine,
                      messageLog,
                      notificationSettings,
                      first, last,
                      name,
                      isDelete)

proc yankLines*(bufStatus: BufferStatus,
                registers: var Registers,
                commandLine: var CommandLine,
                messageLog: var seq[seq[Rune]],
                notificationSettings: NotificationSettings,
                first, last: int) =

  const
    name = ""
    isDelete = false
  bufStatus.yankLines(registers,
                      commandLine,
                      messageLog,
                      notificationSettings,
                      first, last,
                      name,
                      isDelete)

proc pasteLines(bufStatus: var BufferStatus,
                windowNode: var WindowNode,
                register: Register) =

  for i in 0 ..< register.buffer.len:
    bufStatus.buffer.insert(register.buffer[i],
                            windowNode.currentLine + i + 1)

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

# name is the register name
proc yankString*(bufStatus: BufferStatus,
                 registers: var Registers,
                 windowNode: WindowNode,
                 commandLine: var CommandLine,
                 messageLog: var seq[seq[Rune]],
                 platform: Platform,
                 settings: EditorSettings,
                 length: int,
                 name: string,
                 isDelete: bool) =

  var yankedBuffer: seq[Rune]

  if bufStatus.buffer[windowNode.currentLine].len > 0:
    for i in 0 ..< length:
      let
        col = windowNode.currentColumn + i
        line = windowNode.currentLine
      yankedBuffer.add bufStatus.buffer[line][col]

    if settings.clipboard.enable:
      registers.sendToClipboad(platform,
                               settings.clipboard.toolOnLinux)

    if name.len > 0:
      registers.addRegister(yankedBuffer, name)
    else:
      registers.addRegister(yankedBuffer)

  commandLine.writeMessageYankedCharactor(
    yankedBuffer.len,
    settings.notificationSettings,
    messageLog)

proc yankWord*(bufStatus: var BufferStatus,
               registers: var Registers,
               windowNode: WindowNode,
               platform: Platform,
               clipboardSettings: ClipBoardSettings,
               loop: int,
               name: string,
               isDelete: bool) =

  var yankedBuffer: seq[seq[Rune]] = @[ru ""]

  let line = bufStatus.buffer[windowNode.currentLine]
  var startColumn = windowNode.currentColumn

  for i in 0 ..< loop:
    if line.len < 1:
      yankedBuffer = @[ru ""]
      return
    if isPunct(line[startColumn]):
      yankedBuffer[0].add(line[startColumn])
      return

    for j in startColumn ..< line.len:
      let rune = line[j]
      if isWhiteSpace(rune):
        for k in j ..< line.len:
          if isWhiteSpace(line[k]): yankedBuffer[0].add(rune)
          else:
            startColumn = k
            break
        break
      elif not isAlpha(rune) or isPunct(rune) or isDigit(rune):
        startColumn = j
        break
      else: yankedBuffer[0].add(rune)

  const isLine = false
  if name.len > 0:
    registers.addRegister(yankedBuffer, isLine, name)
  else:
    registers.addRegister(yankedBuffer, isLine, isDelete)

  if clipboardSettings.enable:
    registers.sendToClipboad(platform,
                             clipboardSettings.toolOnLinux)

proc yankWord*(bufStatus: var BufferStatus,
               registers: var Registers,
               windowNode: WindowNode,
               platform: Platform,
               clipboardSettings: ClipBoardSettings,
               loop: int,
               isDelete: bool) =

  const name = ""
  bufStatus.yankWord(registers,
                     windowNode,
                     platform,
                     clipboardSettings,
                     loop,
                     name,
                     isDelete)

proc yankWord*(bufStatus: var BufferStatus,
               registers: var Registers,
               windowNode: WindowNode,
               platform: Platform,
               clipboardSettings: ClipBoardSettings,
               loop: int,
               name: string) =

  const isDelete = false
  bufStatus.yankWord(registers,
                     windowNode,
                     platform,
                     clipboardSettings,
                     loop,
                     name,
                     isDelete)

proc yankWord*(bufStatus: var BufferStatus,
               registers: var Registers,
               windowNode: WindowNode,
               platform: Platform,
               clipboardSettings: ClipBoardSettings,
               loop: int) =

  const
    name = ""
    isDelete = false
  bufStatus.yankWord(registers,
                     windowNode,
                     platform,
                     clipboardSettings,
                     loop,
                     name,
                     isDelete)

proc yankCharactersOfLines*(bufStatus: var BufferStatus,
                            windowNode: var WindowNode,
                            registers: var Registers,
                            isDelete: bool,
                            registerName: string) =

  let line = bufStatus.buffer[windowNode.currentLine]

  const isLine = false
  if registerName.len > 0:
    registers.addRegister(line, isLine, registerName)
  else:
    registers.addRegister(line, isLine, isDelete)

proc pasteString(bufStatus: var BufferStatus,
                 windowNode: var WindowNode,
                 register: Register) =

  let oldLine = bufStatus.buffer[windowNode.currentLine]
  var newLine = bufStatus.buffer[windowNode.currentLine]

  newLine.insert(register.buffer[^1], windowNode.currentColumn)

  if oldLine != newLine:
    bufStatus.buffer[windowNode.currentLine] = newLine

  windowNode.currentColumn += register.buffer[^1].high

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc pasteAfterCursor*(bufStatus: var BufferStatus,
                       windowNode: var WindowNode,
                       registers: Registers) =

  let r = registers.noNameRegister

  if r.buffer.len > 0:
    if r.isLine:
      bufStatus.pasteLines(windowNode, r)
    else:
      windowNode.currentColumn.inc
      bufStatus.pasteString(windowNode, r)

proc pasteAfterCursor*(bufStatus: var BufferStatus,
                       windowNode: var WindowNode,
                       registers: Registers,
                       registerName: string) =

  let r = registers.searchByName(registerName)

  if r.isSome:
    if r.get.isLine:
      bufStatus.pasteLines(windowNode, r.get)
    else:
      windowNode.currentColumn.inc
      bufStatus.pasteString(windowNode, r.get)

proc pasteBeforeCursor*(bufStatus: var BufferStatus,
                        windowNode: var WindowNode,
                        registers: Registers) =

  let r = registers.noNameRegister

  if r.buffer.len > 0:
    if r.isLine:
      bufStatus.pasteLines(windowNode, r)
    else:
      bufStatus.pasteString(windowNode, r)

proc pasteBeforeCursor*(bufStatus: var BufferStatus,
                        windowNode: var WindowNode,
                        registers: Registers,
                        registerName: string) =

  let r = registers.searchByName(registerName)

  if r.isSome:
    if r.get.isLine:
      bufStatus.pasteLines(windowNode, r.get)
    else:
      bufStatus.pasteString(windowNode, r.get)

proc replaceCurrentCharacter*(bufStatus: var BufferStatus,
                              windowNode: WindowNode,
                              autoIndent, autoDeleteParen: bool,
                              tabStop: int,
                              character: Rune) =

  if isEnterKey(character):
      bufStatus.deleteCurrentCharacter(windowNode, autoDeleteParen)
      keyEnter(bufStatus, windowNode, autoIndent, tabStop)
  else:
    let oldLine = bufStatus.buffer[windowNode.currentLine]
    var newLine = bufStatus.buffer[windowNode.currentLine]
    newLine[windowNode.currentColumn] = character
    if oldLine != newLine: bufStatus.buffer[windowNode.currentLine] = newLine

    inc(bufStatus.countChange)
    bufStatus.isUpdate = true

proc autoIndentCurrentLine*(bufStatus: var BufferStatus,
                            windowNode: var WindowNode) =

  let currentLine = windowNode.currentLine

  if currentLine == 0 or bufStatus.buffer[currentLine].len == 0: return

  # Check prev line indent
  var prevLineIndent = 0
  for r in bufStatus.buffer[currentLine - 1]:
    if r == ru' ': inc(prevLineIndent)
    else: break

  # Set indent in current line
  let
    indent = ru' '.repeat(prevLineIndent)
    oldLine = bufStatus.buffer[currentLine]
  var newLine = bufStatus.buffer[currentLine]

  # Delete current indent
  for i in 0 ..< oldLine.len:
    if oldLine[i] == ru' ':
      newLine.delete(0, 0)
    else: break

  newLine.insert(indent, 0)

  if oldLine != newLine: bufStatus.buffer[windowNode.currentLine] = newLine

  # Update colmn in current line
  windowNode.currentColumn = prevLineIndent

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc joinLine*(bufStatus: var BufferStatus, windowNode: WindowNode) =
  if windowNode.currentLine == bufStatus.buffer.len - 1 or
     bufStatus.buffer[windowNode.currentLine + 1].len < 1: return

  let oldLine = bufStatus.buffer[windowNode.currentLine]
  var newLine = bufStatus.buffer[windowNode.currentLine]
  newLine.add(bufStatus.buffer[windowNode.currentLine + 1])
  if oldLine != newLine: bufStatus.buffer[windowNode.currentLine] = newLine

  bufStatus.buffer.delete(windowNode.currentLine + 1,
                          windowNode.currentLine + 1)

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc deleteTrailingSpaces*(bufStatus: var BufferStatus) =
  var isChanged = false
  for i in 0 ..< bufStatus.buffer.high:
    let oldLine = bufStatus.buffer[i]
    var newLine = bufStatus.buffer[i]
    for j in countdown(newLine.high, 0):
      if newline[j] == ru' ': newline.delete(newline.high)
      else: break

    if oldLine != newLine:
      bufStatus.buffer[i] = newline
      isChanged = true

  if isChanged:
    inc(bufStatus.countChange)
    bufStatus.isUpdate = true

proc undo*(bufStatus: var BufferStatus, windowNode: WindowNode) =
  if not bufStatus.buffer.canUndo: return
  bufStatus.buffer.undo
  bufStatus.revertPosition(windowNode, bufStatus.buffer.lastSuitId)

  # if replace mode or insert mode
  if (bufStatus.mode == Mode.insert or bufStatus.mode == Mode.replace) and
     windowNode.currentColumn > bufStatus.buffer[windowNode.currentLine].len and
     windowNode.currentColumn > 0:
    (windowNode.currentLine, windowNode.currentColumn) =
      bufStatus.buffer.prev(windowNode.currentLine,
      windowNode.currentColumn + 1)
  # if Other than replace mode and insert mode
  elif (bufStatus.mode != Mode.insert and bufStatus.mode != Mode.replace) and
       windowNode.currentColumn == bufStatus.buffer[windowNode.currentLine].len and
       windowNode.currentColumn > 0:
    (windowNode.currentLine, windowNode.currentColumn) =
      bufStatus.buffer.prev(windowNode.currentLine,
      windowNode.currentColumn)

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

proc redo*(bufStatus: var BufferStatus, windowNode: WindowNode) =
  if not bufStatus.buffer.canRedo: return
  bufStatus.buffer.redo
  bufStatus.revertPosition(windowNode, bufStatus.buffer.lastSuitId)
  inc(bufStatus.countChange)
  bufStatus.isUpdate = true

# If cursor is inside of paren, delete inside paren in the current line
proc deleteInsideOfParen*(bufStatus: var BufferStatus,
                          windowNode: var WindowNode,
                          registers: var Registers,
                          registerName: string,
                          rune: Rune) =

  let
    currentLine = windowNode.currentLine
    currentColumn = windowNode.currentColumn
    oldLine = bufStatus.buffer[currentLine]
    openParen = if isCloseParen(rune): correspondingOpenParen(rune) else: rune
    closeParen = if isOpenParen(rune): correspondingCloseParen(rune) else: rune

  var
    openParenPosition = -1
    closeParenPosition = -1

  # Check open paren position
  for i in countdown(currentColumn, 0):
    if oldLine[i] == openParen:
      openParenPosition = i
      break

  # Check close paren position
  for i in openParenPosition + 1 ..< oldLine.len:
    if oldLine[i] == closeParen:
      closeParenPosition = i
      break

  if openParenPosition > 0 and closeParenPosition > 0:
    var
      newLine = bufStatus.buffer[currentLine]
      deleteBuffer = ru ""

    for i in 0 ..< closeParenPosition - openParenPosition - 1:
      deleteBuffer.add newLine[openParenPosition + 1]
      newLine.delete(openParenPosition + 1)

    if oldLine != newLine:
      if registerName.len > 0:
        registers.addRegister(deleteBuffer, registerName)
      else:
        const
          isLine = false
          isDelete = true
        registers.addRegister(deleteBuffer, isLine, isDelete)

      bufStatus.buffer[currentLine] = newLine
      windowNode.currentColumn = openParenPosition

# If cursor is inside of paren, delete inside paren in the current line
proc deleteInsideOfParen*(bufStatus: var BufferStatus,
                                 windowNode: var WindowNode,
                                 registers: var Registers,
                                 rune: Rune) =

  const registerName = ""
  bufStatus.deleteInsideOfParen(
    windowNode,
    registers,
    registerName,
    rune)

# Return the colmn and word
proc getWordUnderCursor(bufStatus: BufferStatus,
                        windowNode: WindowNode): (int, seq[Rune]) =

  let line = bufStatus.buffer[windowNode.currentLine]
  if line.len <= windowNode.currentColumn:
    return

  let atCursorRune = line[windowNode.currentColumn]
  if not atCursorRune.isAlpha and not (char(atCursorRune) in '0'..'9'):
    return

  var
    beginCol = -1
    endCol = -1
  for i in countdown(windowNode.currentColumn, 0):
    if not line[i].isAlpha and not (char(line[i]) in '0'..'9'):
      break
    beginCol = i
  for i in windowNode.currentColumn..line.len()-1:
    if not line[i].isAlpha and not (char(line[i]) in '0'..'9'):
      break
    endCol = i
  if endCol == -1 or beginCol == -1:
    (-1, seq[Rune].default)
  else:
    return (beginCol, line[beginCol..endCol])

proc getCharacterUnderCursor(bufStatus: BufferStatus,
                             windowNode: WindowNode): Rune =

  let line = bufStatus.buffer[windowNode.currentLine]
  if line.len() <= windowNode.currentColumn:
    return

  line[windowNode.currentColumn]

# Increment/Decrement the number string under the cursor
proc modifyNumberTextUnderCurosr*(bufStatus: var BufferStatus,
                                  windowNode: var WindowNode,
                                  amount: int) =

  let
    currentLine = windowNode.currentLine
    currentColumn = windowNode.currentColumn

  if not isDigit(bufStatus.buffer[currentLine][currentColumn]): return

  let
    wordUnderCursor = bufStatus.getWordUnderCursor(windowNode)
    beginCol = wordUnderCursor[0]
    word = wordUnderCursor[1]

  let
    num = parseInt(word)
    oldLine = bufStatus.buffer[currentLine]
  var newLine = bufStatus.buffer[currentLine]

  # Delete the current number string from newLine
  block:
    var col = currentColumn
    while newLine.len > 0 and isDigit(newLine[col]):
      newLine.delete(col, col)
      if col > newLine.high: col = newLine.high

  # Insert the new number string to newLine
  block:
    let newNumRunes= toRunes(num + amount)
    var col = currentColumn
    newLine.insert(newNumRunes, currentColumn)

  # Update bufStatus.buffer
  if newLine != oldLine:
    bufStatus.buffer[currentLine] = newLine

  inc(bufStatus.countChange)
  bufStatus.isUpdate = true
