{$A+,B-,E+,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit Help;

interface

procedure DoHelp;

implementation

uses GDGfx, GDKeybrd, GDTimer, GDEvents, Assets, Draw, Shared;

var
  page : integer;

procedure DrawBaseHelpScreen;
begin
  Cls(0);

  BlitSpritef(62, 10, titleHelp);

  DrawUIFrame(16, 60, 288, 136, uiGeneralFrame);
  UseFont(@fnt);

end;

procedure ShowPage1;
begin
  DrawBaseHelpScreen;

  PrintAt(24, 68);
  UseFont(@chunkyFnt);
  PrintString('OBJECTIVE'#10, 14);

  UseFont(@fnt);
  PrintString('Using your thumbtack, pop more fruit than'#10'your opponent.'#10, 15);
  PrintString('Each player chooses their fruit preference'#10'and they will only gain points by popping'#10, 15);
  PrintString('matching fruit.'#10#10, 15);

  PrintString('                Tomatos'#10#10, TOMATO_TEXT_COLOR);
  PrintString('                Grapes'#10#10, GRAPES_TEXT_COLOR);
  BlitSpritef(176, 118, sprites[FRUIT_TOMATO_TILE_START]);
  BlitSpritef(176+24, 118, sprites[PLAYER_TOMATO_TILE_START]);
  BlitSpritef(176, 118+16, sprites[FRUIT_GRAPES_TILE_START]);
  BlitSpritef(176+24, 118+16, sprites[PLAYER_GRAPES_TILE_START]);

  PrintString('New fruit plants will appear randomly. Wait'#10'until they grow into fruit before stabbing!'#10#10, 15);
  PrintString('            Fruit Plant'#10#10, PLANT_TEXT_COLOR);
  BlitSpritef(176, 174, sprites[4]);

  WaitForVsync;
  Flip(BACKBUFFER_LAYER);
end;

procedure ShowPage2;
begin
  DrawBaseHelpScreen;

  PrintAt(24, 68);
  UseFont(@fnt);
  PrintString('You have until the time runs out to pop as'#10'much fruit as you can!'#10#10, 15);
  PrintString('If you are splashed by the opposite fruit'#10'being popped near you, you will lose speed'#10, 15);
  PrintString('temporarily! Be careful.'#10#10, 15);
  PrintString('Keep an eye out for golden fruit!'#10#10, 15);
  BlitSpritef(128, 140, sprites[FRUIT_TOMATO_TILE_START+2]);
  BlitSpritef(176, 140, sprites[FRUIT_GRAPES_TILE_START+2]);


  WaitForVsync;
  Flip(BACKBUFFER_LAYER);
end;

procedure ShowPage3;
begin
  DrawBaseHelpScreen;

  PrintAt(24, 68);
  UseFont(@chunkyFnt);
  PrintString('CONTROLS'#10#10, 14);

  UseFont(@fnt);
  PrintString('Player 1'#10, 128);
  PrintString('Arrow keys to move. Spacebar to stab.'#10#10, 15);
  PrintString('Player 2'#10, 128);
  PrintString('A/S/D/W keys to move. T to stab.'#10#10, 15);
  PrintString('Press ESC to pause and/or to exit out of'#10'an active match before the timer ends.', 15);

  WaitForVsync;
  Flip(BACKBUFFER_LAYER);
end;

procedure DoHelp;
var
  event : PInputEvent;
begin
  UseLayer(BACKBUFFER_LAYER);

  page := 0;

  ShowPage1;
  FadeIn;
  InitEvents;

  while (page < 3) do begin
    while not IsEventsEmpty do begin
      event := PollEvents;

      if IsKeyReleasedEvent(event, KEY_ENTER) then inc(page);
      if IsKeyReleasedEvent(event, KEY_SPACE) then inc(page);
      if IsKeyReleasedEvent(event, KEY_ESC) then inc(page);

      if IsKeyReleasedEvent(event, KEY_UP)
         or IsKeyReleasedEvent(event, KEY_LEFT) then begin
        dec(page);
        if page < 0 then page := 0;
      end;

      if IsKeyReleasedEvent(event, KEY_DOWN)
         or IsKeyReleasedEvent(event, KEY_RIGHT) then begin
        inc(page);
        if page >= 2 then page := 2;
      end;
    end;

    case page of
      0: ShowPage1;
      1: ShowPage2;
      2: ShowPage3;
    end;

  end;

  CloseEvents;
  FadeOut;
  currentGameState := StateMainMenu;

end;

end.
