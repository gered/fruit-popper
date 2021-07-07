{$A+,B-,E+,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

program FruitPopper;

uses GDGfx, GDKeybrd, GDTimer, GDEvents, FixedP, Math, MathFP, Toolbox,
     Assets, Entities, Maps, Draw, Shared,
     MainMenu, LevelSel, FruitSel, Match, Results, Help;

procedure FatalExit(message : string);
begin
  CloseEvents;
  CloseTimer;
  CloseKeyboard;
  CloseGraphics;

  WriteLn('Fatal error. Exiting.');
  if length(message) > 0 then
    WriteLn('Cause: ', message);

  Halt(1);
end;

procedure LoadEverything;
var
  s : string[32];
begin
  UseLayer(SCREEN_LAYER);

  s := 'Loading 1/4 ...';
  Cls(0);
  DrawString(100, 96, 15, s);

  if LoadFont('dp.fnt', @fnt) <> FontOk then
    FatalExit('Failed loading font dp.fnt');

  s := 'Loading 2/4 ...';
  Cls(0);
  DrawString(100, 96, 15, s);

  if LoadFont('chunky.fnt', @chunkyFnt) <> FontOk then
    FatalExit('Failed loading font chunky.fnt');

  s := 'Loading 3/4 ...';
  Cls(0);
  DrawString(100, 96, 15, s);

  if (not LoadTilesAndSprites('tiles.lbm')) then
    FatalExit('Failed loading graphics tiles.lbm');

  s := 'Loading 4/4 ...';
  Cls(0);
  DrawString(100, 96, 15, s);

  if (not LoadImages('images.lbm')) then
    FatalExit('Failed loading images images.lbm');

  FadeOut;

  Cls(0);
  SetPalette(@pal);
end;

procedure DoIntro;
begin
  UseLayer(SCREEN_LAYER);
  UseFont(@fnt);

  Cls(0);
  BlackOutPalette;
  WaitForTime(500);

  DrawString(50, 96, 15, '... a GDR 4x4x4 Challenge Entry ...');
  FadeIn;
  WaitForTime(2000);
  FadeOut;

  WaitForTime(500);

  Cls(0);
  DrawString(50, 96, 15, '... created despite much slacking ...');
  FadeIn;
  WaitForTime(2000);
  FadeOut;

  WaitForTime(500);
  Cls(0);
end;

begin
  Randomize;
  InitGraphics(2);
  InitKeyboard;
  InitTimer(TIMER_FREQ);
  InitTrigTablesFP;

  LoadEverything;
  DoIntro;

  currentGameState := StateMainMenu;

  while currentGameState <> StateQuit do begin
    case currentGameState of
      StateMainMenu: DoMainMenu;
      StateLevelSelect: DoLevelSelect;
      StateFruitSelect: DoFruitSelect;
      StateHelp: DoHelp;
      StateMatch: begin
          StartMatch;
          MainLoop;
        end;
      StateResults: DoResults;
    end;
  end;

  CloseEvents;
  CloseTimer;
  CloseKeyboard;
  CloseGraphics;
end.
