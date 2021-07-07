{ GDlib Higher Frequency Timer Utilities
  Gered King, 2021 }

{$A+,B-,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit GDTimer;

interface

const

  { count of the number of times the timer interrupt has been raised.
    this will be incremented 'freq' times per second once InitTimer
    has been called. }
  TimerTicks                 : longint = 0;

function InitTimer(freq: word) : boolean;
function CloseTimer : boolean;
function GetTimerFrequency : word;
function MarkTimer : longint;
procedure WaitForTime(delay : word);

implementation

uses Dos;

const
  PIC_CTRL_PORT              = $20;
  CHANNEL_0_PORT             = $40;
  COMMAND_PORT               = $43;

  TIMER_FREQ_SET_COMMAND     = $36; { mode 2 (rate generator),
                                      read/write lo-byte of counter,
                                      read/write hi-byte of counter }

  TIMER_CLOCK_RATE           = 1193180; { 1.19318 mhz }
  ORIGINAL_TIMER_FREQ        = 18.2065;

  _timerInstalled            : boolean = false;
  _timerFreq                 : word = 0;
  _lastMarkedAt              : longint = 0;

var
  _oldTimerCounter           : longint;
  _oldTimerTriggerAt         : longint;
  _oldTimerInterrupt         : pointer;

procedure SetTimerFrequency(freq: word);
{ configures the PC 8253 timer to trigger interrupt 8 at the given frequency.
  the value provided here should simply be just that: the number of times
  per second that interrupt 8 should be triggered per second. }
var
  counter0 : word;
begin
  if freq = 0 then
    counter0 := 0
  else
    counter0 := TIMER_CLOCK_RATE div freq;

  { calculate the number of timer interrupt ticks that will need to elapse
    (at our new timer frequency) before our custom interrupt should call the
    original timer interrupt handler to ensure it is still called at the
    original 18.2hz frequency }
  _oldTimerTriggerAt := round(freq / ORIGINAL_TIMER_FREQ);

  port[COMMAND_PORT] := TIMER_FREQ_SET_COMMAND;
  port[CHANNEL_0_PORT] := Lo(counter0);
  port[CHANNEL_0_PORT] := Hi(counter0);

  _timerFreq := freq;
end;

procedure TimerHandler;
{ custom timer (interrupt 8) handler.
  this has been written as a 'raw' assembler procedure instead of using
  a more typical pascal 'interrupt' procedure just to keep this as lean
  as possible since it will potentially be called hundreds (or more)
  times per second }
far;
assembler;
asm
  push ds
  db $66; push ax

  mov ax, seg @Data { restore DS so that we can access pascal vars }
  mov ds, ax

  db $66; inc word ptr [TimerTicks]

  { house-keeping to ensure the original interrupt 8 handler is still
    called at the rate it should be (18.2hz) }

  db $66; inc word ptr [_oldTimerCounter]

  { if _oldTimerCounter < _oldTimerTriggerAt, then skip calling the
    original interrupt 8 handler }
  db $66; mov ax, word(_oldTimerCounter)
  db $66; cmp ax, word(_oldTimerTriggerAt)
  jl @done

  { otherwise (if _oldTimerCounter >= _oldTimerTriggerAt), then,
    reset the counter back to zero and call the original interrupt 8
    handler }
  db $66; xor ax, ax
  db $66; mov word(_oldTimerCounter), ax
  pushf
  call [_oldTimerInterrupt]

@done:
  { tell the PIC that we're done }
  mov al, $20
  out PIC_CTRL_PORT, al

  db $66; pop ax
  pop ds
  iret
end;

function InitTimer(freq: word) : boolean;
{ installs a custom timer interrupt handler (interrupt 8). returns false if
  the timer interrupt handler could not be installed for some reason, or if
  the custom handler was already installed. }
begin
  InitTimer := false;
  if _timerInstalled then exit;

  TimerTicks       := 0;
  _oldTimerCounter := 0;
  _lastMarkedAt    := 0;

  asm cli end;
  SetTimerFrequency(freq);
  GetIntVec(8, _oldTimerInterrupt);
  SetIntVec(8, @TimerHandler);
  asm sti end;

  _timerInstalled := true;
  InitTimer := true;
end;

function CloseTimer : boolean;
{ removes a previously installed custom timer interrupt handler. }
begin
  CloseTimer := false;
  if not _timerInstalled then exit;

  asm cli end;
  SetTimerFrequency(0);  { resets back to the normal 18.2hz }
  SetIntVec(8, _oldTimerInterrupt);
  asm sti end;

  TimerTicks         := 0;
  _oldTimerCounter   := 0;
  _oldTimerInterrupt := nil;

  _timerInstalled := false;
  CloseTimer := true;
end;

function GetTimerFrequency : word;
{ returns the frequency that the installed custom timer interrupt handler
  is being triggered at. if no custom timer interrupt handler is installed,
  returns 0 }
begin
  GetTimerFrequency := _timerFreq;
end;

function MarkTimer : longint;
{ used to calculate time differences between subsequent calls to this
  function. the very first time it is called, the return value should
  probably be ignored (will be the ticks since the timer subsystem was
  initialized). }
var
  newMarkedAt : longint;
begin
  newMarkedAt := TimerTicks;
  MarkTimer := newMarkedAt - _lastMarkedAt;
  _lastMarkedAt := newMarkedAt;
end;

procedure WaitForTime(delay : word);
{ waits indefinitely for specified number of ticks to elapse }
var
  startedAt : longint;
begin
  if not _timerInstalled then exit;

  startedAt := TimerTicks;
  while (TimerTicks - startedAt) < delay do begin
  end;
end;

begin
  if Test8086 < 2 then begin
    writeln('The GDTIMER unit requires a 386 cpu or higher!');
    halt;
  end;
end.
