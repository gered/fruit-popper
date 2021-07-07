{ Fixed-point math type definition, constants and functions.
  Gered King, 2019-2020 }

{$A+,B-,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit FixedP;

interface

const
  FP_INT_SHIFT               = 16;
  FP_FLOAT_SHIFT             = 65536.0;

  FP_DIV_ERROR               = $7fffffff;

  FP_1                       = trunc(1 * FP_FLOAT_SHIFT);
  FP_2                       = trunc(2 * FP_FLOAT_SHIFT);
  FP_3                       = trunc(3 * FP_FLOAT_SHIFT);
  FP_4                       = trunc(4 * FP_FLOAT_SHIFT);
  FP_5                       = trunc(5 * FP_FLOAT_SHIFT);
  FP_6                       = trunc(6 * FP_FLOAT_SHIFT);
  FP_7                       = trunc(7 * FP_FLOAT_SHIFT);
  FP_8                       = trunc(8 * FP_FLOAT_SHIFT);
  FP_9                       = trunc(9 * FP_FLOAT_SHIFT);
  FP_10                      = trunc(10 * FP_FLOAT_SHIFT);

  FP_16                      = trunc(16 * FP_FLOAT_SHIFT);
  FP_32                      = trunc(32 * FP_FLOAT_SHIFT);
  FP_64                      = trunc(64 * FP_FLOAT_SHIFT);
  FP_128                     = trunc(128 * FP_FLOAT_SHIFT);
  FP_256                     = trunc(256 * FP_FLOAT_SHIFT);

  FP_0_1                     = trunc(0.1 * FP_FLOAT_SHIFT);
  FP_0_2                     = trunc(0.2 * FP_FLOAT_SHIFT);
  FP_0_3                     = trunc(0.3 * FP_FLOAT_SHIFT);
  FP_0_4                     = trunc(0.4 * FP_FLOAT_SHIFT);
  FP_0_5                     = trunc(0.5 * FP_FLOAT_SHIFT);
  FP_0_6                     = trunc(0.6 * FP_FLOAT_SHIFT);
  FP_0_7                     = trunc(0.7 * FP_FLOAT_SHIFT);
  FP_0_8                     = trunc(0.8 * FP_FLOAT_SHIFT);
  FP_0_9                     = trunc(0.9 * FP_FLOAT_SHIFT);

  FP_0_25                    = trunc(0.25 * FP_FLOAT_SHIFT);
  FP_0_75                    = trunc(0.75 * FP_FLOAT_SHIFT);

  FP_1_OVER_3                = trunc((1 / 3) * FP_FLOAT_SHIFT);
  FP_2_OVER_3                = trunc((2 / 3) * FP_FLOAT_SHIFT);

type
  Fixed = LongInt;

{ turbo pascal's "inline" used here solely for functions that we want to be
  inlined for best performance. in c/c++, these would've been written
  as macros, but turbo pascal unfortunately lacks macro support. so we
  are using "inline" as a poor way to get a sort of function inlining... }

function IntToFix(x : integer) : fixed;
inline(
  $58/                            { pop  ax }
  $8B/$D0/                        { mov  dx, ax }
  $33/$C0                         { xor  ax, ax }
);
function FixToInt(x : fixed) : integer;
inline(
  $66/$58/                        { pop  eax }
  $66/$C1/$E8/FP_INT_SHIFT        { shr  eax, FP_INT_SHIFT }
);

function FloatToFix(x : single) : fixed;

function FixToFloat(x : fixed) : single;

function FixMul(a, b : fixed) : fixed;
inline(
  $66/$5B/                        { pop  ebx }
  $66/$58/                        { pop  eax }
  $66/$F7/$EB/                    { imul ebx }
  $66/$0F/$AC/$D0/FP_INT_SHIFT/   { shrd eax, edx, FP_INT_SHIFT }
  $66/$C1/$C0/FP_INT_SHIFT/       { rol  eax, FP_INT_SHIFT }
  $8B/$D0/                        { mov  dx, ax }
  $66/$C1/$C0/FP_INT_SHIFT        { rol  eax, FP_INT_SHIFT }
);

function FixDiv(a, b : fixed) : fixed;
inline(
  $66/$5B/                        { pop ebx }
  $66/$58/                        { pop eax }
  $66/$33/$C9/                    { xor ecx, ecx }
  $66/$0B/$C0/                    { or eax, eax }
  $79/$05/                        { jns checkDivisorSign }
  $66/$F7/$D8/                    { neg eax }
  $66/$41/                        { inc ecx }
  { checkDivisorSign: }
  $66/$0B/$DB/                    { or ebx, ebx }
  $79/$05/                        { jns divide }
  $66/$F7/$DB/                    { neg ebx }
  $66/$41/                        { inc ecx }
  { divide: }
  $66/$33/$D2/                    { xor edx, edx }
  $66/$0F/$A4/$C2/FP_INT_SHIFT/   { shld edx, eax, FP_INT_SHIFT }
  $66/$C1/$E0/FP_INT_SHIFT/       { shl eax, FP_INT_SHIFT }
  $66/$3B/$D3/                    { cmp edx, ebx }
  $73/$08/                        { jae error }
  $66/$F7/$F3/                    { div ebx }
  $66/$0B/$C0/                    { or eax, eax }
  $79/$08/                        { jns restoreSignBit }
  { error: }
  $66/$B8/$FF/$FF/$FF/$7F/        { mov eax, FP_DIV_ERROR }
  $EB/$09/                        { jmp done }
  { restoreSignBit: }
  $66/$83/$F9/$01/                { cmp ecx, 1 }
  $75/$03/                        { jne done }
  $66/$F7/$D8/                    { neg eax }
  { done: }
  $66/$C1/$C0/FP_INT_SHIFT/       { rol  eax, FP_INT_SHIFT }
  $8B/$D0/                        { mov  dx, ax }
  $66/$C1/$C0/FP_INT_SHIFT        { rol  eax, FP_INT_SHIFT }
);


function FixDivFast(a, b : fixed) : fixed;
inline(
  $66/$5B/                        { pop  ebx }
  $66/$58/                        { pop  eax }
  $66/$99/                        { cdq }
  $66/$0F/$A4/$C2/FP_INT_SHIFT/   { shld edx, eax, FP_INT_SHIFT }
  $66/$C1/$E0/FP_INT_SHIFT/       { shl  eax, FP_INT_SHIFT }
  $66/$F7/$FB/                    { idiv ebx }
  $66/$C1/$C0/FP_INT_SHIFT/       { rol  eax, FP_INT_SHIFT }
  $8B/$D0/                        { mov  dx, ax }
  $66/$C1/$C0/FP_INT_SHIFT        { rol  eax, FP_INT_SHIFT }
);

function FixSqr(x : fixed) : fixed;
inline(
  $66/$58/                        { pop  eax }
  $66/$F7/$E8/                    { imul eax }
  $66/$0F/$AC/$D0/FP_INT_SHIFT/   { shrd eax, edx, FP_INT_SHIFT }
  $66/$C1/$C0/FP_INT_SHIFT/       { rol  eax, FP_INT_SHIFT }
  $8B/$D0/                        { mov  dx, ax }
  $66/$C1/$C0/FP_INT_SHIFT        { rol  eax, FP_INT_SHIFT }
);

function FixSqrt(x : fixed) : fixed;

implementation

function FloatToFix(x : single) : fixed;
begin
  FloatToFix := trunc(x * FP_FLOAT_SHIFT);
end;

function FixToFloat(x : fixed) : single;
begin
  FixToFloat := x / FP_FLOAT_SHIFT;
end;

function FixSqrt(x : fixed) : fixed;
assembler;
asm
  db $66; mov bx, x.word          { mov ebx, x }
  db $66,$b9,$00,$00,$00,$40      { mov ecx, $40000000 }
  db $66; xor ax, ax              { xor eax, eax }

  @@1:
    db $66; mov dx, ax            { mov edx, eax }
    db $66; add dx, cx            { add edx, ecx }

    db $66; cmp bx, dx            { cmp ebx, edx }
    jl @@2
      db $66; sub bx, dx          { sub ebx, edx }
      db $66; mov ax, dx          { mov eax, edx }
      db $66; add ax, cx          { add eax, ecx }
    @@2:
    db $66; shl bx, 1             { shl ebx, 1 }
    db $66; shr cx, 1             { shr ecx, 1 }

  db $66; cmp cx, 40h             { cmp ecx, $40 }
  jg @@1

  db $66; shr ax, 8               { shr eax, 8 }

  db $66; rol ax, FP_INT_SHIFT    { rol eax, FP_INT_SHIFT }
  mov dx, ax
  db $66; rol ax, FP_INT_SHIFT    { rol eax, FP_INT_SHIFT }
end;

begin
  if Test8086 < 2 then begin
    writeln('The FIXEDP unit requires a 386 cpu or higher!');
    halt;
  end;
end.
