{$A+,B-,E+,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit Match;

interface

function StartMatch : boolean;
procedure MainLoop;

implementation

uses GDGfx, GDKeybrd, GDTimer, GDEvents, FixedP, Math, MathFP, Toolbox,
     Assets, Entities, Maps, Draw, Shared;

var
  menuSelection : integer;

function StartMatch : boolean;
var
  i : integer;
begin
  StartMatch := false;

  if (not LoadMap(selectedMap)) then exit;
  InitDirtTiles;

  UseLayer(BACKBUFFER_LAYER);
  Cls(0);

  with map.header do begin
    matchTime := time;
    matchTime := matchTime * 1000;  { time is a word, matchTime is longint }

    InitPlayer(player1, player1x*16, player1y*16, player1Selection);
    InitPlayer(player2, player2x*16, player2y*16, player2Selection);

    for i := 1 to initialFruit do
      SpawnRandomFruit;

  end;

  StartMatch := true;
end;

procedure DrawPauseMenu;
var
  c    : color;
  x, y : integer;
begin
  BlitSpritef(111, 10, titlePause);

  DrawUIFrame(76, 90, 168, 56, uiGeneralFrame);
  UseFont(@fnt);

  x := 92; y := 100;
  if menuSelection = 0 then begin
    c := 14;
    BlitSpritef(x, y, sprites[18]);
  end else
    c := 15;
  DrawString(x+16+8, y+4, c, 'Resume Game');

  x := 92; y := 120;
  if menuSelection = 1 then begin
    c := 14;
    BlitSpritef(x, y, sprites[18]);
  end else
    c := 15;
  DrawString(x+16+8, y+4, c, 'Back to Main Menu');

  WaitForVsync;
  Flip(BACKBUFFER_LAYER);
end;

function DoPauseMenu : boolean;
var
  quit  : boolean;
  event : PInputEvent;
begin
  UseLayer(BACKBUFFER_LAYER);

  menuSelection := 0;

  DrawPauseMenu;
  InitEvents;

  quit := false;
  while not quit do begin
    while not IsEventsEmpty do begin
      event := PollEvents;

      if IsKeyReleasedEvent(event, KEY_ESC) then begin
        menuSelection := 0;
        quit := true;
      end;

      if IsKeyReleasedEvent(event, KEY_DOWN) then begin
        inc(menuSelection);
        if menuSelection > 1 then menuSelection := 0;
      end;

      if IsKeyReleasedEvent(event, KEY_UP) then begin
        dec(menuSelection);
        if menuSelection < 0 then menuSelection := 1;
      end;

      if IsKeyReleasedEvent(event, KEY_ENTER) then quit := true;
    end;

    DrawPauseMenu;
  end;

  CloseEvents;

  { return true if the menu selection was 'quit' }
  DoPauseMenu := (menuSelection = 1);
end;

procedure MainLoop;
var
  frames, fps : word;
  elapsed     : longint;
  quit        : boolean;
  aborted     : boolean;
begin
  frames     := 0;
  fps        := 0;
  elapsed    := 0;

  quit    := false;
  aborted := false;
  isMapDirty := true;
  isStatusBackdropDirty := true;
  fruitSpawnTimer := 0;

  UseLayer(BACKBUFFER_LAYER);

  DrawBackdrop;
  DrawAllFruit;
  DrawPlayer(player1);
  DrawPlayer(player2);
  DrawAllParticles;
  DrawPlayerStatuses;
  DrawMatchStatus;

  Flip(BACKBUFFER_LAYER);

  FadeIn;

  MarkTimer;
  while not quit do begin

    if Keys[KEY_ESC] then begin
      WaitUntilKeyNotPressed(KEY_ESC);
      quit := DoPauseMenu;
      if quit then aborted := true;

      { reset timer mark, so if the pause menu is open for a long time,
        our timing / elapsed time tracking doesn't time travel forward }
      MarkTimer;
    end;

    frameTicks := MarkTimer;

    inc(elapsed, frameTicks);
    inc(fruitSpawnTimer, frameTicks);

    dec(matchTime, frameTicks);
    if matchTime < 0 then matchTime := 0;

    { player 1 }
    if Keys[KEY_LEFT] then MovePlayer(player1, West);
    if Keys[KEY_RIGHT] then MovePlayer(player1, East);
    if Keys[KEY_UP] then MovePlayer(player1, North);
    if Keys[KEY_DOWN] then MovePlayer(player1, South);
    if Keys[KEY_SPACE] then StabPlayer(player1);

    { player 2 }
    if Keys[KEY_A] then MovePlayer(player2, West);
    if Keys[KEY_D] then MovePlayer(player2, East);
    if Keys[KEY_W] then MovePlayer(player2, North);
    if Keys[KEY_S] then MovePlayer(player2, South);
    if Keys[KEY_T] then StabPlayer(player2);

    { update state }
    UpdatePlayer(player1);
    UpdatePlayer(player2);
    UpdateAllFruit;
    UpdateAllParticles;


    { render }
    DrawBackdrop;
    DrawAllFruit;
    DrawPlayer(player1);
    DrawPlayer(player2);
    DrawAllParticles;
    DrawPlayerStatuses;
    DrawMatchStatus;


    { update fps stats }
    inc(frames);

    { once per second, update the FPS value }
    if elapsed >= TIMER_FREQ then begin
      fps := frames;
      frames := 0;
      elapsed := 0;
    end;

    {
    UseFont(@fnt);
    PrintAt(0, 0); PrintInt(fps, 15);
    PrintString(' ', 15); PrintInt(frameTicks, 15);
    }

    { wait for vsync only if our frames are running at or beyond our
      target framerate ... }
    if frameTicks <= TARGET_FRAME_TICKS then
      WaitForVsync;

    Flip(BACKBUFFER_LAYER);

    { forcefully end the match once the timer is done ... }
    if matchTime <= 0 then quit := true;
  end;

  FadeOut;

  if aborted then
    currentGameState := StateMainMenu
  else
    currentGameState := StateResults;
end;

end.
