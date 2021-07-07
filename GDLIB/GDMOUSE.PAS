{ GDlib Mouse Handler
  Gered King, 2018 }

{$A+,B-,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit GDMouse;

interface

type
  MouseButton                = byte;

  CursorBitmap               = array[0..63] of byte;
  PCursorBitmap              = ^CursorBitmap;

const
  MOUSE_LEFT_BUTTON          = $01;
  MOUSE_RIGHT_BUTTON         = $02;
  MOUSE_MIDDLE_BUTTON        = $04;

  CURSOR_WIDTH               = 16;
  CURSOR_HEIGHT              = 16;

  MouseX                     : integer = 0;
  MouseY                     : integer = 0;
  MouseButtons               : word = 0;
  MouseDeltaX                : integer = 0;
  MouseDeltaY                : integer = 0;

function InitMouse : boolean;
function CloseMouse : boolean;
function IsMouseInitialized : boolean;
function IsMousePresent : boolean;
procedure ShowMouse;
procedure HideMouse;
procedure SetMouseBounds(minX, minY, maxX, maxY: integer);
procedure SetMouseCursor(const bitmap: PCursorBitmap; hotspotX, hotspotY: integer);
procedure DrawMouseCursor;

implementation

uses GDGfx, GDClip, GDEvents, Toolbox;

const
  MOUSE_FILL_COLOR           = 15;
  MOUSE_OUTLINE_COLOR        = 0;

  _hasMouse                  : boolean = false;
  _mouseInstalled            : boolean = false;
  _mouseVisible              : boolean = false;

  _cursorHotspotX            : integer = 0;
  _cursorHotspotY            : integer = 0;

  { copy of the default microsoft mouse driver's cursor in graphics modes }
  _defaultCursorBitmap : CursorBitmap = (
    $ff,$3f,$ff,$1f,$ff,$0f,$ff,$07,
    $ff,$03,$ff,$01,$ff,$00,$7f,$00,
    $3f,$00,$1f,$00,$ff,$01,$ff,$00,
    $ff,$30,$7f,$f8,$7f,$f8,$ff,$fc,
    $00,$00,$00,$40,$00,$60,$00,$70,
    $00,$78,$00,$7c,$00,$7e,$00,$7f,
    $80,$7f,$00,$7c,$00,$6c,$00,$46,
    $00,$06,$00,$03,$00,$03,$00,$00
  );

var
  _currentCursorBitmap       : CursorBitmap;
  _mouseEvent                : PInputEvent;
  _mousePrevButtons          : word;

procedure ResetMouseState;
begin
  MouseX            := 0;
  MouseY            := 0;
  MouseButtons      := 0;
  _mousePrevButtons := 0;
  MouseDeltaX       := 0;
  MouseDeltaY       := 0;
end;

function InitMouseDriver : boolean;
begin
  asm
    mov ax, 0
    int 33h
    mov @Result, al          { ax = 0 if it failed }
  end;

  { reset our copy of the current mouse cursor bitmap at the same time }
  MemCopy(@_currentCursorBitmap, @_defaultCursorBitmap, SizeOf(CursorBitmap));
  _cursorHotspotX := 0;
  _cursorHotspotY := 0;
end;

procedure UpdateMouseState;
assembler;
asm
  mov ax, 3
  int 33h
  shr cx, 1
  mov MouseX, cx             { MouseX = cx / 2 }
  mov MouseY, dx
  mov ax, MouseButtons
  mov _mousePrevButtons, ax  { MousePrevButtons = MouseButtons }
  mov MouseButtons, bx
  mov MouseDeltaX, 0
  mov MouseDeltaY, 0
end;

procedure PushMotionEvent;
begin
  _mouseEvent := PushEvent;

  with _mouseEvent^ do begin
    Event      := EVENT_TYPE_MOUSE_MOTION;
    MM_X       := MouseX;
    MM_Y       := MouseY;
    MM_DeltaX  := MouseDeltaX;
    MM_DeltaY  := MouseDeltaY;
    MM_Buttons := MouseButtons;
  end;
end;

procedure PushButtonEvent(action: EventAction; button: MouseButton);
begin
  _mouseEvent := PushEvent;

  with _mouseEvent^ do begin
    Event     := EVENT_TYPE_MOUSE_BUTTON;
    MB_X      := MouseX;
    MB_Y      := MouseY;
    MB_Action := action;
    MB_Button := button;
  end;
end;

procedure ProcessMouseEvents;
begin
  if not IsEventsInitialized then
    exit;

  if (MouseDeltaX <> 0) or (MouseDeltaY <> 0) then
    PushMotionEvent;

    if MouseButtons <> _mousePrevButtons then begin
      if (MouseButtons and MOUSE_LEFT_BUTTON) <>
         (_mousePrevButtons and MOUSE_LEFT_BUTTON) then begin
        if (MouseButtons and MOUSE_LEFT_BUTTON) > 0 then
          PushButtonEvent(EVENT_ACTION_PRESSED, MOUSE_LEFT_BUTTON)
        else
          PushButtonEvent(EVENT_ACTION_RELEASED, MOUSE_LEFT_BUTTON);
    end;

    if (MouseButtons and MOUSE_RIGHT_BUTTON) <>
       (_mousePrevButtons and MOUSE_RIGHT_BUTTON) then begin
      if (MouseButtons and MOUSE_RIGHT_BUTTON) > 0 then
        PushButtonEvent(EVENT_ACTION_PRESSED, MOUSE_RIGHT_BUTTON)
      else
        PushButtonEvent(EVENT_ACTION_RELEASED, MOUSE_RIGHT_BUTTON);
    end;

    if (MouseButtons and MOUSE_MIDDLE_BUTTON) <>
       (_mousePrevButtons and MOUSE_MIDDLE_BUTTON) then begin
      if (MouseButtons and MOUSE_MIDDLE_BUTTON) > 0 then
        PushButtonEvent(EVENT_ACTION_PRESSED, MOUSE_MIDDLE_BUTTON)
      else
        PushButtonEvent(EVENT_ACTION_RELEASED, MOUSE_MIDDLE_BUTTON);
    end;
  end;
end;

procedure MouseHandler;
{ our custom mouse handler.
  this is written as an 'assembler' proc because the mouse driver passes it
  the mouse status via registers. using a pascal 'interrupt' proc would
  kind of work also, except that we would have to do a hacky return to ensure
  the registers are popped correctly and that a 'retf' is used for the
  return (instead of an 'iret' which is what pascal would otherwise do).
  doing this with an 'assembler' proc instead just seemed cleaner to me... }
far;
assembler;
asm
  { inputs provided by mouse driver:
    AX = event trigger bit
    BX = button state
    CX = X coordinate
    DX = Y coordinate
    DI = horizontal mickeys
    SI = vertical mickeys }

  pusha

  mov ax, seg @Data         { restore DS so that we can access pascal vars }
  mov ds, ax

  shr cx, 1                 { mouse x coordinate is doubled for some reason }

  mov ax, MouseButtons
  mov _mousePrevButtons, ax { MousePrevButtons := MouseButtons }
  mov MouseButtons, bx

  mov ax, cx
  sub ax, MouseX
  mov MouseDeltaX, ax       { MouseDeltaX := CX - MouseX }

  mov ax, dx
  sub ax, MouseY
  mov MouseDeltaY, ax       { MouseDeltaY := DX - MouseX }

  mov MouseX, cx
  mov MouseY, dx

  call ProcessMouseEvents

  popa
end;

function InitMouse : boolean;
{ initializes the mouse driver (if there is one present) and then installs
  our custom mouse event handler. returns true if the mouse was set up
  successfully or if there is no mouse device connected (check
  IsMousePresent() to be sure). returns false if an error occured setting
  up the mouse or if it was already initialized. }
begin
  if _mouseInstalled then begin
    InitMouse := false;
    exit;
  end;

  ResetMouseState;
  _hasMouse := InitMouseDriver;
  if not _hasMouse then begin
    _mouseInstalled := true;
    InitMouse       := true;
    exit;
  end;

  UpdateMouseState;

  asm
    mov ax, 0ch
    mov cx, 31
    mov dx, seg MouseHandler
    mov es, dx
    mov dx, offset MouseHandler
    int 33h
  end;

  _mouseVisible   := false;
  _mouseInstalled := true;
  InitMouse       := true;
end;

function CloseMouse : boolean;
{ removes a previously installed custom mouse event handler and resets the
  mouse driver to it's initial state. }
begin
  if not _mouseInstalled then begin
    CloseMouse := true;
    exit;
  end;

  if not _hasMouse then begin
    _mouseInstalled := false;
    CloseMouse      := true;
    exit;
  end;

  asm
    mov ax, 0ch
    mov cx, 0
    int 33h
  end;

  ResetMouseState;
  InitMouseDriver;

  _mouseVisible   := false;
  _mouseInstalled := false;
  CloseMouse      := true;
end;

function IsMouseInitialized : boolean;
{ returns true if the mouse driver was initialized successfully }
begin
  IsMouseInitialized := _mouseInstalled;
end;

function IsMousePresent : boolean;
{ returns true if a mouse device is currently connected to the computer }
begin
  IsMousePresent := _hasMouse;
end;

procedure ShowMouse;
{ shows the mouse cursor. if the mouse cursor is currently shown, this does
  nothing }
begin
  if not _hasMouse then
    exit;
  if _mouseVisible then
    exit;

  asm
    mov ax, 1
    int 33h
  end;
  _mouseVisible := true;
end;

procedure HideMouse;
{ hides the mouse cursor. if the mouse cursor is not currently shown, this
  does nothing }
begin
  if not _hasMouse then
    exit;
  if not _mouseVisible then
    exit;

  asm
    mov ax, 2
    int 33h;
  end;
  _mouseVisible := false;
end;

procedure SetMouseBounds(minX, minY, maxX, maxY: integer);
{ sets the pixel boundaries for the mouse cursor }
begin
  if not _hasMouse then
    exit;

  asm
    mov ax, 7
    mov cx, minX
    mov dx, maxX
    int 33h

    mov ax, 8
    mov cx, minY
    mov dx, maxY
    int 33h
  end;
end;

procedure SetMouseCursor(const bitmap: PCursorBitmap;
                         hotspotX, hotspotY: integer);
{ changes the mouse cursor to the specified bitmap. if the bitmap is nil,
  resets the cursor back to the original bitmap }
begin
  { make a copy of the bitmap, solely for DrawMouseCursor to use it.
    (there is no mouse driver function for reading the current cursor
    bitmap?) }
  if bitmap = nil then
    MemCopy(@_currentCursorBitmap, @_defaultCursorBitmap, SizeOf(CursorBitmap))
  else
    MemCopy(@_currentCursorBitmap, bitmap, SizeOf(CursorBitmap));

  _cursorHotspotX := hotspotX;
  _cursorHotspotY := hotspotY;

  asm
    mov ax, 9h
    mov bx, hotspotX
    mov cx, hotspotY
    mov dx, seg _currentCursorBitmap
    mov es, dx
    mov dx, offset _currentCursorBitmap
    int 33h
  end;
end;

procedure LLBlitMouseCursor(width, height, destYinc, leftClipBits: integer;
                            destOffs, srcSeg, srcOffs: word);
assembler;
asm
  push ds

  mov dx, height             { dx = line loop counter }
  test dx, dx                { stop now if there's zero lines to draw }
  jz @done

  call far ptr GetBoundLayerSegment
  mov es, ax
  mov di, destOffs
  mov ds, srcSeg
  mov si, srcOffs

@draw_line:
  mov ax, ds:[si]            { load next screen mask word }
  mov bx, ds:[si+32]         { load next shape mask word }
  mov cx, leftClipBits
  test cx, cx
  jz @done_bits_clipping     { trim off left bits (for clipping) if needed }
  shl ax, cl
  shl bx, cl
@done_bits_clipping:
  mov cx, width              { cx = number of pixels to draw }
                             { ax = screen mask word }
                             { bx = shape mask word }

@draw_pixel:
  shl ax, 1
  jc @skip_pixel             { screen mask bit is 1? skip this pixel }
  shl bx, 1
  jnc @draw_cursor_outline_px
@draw_cursor_color_px:       { draw inner color if shape bit is 1 }
  mov es:[di], byte(MOUSE_FILL_COLOR)
  jmp @end_pixel
@draw_cursor_outline_px:     { or, draw outline color if shape bit is 0 }
  mov es:[di], byte(MOUSE_OUTLINE_COLOR)
  jmp @end_pixel

@skip_pixel:
  shl bx, 1                  { skipping this pixel, need to also shift the }
                             { shape mask word to keep them both at the }
                             { same location }

@end_pixel:
  inc di                     { move to the next pixel }
  dec cx                     { decrease pixel drawing counter }
  jnz @draw_pixel

@end_line:
  add si, 2                  { move to next line }
  add di, destYinc
  dec dx                     { decrease line loop counter }
  jnz @draw_line

@done:
  pop ds
end;

procedure DrawMouseCursor;
{ draws the mouse cursor at it's current location. this draws it completely
  independently from the mouse driver. it should only be used after a call
  to HideMouse and when your application is redrawing the entire screen
  every frame. otherwise, the built-in mouse driver cursor rendering is
  probably the best choice. }
var
  x, y: integer;
  srcX, srcY, srcWidth, srcHeight: integer;
  srcOffs, destOffs: word;
  destYinc: integer;
begin
  if not _mouseInstalled then
    exit;

  { destination always at current mouse cursor position (adjusted by
    hotspot X/Y, which is how the normal mouse driver does it) }
  x := MouseX - _cursorHotspotX;
  y := MouseY - _cursorHotspotY;

  srcX      := 0;
  srcY      := 0;
  srcWidth  := CURSOR_WIDTH;
  srcHeight := CURSOR_HEIGHT;

  if not ClipBlitToScreen(srcX, srcY, srcWidth, srcHeight, x, y) then
    exit;

  srcOffs  := Ofs(_currentCursorBitmap[srcY * 2]);
  destOffs := GetBoundLayerOffsetAt(x, y);
  destYinc := SCREEN_WIDTH - srcWidth;

  LLBlitMouseCursor(srcWidth, srcHeight,
                    destYinc, srcX,
                    destOffs,
                    Seg(_currentCursorBitmap), srcOffs);
end;

end.
