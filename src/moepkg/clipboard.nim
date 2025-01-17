import unicode, os, osproc
import independentutils, platform, settings

proc runesToStrings(runes: seq[seq[Rune]]): string =
  if runes.len == 1:
    result = $runes[0]
  else:
    for i in 0 ..< runes.len:
      if i == 0:
        result = $runes[0]
      else:
        result &= "\n" & $runes[i]

proc sendToClipboard*(buffer: seq[seq[Rune]],
                      tool: ClipboardToolOnLinux) =

  if buffer.len < 1: return

  let
    str = runesToStrings(buffer)
    delimiterStr = genDelimiterStr(str)

  case CURRENT_PLATFORM:
    of linux:
      ## Check if X server is running
      let (_, exitCode) = execCmdEx("xset q")
      if exitCode == 0:
        let cmd = if tool == ClipboardToolOnLinux.xclip:
                    "xclip -r <<" & "'" & delimiterStr & "'" & "\n" & str & "\n" & delimiterStr & "\n"
                  else:
                    "xsel <<" & "'" & delimiterStr & "'" & "\n" & str & "\n" & delimiterStr & "\n"
        discard execShellCmd(cmd)
    of wsl:
      let cmd = "clip.exe <<" & "'" & delimiterStr & "'" & "\n" & str & "\n"  & delimiterStr & "\n"
      discard execShellCmd(cmd)
    of mac:
      let cmd = "pbcopy <<" & "'" & delimiterStr & "'" & "\n" & str & "\n"  & delimiterStr & "\n"
      discard execShellCmd(cmd)
    else:
      discard
