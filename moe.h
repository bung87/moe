#ifndef  MOE_MOE__H
#define MOE_MOE_H

#include<stdio.h>
#include<string.h>
#include<stdlib.h>
#include<stdbool.h>
#include<malloc.h>
#include<signal.h>
#include<ncurses.h>
#include"gapbuffer.h"
//#include<locale.h>

#define KEY_ESC 27
#define COLOR_DEFAULT -1
#define BRIGHT_WHITE 231
#define BRIGHT_GREEN 85 
#define GRAY 245
#define ON 1
#define OFF 0
#define NORMAL_MODE 0
#define INSERT_MODE 1
#define MAIN_WIN 0
#define STATE_WIN 1
#define CMD_WIN 2


typedef struct registers{
  gapBuffer *yankedLine;
  charArray *yankedStr;
  int numOfYankedLines,
      numOfYankedStr;
} registers;

typedef struct editorSetting{
  int autoCloseParen,
      autoIndent,
      tabStop;
} editorSetting;

typedef struct editorView{
  int height, width;
  charArray** lines;
  int* originalLine, *start, *length;
  bool isUpdated;
} editorView;

typedef struct cursorPosition{
  int y,x;
  bool isUpdated;
} cursorPosition;

typedef struct editorStat{
  editorSetting setting;
  registers rgst;
  editorView view;
  cursorPosition cursor;
  char filename[256];
  int   y, // obsolete
        x, // obsolete
        currentLine,
        positionInCurrentLine,
        numOfLines, // obsolete
        lineDigit,
        lineDigitSpace,
        mode,
        cmdLoop,
        numOfChange,
        isViewUpdated, // obsolete
        debugMode,
        adjustLineNum, // obsolete
        trueLineCapa, // obsolete
        *trueLine; // obsolete
} editorStat;

int debugMode(WINDOW **win, gapBuffer *gb, editorStat *stat);
void winInit(WINDOW **win);
void winResizeMove(WINDOW *win, int lines, int columns, int y, int x);
int setCursesColor();
void startCurses();
void signal_handler(int SIG);
void exitCurses();
void winResizeEvent(WINDOW **win, gapBuffer *gb, editorStat *stat);
void editorStatInit(editorStat* stat);
int returnLine(gapBuffer *gb, editorStat *stat); // obsolete
int trueLineInit(editorStat *stat); // obsolete
int registersInit(editorStat *stat);
void editorSettingInit(editorStat *stat);
int saveFile(WINDOW **win, gapBuffer* gb, editorStat *stat);
int shellMode(char *cmd);
int commandBar(WINDOW **win, gapBuffer *gb, editorStat *stat);
int insNewLine(gapBuffer *gb, editorStat *stat, int position);
int insertTab(gapBuffer *gb, editorStat *stat);
int keyBackSpace(gapBuffer* gb, editorStat* stat);
int insIndent(gapBuffer *gb, editorStat *stat);
int keyEnter(gapBuffer* gb, editorStat* stat);
int keyO(gapBuffer* gb, editorStat* stat);
int appendAfterTheCursor(gapBuffer *gb, editorStat *stat);
int appendEndOfLine(gapBuffer *gb, editorStat *stat);
int insBeginOfLine(gapBuffer *gb, editorStat *stat);
int keyX(gapBuffer* gb, editorStat* stat);
int keyD(WINDOW **win, gapBuffer* gb, editorStat* stat);
int charReplace(gapBuffer *gb, editorStat *stat, int key);
int moveFirstLine(WINDOW **win, gapBuffer* gb, editorStat* stat);
int moveLastLine(gapBuffer* gb, editorStat* stat);
int lineYank(WINDOW **win, gapBuffer *gb, editorStat *stat);
int linePaste(gapBuffer *gb, editorStat *stat);
int cmdE(gapBuffer *gb, editorStat *stat, char *filename);
void cmdNormal(WINDOW **win, gapBuffer *gb, editorStat *stat, int key);
void normalMode(WINDOW **win, gapBuffer* gb, editorStat* stat);
void insertMode(WINDOW **win, gapBuffer* gb, editorStat* stat);
int newFile(editorStat *stat);
int openFile(gapBuffer *gb, editorStat *stat);

#endif
