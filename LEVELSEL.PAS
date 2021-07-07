{$A+,B-,E+,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit LevelSel;

interface

procedure DoLevelSelect;

implementation

uses Dos, GDGfx, GDKeybrd, GDTimer, GDEvents,
     Assets, Maps, Draw, Shared, Toolbox;

const
  MAX_MAP_FILES = 127;  { because i am lazy right now }

type
  FoundMapFile = record
    filename : string[12];
    header   : MapHeader;
  end;

var
  mapFilesList  : array[0..MAX_MAP_FILES] of FoundMapFile;
  mapFilesCount : word;

  menuSelection : integer;

function ReadMapFileHeader(filename : string; var header : MapHeader) : boolean;
var
  f     : file;
  n     : integer;
  ident : array[0..2] of char;
label ioError;
begin
  ReadMapFileHeader := false;

  Assign(f, filename);

  Reset(f, 1);
  if IOResult <> 0 then begin
    Close(f);
    n := IOResult;  { clear i/o error flag }
    exit;
  end;

  { validate file type by checking for expected header }
  BlockRead(f, ident, SizeOf(ident));
  if (ident[0] <> 'M') or (ident[1] <> 'A') or (ident[2] <> 'P') then
    goto ioError;

  MemFill(@header, 0, SizeOf(header));
  BlockRead(f, header, SizeOf(header), n);
  if n <> SizeOf(header) then goto ioError;

  ReadMapFileHeader := true;

ioError:
  Close(f);
  n := IOResult;  { clear i/o error flag }
end;

procedure ScanForMapFiles;
var
  search : SearchRec;
  header : MapHeader;
  i      : integer;
begin
  i := 0;
  MemFill(@mapFilesList, 0, SizeOf(mapFilesList));

  FindFirst('*.map', AnyFile, search);
  while DosError = 0 do begin
    ReadMapFileHeader(search.Name, header);

    if search.Name <> 'TEST.MAP' then begin
      mapFilesList[i].filename := search.Name;
      mapFilesList[i].header := header;
      inc(i);
    end;
    FindNext(search);
  end;

  mapFilesCount := i;
end;

procedure DrawLevelSelect;
var
  i, x, y : integer;
  idx     : integer;
  uiFrame : ^UIFrameBitmaps;
begin
  Cls(0);

  BlitSpritef(80, 10, titleSelectLevel);

  UseFont(@fnt);
  x := 16;
  y := 70;
  for i := -1 to 1 do begin;
    idx := i + menuSelection;

    if i = 0 then
      uiFrame := @uiTomatoFrame
    else
      uiFrame := @uiGeneralFrame;

    if (idx < 0) or (idx >= mapFilesCount) then
      {DrawUIFrame(x, y, 288, 32, uiFrame^)}
    else begin
      with mapFilesList[idx] do begin
        DrawUIFrame(x, y, 288, 32, uiFrame^);
        DrawString(x+8, y+8, 15, filename);
        SetClipRegion(x+8, y+16, x+8+288-16, y+16+32-16);
        DrawString(x+8, y+16, 15, header.Name);
        ResetClipRegion;
      end;
    end;

    inc(y, 32);
  end;

  WaitForVsync;
  Flip(BACKBUFFER_LAYER);
end;

procedure DoLevelSelect;
var
  quit    : boolean;
  aborted : boolean;
  event   : PInputEvent;
begin
  UseLayer(BACKBUFFER_LAYER);

  menuSelection := 0;

  ScanForMapFiles;

  DrawLevelSelect;
  FadeIn;
  InitEvents;

  quit    := false;
  aborted := false;
  while not quit do begin
    while not IsEventsEmpty do begin
      event := PollEvents;

      if IsKeyReleasedEvent(event, KEY_ESC) then begin
        quit    := true;
        aborted := true;
      end;

      if IsKeyReleasedEvent(event, KEY_UP) then begin
        dec(menuSelection);
        if menuSelection < 0 then
          menuSelection := 0;
      end;

      if IsKeyReleasedEvent(event, KEY_DOWN) then begin
        inc(menuSelection);
        if menuSelection >= mapFilesCount then
          menuSelection := mapFilesCount-1;
      end;

      if IsKeyReleasedEvent(event, KEY_ENTER) then begin
        if mapFilesCount > 0 then
          selectedMap := mapFilesList[menuSelection].filename
        else
          selectedMap := '';
        quit := true;
      end;

    end;

    DrawLevelSelect;
  end;

  CloseEvents;
  FadeOut;

  if aborted then
    currentGameState := StateMainMenu
  else
    currentGameState := StateFruitSelect;

end;

end.
