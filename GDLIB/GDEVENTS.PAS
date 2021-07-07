{ GDlib Input device events
  Gered King, 2018 }

{$A+,B-,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit GDEvents;

interface

uses GDKeybrd, GDMouse;

const
  EVENT_TYPE_KEYBOARD        = 1;
  EVENT_TYPE_MOUSE_MOTION    = 2;
  EVENT_TYPE_MOUSE_BUTTON    = 3;
  EVENT_ACTION_PRESSED       = 1;
  EVENT_ACTION_RELEASED      = 2;
  EVENT_ACTION_HELD          = 3;

type
  EventType                  = byte;
  EventAction                = byte;

  InputEvent = record
    case Event: EventType of
      EVENT_TYPE_KEYBOARD: (
        KB_Key      : Key;
        KB_Action   : EventAction;
        KB_Modifier : word;
      );
      EVENT_TYPE_MOUSE_MOTION: (
        MM_X       : integer;
        MM_Y       : integer;
        MM_DeltaX  : integer;
        MM_DeltaY  : integer;
        MM_Buttons : MouseButton;
      );
      EVENT_TYPE_MOUSE_BUTTON: (
        MB_X       : integer;
        MB_Y       : integer;
        MB_Button  : MouseButton;
        MB_Action  : EventAction;
      );
  end;

  PInputEvent                = ^InputEvent;

function InitEvents : boolean;
function CloseEvents : boolean;
function IsEventsInitialized : boolean;
function IsEventsEmpty : boolean;
function PollEvents : PInputEvent;
function PeekEvents : PInputEvent;
procedure ClearEvents;

function PushEvent : PInputEvent;

function IsKeyPressedEvent(event : PInputEvent; k : Key) : boolean;
function IsKeyReleasedEvent(event : PInputEvent; k : Key) : boolean;
function IsKeyHeldEvent(event : PInputEvent; k : Key) : boolean;

implementation

uses Toolbox;

const
  EVENT_BUFFER_SIZE          = 16;

  _eventsInitialized         : boolean = false;
  _bufferStart               : integer = 0;
  _bufferEnd                 : integer = 0;

var
  _buffer                    : array[0..(EVENT_BUFFER_SIZE-1)] of InputEvent;

function InitEvents : boolean;
{ initializes the events system, returning true if successful }
begin
  if IsEventsInitialized then begin
    InitEvents := false;
    exit;
  end;

  ClearEvents;
  _eventsInitialized := true;
  InitEvents := true;
end;

function CloseEvents : boolean;
{ closes the events system, returning true if successful. }
begin
  if not IsEventsInitialized then begin
    CloseEvents := true;
    exit;
  end;

  _eventsInitialized := false;
  ClearEvents;
  CloseEvents := true;
end;

function IsEventsInitialized : boolean;
{ returns true if the events system has been initialized }
begin
  IsEventsInitialized := _eventsInitialized;
end;

function IsEventsEmpty : boolean;
{ returns true if there are no events to be processed currently }
begin
  IsEventsEmpty := (_bufferStart = _bufferEnd);
end;

function PollEvents : PInputEvent;
{ returns the next input event in the buffer, or nil if there was none.
  calling this function moves the input event buffer head to the next event }
begin
  if IsEventsEmpty then begin
    PollEvents := nil;
    exit;
  end;

  asm cli end;

  { return a pointer to the event at the buffer queue head currently }
  PollEvents := @_buffer[_bufferStart];

  { move the buffer queue head to the following event }
  inc(_bufferStart);
  if _bufferStart >= EVENT_BUFFER_SIZE then
    _bufferStart := 0;

  asm sti end;
end;

function PeekEvents : PInputEvent;
{ returns the next input event in the buffer, or nil if there was none.
  calling this function does not modify the input event buffer in any way
  (subsequent calls will return the same event, and/or PollEvents can be
  used immediately after to return the same event) }
begin
  if IsEventsEmpty then begin
    PeekEvents := nil;
    exit;
  end;

  { return a pointer to the event at the buffer queue head currently }
  PeekEvents := @_buffer[_bufferStart];
end;

procedure ClearEvents;
{ clears the event buffer of all events }
begin
  asm cli end;

  MemFill(@_buffer, 0, SizeOf(_buffer));
  _bufferStart := 0;
  _bufferEnd   := 0;

  asm sti end;
end;

function PushEvent : PInputEvent;
{ returns a pointer to the last event on the buffer queue. it is up to the
  caller to fill that event structure with the information about the event to
  be "pushed" onto the queue. the buffer end pointer is incremented each
  time this is called (so it won't return the same pointer for subsequent
  calls). this function was mainly intended to be used by GDlib keyboard and
  mouse handlers. }
begin
  { return pointer to the last event in the buffer queue (which ensures
    FIFO queue behaviour when adding new events) }
  PushEvent := @_buffer[_bufferEnd];

  { advance the end pointer }
  inc(_bufferEnd);
  if _bufferEnd >= EVENT_BUFFER_SIZE then
    _bufferEnd := 0;

  { is the events buffer full? (if the end meets up to the start, it is) }
  if _bufferEnd = _bufferStart then begin
    { move the start up. this ensures the start always points to the oldest
      event in the buffer }
    inc(_bufferStart);
    if _bufferStart >= EVENT_BUFFER_SIZE then
      _bufferStart := 0;
  end;
end;

function IsKeyPressedEvent(event : PInputEvent; k : Key) : boolean;
{ returns true if this event is a 'key pressed' event for the given key }
begin
  if event = nil then
    IsKeyPressedEvent := false
  else
    with event^ do begin
      IsKeyPressedEvent := (Event = EVENT_TYPE_KEYBOARD)
                           and (KB_Action = EVENT_ACTION_PRESSED)
                           and (KB_Key = k);
    end;
end;

function IsKeyReleasedEvent(event : PInputEvent; k : Key) : boolean;
{ returns true if this event is a 'key released' event for the given key }
begin
  if event = nil then
    IsKeyReleasedEvent := false
  else
    with event^ do begin
      IsKeyReleasedEvent := (Event = EVENT_TYPE_KEYBOARD)
                            and (KB_Action = EVENT_ACTION_RELEASED)
                            and (KB_Key = k);
    end;
end;

function IsKeyHeldEvent(event : PInputEvent; k : Key) : boolean;
{ returns true if this event is a 'key held' event for the given key }
begin
  if event = nil then
    IsKeyHeldEvent := false
  else
    with event^ do begin
      IsKeyHeldEvent := (Event = EVENT_TYPE_KEYBOARD)
                        and (KB_Action = EVENT_ACTION_HELD)
                        and (KB_Key = k);
    end;
end;

end.
