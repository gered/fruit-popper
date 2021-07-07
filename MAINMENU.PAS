{$A+,B-,E+,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit MainMenu;

interface

procedure DoMainMenu;

implementation

uses GDGfx, GDKeybrd, GDTimer, GDEvents, Assets, Draw, Shared;

var
  menuSelection : integer;

procedure DrawMainMenu;
var
  c    : color;
  x, y : integer;
begin
  Cls(0);

  BlitSpritef(24, 10, titleMain);

  DrawUIFrame(68, 110, 184, 72, uiGeneralFrame);
  UseFont(@fnt);

  { --- }

  x := 100; y := 120;
  if menuSelection = 0 then begin
    c := 14;
    BlitSpritef(x, y, sprites[18]);
  end else
    c := 15;
  DrawString(x+16+8, y+4, c, 'Play!');

  x := 100; y := 140;
  if menuSelection = 1 then begin
    c := 14;
    BlitSpritef(x, y, sprites[18]);
  end else
    c := 15;
  DrawString(x+16+8, y+4, c, 'Instructions');

  x := 100; y := 160;
  if menuSelection = 2 then begin
    c := 14;
    BlitSpritef(x, y, sprites[18]);
  end else
    c := 15;
  DrawString(x+16+8, y+4, c, 'Quit');

  { --- }

  UseFont(@chunkyFnt);

  DrawString(94, 70, 22, 'GDR 4X4X4 CHALLENGE');
  x := 112;
  y := 80;
  BlitSpritef(x, y, sprites[0]);
  inc(x, 24);
  BlitSpritef(x, y, sprites[6]);
  inc(x, 24);
  BlitSpritef(x, y, sprites[1]);
  inc(x, 24);
  BlitSpritef(x, y, sprites[5]);
  DrawString(178, 193, 22, 'BY: GERED KING, 2021');

  WaitForVsync;
  Flip(BACKBUFFER_LAYER);
end;

procedure DoMainMenu;
var
  quit  : boolean;
  event : PInputEvent;
begin
  UseLayer(BACKBUFFER_LAYER);

  menuSelection := 0;

  DrawMainMenu;
  FadeIn;
  InitEvents;

  quit := false;
  while not quit do begin
    while not IsEventsEmpty do begin
      event := PollEvents;

      if IsKeyReleasedEvent(event, KEY_ESC) then begin
        menuSelection := 2;
        quit := true;
      end;

      if IsKeyReleasedEvent(event, KEY_DOWN) then begin
        inc(menuSelection);
        if menuSelection > 2 then menuSelection := 0;
      end;

      if IsKeyReleasedEvent(event, KEY_UP) then begin
        dec(menuSelection);
        if menuSelection < 0 then menuSelection := 2;
      end;

      if IsKeyReleasedEvent(event, KEY_ENTER) then quit := true;
    end;

    DrawMainMenu;
  end;

  CloseEvents;
  FadeOut;

  case menuSelection of
    0: currentGameState := StateLevelSelect;
    1: currentGameState := StateHelp;
    2: currentGameState := StateQuit;
  end;

end;

end.
