{ GDlib Keyboard Handler
  Gered King, 2018 }

{$A+,B-,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit GDKeybrd;

interface

const
  KEY_ESC                    = $01;
  KEY_1                      = $02;
  KEY_2                      = $03;
  KEY_3                      = $04;
  KEY_4                      = $05;
  KEY_5                      = $06;
  KEY_6                      = $07;
  KEY_7                      = $08;
  KEY_8                      = $09;
  KEY_9                      = $0a;
  KEY_0                      = $0b;
  KEY_MINUS                  = $0c;
  KEY_EQUALS                 = $0d;
  KEY_BACKSPACE              = $0e;
  KEY_TAB                    = $0f;
  KEY_Q                      = $10;
  KEY_W                      = $11;
  KEY_E                      = $12;
  KEY_R                      = $13;
  KEY_T                      = $14;
  KEY_Y                      = $15;
  KEY_U                      = $16;
  KEY_I                      = $17;
  KEY_O                      = $18;
  KEY_P                      = $19;
  KEY_LEFT_BRACKET           = $1a;
  KEY_RIGHT_BRACKET          = $1b;
  KEY_ENTER                  = $1c;
  KEY_CTRL                   = $1d;
  KEY_A                      = $1e;
  KEY_S                      = $1f;
  KEY_D                      = $20;
  KEY_F                      = $21;
  KEY_G                      = $22;
  KEY_H                      = $23;
  KEY_J                      = $24;
  KEY_K                      = $25;
  KEY_L                      = $26;
  KEY_SEMICOLON              = $27;
  KEY_APOSTROPHE             = $28;
  KEY_TILDE                  = $29;
  KEY_LEFT_SHIFT             = $2a;
  KEY_BACKSLASH              = $2b;
  KEY_Z                      = $2c;
  KEY_X                      = $2d;
  KEY_C                      = $2e;
  KEY_V                      = $2f;
  KEY_B                      = $30;
  KEY_N                      = $31;
  KEY_M                      = $32;
  KEY_COMMA                  = $33;
  KEY_PERIOD                 = $34;
  KEY_FORWARDSLASH           = $35;
  KEY_RIGHT_SHIFT            = $36;
  KEY_ASTERISK               = $37;
  KEY_ALT                    = $38;
  KEY_SPACE                  = $39;
  KEY_CAPS_LOCK              = $3a;
  KEY_F1                     = $3b;
  KEY_F2                     = $3c;
  KEY_F3                     = $3d;
  KEY_F4                     = $3e;
  KEY_F5                     = $3f;
  KEY_F6                     = $40;
  KEY_F7                     = $41;
  KEY_F8                     = $42;
  KEY_F9                     = $43;
  KEY_F10                    = $44;
  KEY_NUM_LOCK               = $45;
  KEY_SCROLL_LOCK            = $46;
  KEY_HOME                   = $47;
  KEY_UP                     = $48;
  KEY_PAGE_UP                = $49;
  KEY_NUM_MINUS              = $4a;
  KEY_LEFT                   = $4b;
  KEY_NUM_5                  = $4c;
  KEY_RIGHT                  = $4d;
  KEY_NUM_PLUS               = $4e;
  KEY_END                    = $4f;
  KEY_DOWN                   = $50;
  KEY_PAGE_DOWN              = $51;
  KEY_INSERT                 = $52;
  KEY_DELETE                 = $53;
  KEY_F11                    = $57;
  KEY_F12                    = $58;

  KB_FLAGS_SCROLL_LOCK       = $10;
  KB_FLAGS_NUM_LOCK          = $20;
  KB_FLAGS_CAPS_LOCK         = $40;

  KB_MOD_EXTENDED            = $01;
  KB_MOD_SHIFT               = $02;
  KB_MOD_NUM_LOCK            = $04;
  KB_MOD_CAPS_LOCK           = $08;

type
  Key                        = byte;

var
  Keys                       : array[0..127] of bytebool;
  KeybrdFlags                : word absolute $0040:$0017;
  KeyFlags                   : word;
  KeyMod                     : word;

function InitKeyboard : boolean;
function CloseKeyboard : boolean;
function IsKeyboardInitialized : boolean;
function WaitForAnyKey : Key;
procedure WaitForNoKeys;
procedure WaitForKey(k: Key);
procedure WaitUntilKeyNotPressed(k: Key);

implementation

uses Dos, GDEvents, Toolbox;

const
  PIC_CTRL_PORT              = $20;
  KBRD_DATA_PORT             = $60;
  KBRD_CTRL_PORT             = $61;
  KBRD_STATUS_PORT           = $64;
  KBRD_CMD_SET_LED           = $ed;
  KBRD_LED_SCROLL_LOCK       = $01;
  KBRD_LED_NUM_LOCK          = $02;
  KBRD_LED_CAPS_LOCK         = $04;
  KEY_EXTENDED               = $e0;

  _KeyboardInstalled         : boolean = false;

var
  _keyLastScan               : Key;
  _keyScan                   : Key;
  _oldKeybrdInterrupt        : pointer;
  _keyboardEvent             : PInputEvent;

procedure ResetKeyState;
begin
  _keyLastScan := 0;
  _keyScan := 0;
  KeyFlags := 0;
  KeyMod := 0;
  MemFill(@Keys, 0, 128);
end;

procedure WaitKeybrdDataRead;
{ waits until the keyboard status port indicates the data port can be
  read from once again }
begin
  while (port[KBRD_STATUS_PORT] and 1) = 0 do begin
  end;
end;

procedure WaitKeybrdDataWrite;
{ waits until the keyboard status port indicates the data port can be
  written to once again }
begin
  while (port[KBRD_STATUS_PORT] and 2) <> 0 do begin
  end;
end;

function SendKeybrdData(data: byte) : boolean;
{ sends data to the keyboard data port. checks for success and returns
  true if the data write succeeded }
var
  result: byte;
begin
  WaitKeybrdDataWrite;
  port[KBRD_DATA_PORT] := data;

  WaitKeybrdDataRead;
  result := port[KBRD_DATA_PORT];

  SendKeybrdData := (result = $fa);
end;

function UpdateKeybrdLED(flags: byte) : boolean;
{ updates the keyboard indicator LEDs from the num/caps/scroll lock flags
  provided. returns false if the LEDs could not be updated (if the writes
  to the keyboard data port fail for any reason). }
var
  data: byte;
begin
  UpdateKeybrdLED := false;

  if not SendKeybrdData(KBRD_CMD_SET_LED) then
    exit;

  data := (flags shr 4) and 7;   { restrict to only the 3 led flags }
  if not SendKeybrdData(data) then
    exit;

  UpdateKeybrdLED := true;
end;

procedure PushKeyboardEvent(key: Key; action: EventAction);
begin
  if not IsEventsInitialized then
    exit;

  _keyboardEvent := PushEvent;

  with _keyboardEvent^ do begin
    Event := EVENT_TYPE_KEYBOARD;
    KB_Key := key;
    KB_Action := action;
    KB_Modifier := KeyMod;
  end;
end;

function HandlerFilterKeys : boolean;
{ returns true if the key interrupt event should not be handled (at least
  as far as updating key state is concerned) }
begin
  HandlerFilterKeys := false;

  if (KeyMod and KB_MOD_EXTENDED) <> 0 then begin
    { extended key + leftshift comes with cursor key presses when
      numlock is enabled ... }
    if (_keyScan and $7f) = KEY_LEFT_SHIFT then
      HandlerFilterKeys := true;
  end;
end;

procedure HandlerUpdateFlagsAndLEDs;
{ maintains BIOS keyboard flags/led toggle states (caps/num/scroll lock) }
begin
  case _keyScan of
    KEY_CAPS_LOCK: begin
        KeyFlags := KeyFlags xor KB_FLAGS_CAPS_LOCK;
        UpdateKeybrdLED(KeyFlags);
        KeybrdFlags := KeyFlags;
      end;
    KEY_NUM_LOCK: begin
        KeyFlags := KeyFlags xor KB_FLAGS_NUM_LOCK;
        UpdateKeybrdLED(KeyFlags);
        KeybrdFlags := KeyFlags;
      end;
    KEY_SCROLL_LOCK: begin
        KeyFlags := KeyFlags xor KB_FLAGS_SCROLL_LOCK;
        UpdateKeybrdLED(KeyFlags);
        KeybrdFlags := KeyFlags;
      end;
  end;
end;

procedure HandlerUpdateModifiers;
begin
  if (KeyFlags and KB_FLAGS_NUM_LOCK) <> 0 then
    KeyMod := KeyMod or KB_MOD_NUM_LOCK
  else
    KeyMod := KeyMod and not KB_MOD_NUM_LOCK;

  if (KeyFlags and KB_FLAGS_CAPS_LOCK) <> 0 then
    KeyMod := KeyMod or KB_MOD_CAPS_LOCK
  else
    KeyMod := KeyMod and not KB_MOD_CAPS_LOCK;

  if Keys[KEY_LEFT_SHIFT] or Keys[KEY_RIGHT_SHIFT] then
    KeyMod := KeyMod or KB_MOD_SHIFT
  else
    KeyMod := KeyMod and not KB_MOD_SHIFT;
end;

procedure KeybrdHandler;
{ custom keyboard interrupt handler. called on every keyboard event }
interrupt;
begin
  { read scan code of key that was just pressed (or released) }
  _keyScan := port[KBRD_DATA_PORT];

  { handle updating key state and flags/modifiers }
  if _keyScan = KEY_EXTENDED then begin
    KeyMod := KeyMod or KB_MOD_EXTENDED;

  end else begin
    if not HandlerFilterKeys then begin
      if (_keyScan and $80) <> 0 then begin
        { high bit set indicates key was released. clear high bit to get
          the actual key scan code }
        _keyScan := _keyScan and $7f;
        Keys[_keyScan] := false;
        HandlerUpdateModifiers;
        PushKeyboardEvent(_keyScan, EVENT_ACTION_RELEASED);

      end else begin
        if Keys[_keyScan] then begin
          PushKeyboardEvent(_keyScan, EVENT_ACTION_HELD);

        end else begin
          Keys[_keyScan] := true;
          { toggling of states only needs to be done for a key down event }
          HandlerUpdateFlagsAndLEDs;
          HandlerUpdateModifiers;

          PushKeyboardEvent(_keyScan, EVENT_ACTION_PRESSED);
        end;

      end;

      _keyLastScan := _keyScan;
    end;

    { clear extended modifier for the following event(s) in any case }
    KeyMod := KeyMod and not KB_MOD_EXTENDED;

  end;

  { indicate key event was processed to the keyboard controller }
  _keyScan := (port[KBRD_CTRL_PORT] or $80);
  port[KBRD_CTRL_PORT] := _keyScan;
  port[KBRD_CTRL_PORT] := (_keyScan and $7f);
  port[PIC_CTRL_PORT] := $20;
end;

function InitKeyboard : boolean;
{ installs a custom keyboard interrupt handler. returns false if the
  keyboard interrupt handler could not be installed for some reason, or if
  the custom handler was already installed. }
begin
  if _keyboardInstalled then begin
    InitKeyboard := false;
    exit;
  end;

  ResetKeyState;

  KeyFlags := KeybrdFlags;
  { bad hacky way to maybe-sortof-possibly not get into weird states
    depending on what keys are held down as this executes.
    a proper fix would involve updating our key handler to handle ALL
    of the bios key flag bits. }
  KeyFlags := KeyFlags and not $f38f;
  HandlerUpdateModifiers;
  GetIntVec(9, _oldKeybrdInterrupt);
  SetIntVec(9, @KeybrdHandler);
  KeybrdFlags := KeyFlags;

  _keyboardInstalled := true;
  InitKeyboard := true;
end;

function CloseKeyboard : boolean;
{ removes a previously installed custom keyboard interrupt handler. }
begin
  if not _keyboardInstalled then begin
    CloseKeyboard := true;
    exit;
  end;

  SetIntVec(9, _oldKeybrdInterrupt);
  ResetKeyState;

  _keyboardInstalled := false;
  CloseKeyboard := true;
end;

function IsKeyboardInitialized : boolean;
{ returns true if our custom keyboard handler has been initialized }
begin
  IsKeyboardInitialized := _keyboardInstalled;
end;

function WaitForAnyKey : Key;
{ waits indefinitely until any key is pressed, and returns the key scan code
  of the key that was pressed. }
begin
  _keyLastScan := 0;
  while _keyLastScan = 0 do begin
  end;
  WaitForAnyKey := _keyLastScan;
end;

procedure WaitForNoKeys;
{ waits indefinitely until there are no keys pressed. }
var
  i            : word;
  foundPressed : boolean;
begin
  repeat
    foundPressed := false;
    for i := 0 to 127 do begin
      if Keys[i] then begin
        foundPressed := true;
        break;
      end;
    end;
  until (not foundPressed);
end;

procedure WaitForKey(k: Key);
{ waits indefinitely until the specified key is pressed }
begin
  _keyLastScan := 0;
  while _keyLastScan <> k do begin
  end;
end;

procedure WaitUntilKeyNotPressed(k: Key);
{ waits indefinitely until the specified key is not pressed }
begin
  while Keys[k] do begin
  end;
end;

begin
  MemFill(@Keys, 0, SizeOf(Keys));
end.
