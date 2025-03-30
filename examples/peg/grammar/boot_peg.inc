
Grammar      : 
    Spacing  ( ( Definition ) =>|| )+ EndOfFile
 
; 
Definition   : 
    Identifier  LEFTARROW  Expression
 
; 
Expression   : 
    Sequence  ( ( SLASH  Sequence ) =>|| )* 
; 
Sequence     : 
    ( ( Prefix  =>|| ( ( & ENTAILS ) =>|| )? ) =>|| )* 
; 
Prefix       : 
    Cardinality  =>|| | ( ( AND  =>|| | NOT ) =>|| )? Suffix
 
; 
Suffix       : 
    Primary  ( ( QUESTION  =>|| | STAR  =>|| | PLUS ) =>|| )? 
; 
Primary      : 
    Identifier  ENSURE ~( LEFTARROW
              ) | OPEN  Expression  CLOSE
              =>|| | Literal  =>|| | _Class  =>|| | DOT
; 
Identifier   : 
    IdentStart  ( IdentCont =>|| )* Spacing
 
; 
IdentStart   : 
    LEXICAL_STATE CLASS_0_STATE (<CLASS_0>) 
; 
IdentCont    : 
    IdentStart  =>|| | LEXICAL_STATE CLASS_1_STATE (<CLASS_1>) 
; 
Literal      : 
    "'" =>|| ( ( ENSURE ~( "'" ) Char ) =>|| )* "'" Spacing 
              =>|| | "\"" =>|| ( ( ENSURE ~( "\"" ) Char ) =>|| )* "\"" Spacing 
 
; 
_Class        : 
    "[" =>|| ( ( ENSURE ~( "]" ) Range  ) =>|| )* "]" Spacing
 
; 
Range        : 
    Char  "-" =>|| Char  | Char
 
; 
Char         : 
    "\\" LEXICAL_STATE CLASS_2_STATE (<CLASS_2>) =>|| | "\\" LEXICAL_STATE CLASS_3_STATE (<CLASS_3>) LEXICAL_STATE CLASS_4_STATE (<CLASS_4>) LEXICAL_STATE CLASS_4_STATE (<CLASS_4>) =>|| | "\\" LEXICAL_STATE CLASS_4_STATE (<CLASS_4>) ( LEXICAL_STATE CLASS_4_STATE (<CLASS_4>) =>|| )? =>|| | ENSURE ~( "\\" ) LEXICAL_STATE ANY (<ANY_CHAR>) 
; 
LEFTARROW    : 
    "<-" Spacing
 
; 
SLASH        : 
    "/" Spacing
 
; 
AND          : 
    "&" Spacing
 
; 
NOT          : 
    "!" Spacing
 
; 
QUESTION     : 
    "?" Spacing
 
; 
STAR         : 
    "*" Spacing
 
; 
PLUS         : 
    "+" Spacing
 
; 
OPEN         : 
    "(" Spacing
 
; 
CLOSE        : 
    ")" Spacing
 
; 
DOT          : 
    "." Spacing
 
; 
Spacing      : 
    ( ( Space  =>|| | Comment  ) =>|| )* 
; 
Comment      : 
    "#" ( ( ENSURE ~( EndOfLine  ) LEXICAL_STATE ANY (<ANY_CHAR>) ) =>|| )* EndOfLine
 
; 
Space        : 
    " " =>|| | "\t" =>|| | EndOfLine
 
; 
EndOfLine    : 
    "\r\n" =>|| | "\n" =>|| | "\r" 
; 
EndOfFile    : 
    ENSURE ~( LEXICAL_STATE ANY (<ANY_CHAR>) ) 
; 
Cardinality  : 
    "%" ( ( Natural  ( ( ":" ( Natural =>|| )? "%" ) =>|| )? ) =>|| )? 
; 
Natural      : 
    "0" =>|| | LEXICAL_STATE CLASS_5_STATE (<CLASS_5>) ( LEXICAL_STATE CLASS_1_STATE (<CLASS_1>) =>|| )* 
; 
ENTAILS      : 
    ( ">>>" =>|| | "⫸" ) Spacing
         
; <ANY> TOKEN : <ANY_CHAR: ~[] >;
<CLASS_0_STATE> TOKEN: <CLASS_0: ["a"-"z","A"-"Z"] >;
<CLASS_1_STATE> TOKEN: <CLASS_1: ["0"-"9"] >;
<CLASS_2_STATE> TOKEN: <CLASS_2: ["n","r","t","\"","'","[","]","\\"] >;
<CLASS_3_STATE> TOKEN: <CLASS_3: ["0"-"2"] >;
<CLASS_4_STATE> TOKEN: <CLASS_4: ["0"-"7"] >;
<CLASS_5_STATE> TOKEN: <CLASS_5: ["1"-"9"] >;