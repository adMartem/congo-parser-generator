# Parser lexing package. Generated by ${generated_by}. Do not edit.
#import "common_utils.inc.ftl" as CU

import bisect
from enum import Enum, auto, unique
import logging
import re

from .tokens import (TokenType, LexicalState, InvalidToken, IgnoredToken,
                     SkippedToken, new_token)

  #list settings.extraTokenNames as tokenName
from .tokens import ${settings.extraTokens[tokenName]}
  /#list
from .utils import as_chr, _List, EMPTY_SET, HashSet

# See if an accelerated BitSet is available.
try:
    from _bitset import BitSet
    _fast_bitset = True
except ImportError:
    from .utils import BitSet
    _fast_bitset = False

${globals::translateLexerImports()}

#var NFA_RANGE_THRESHOLD = 16,
     MAX_INT=2147483647,
     lexerData=grammar.lexerData,
     multipleLexicalStates = lexerData.lexicalStates?size > 1,
     TT = "TokenType."

logger = logging.getLogger(__name__)

DEFAULT_TAB_SIZE = ${settings.tabSize}

#
# Hack to allow token types to be referenced in snippets without
# qualifying
#
globals().update(TokenType.__members__)

# NFA code and data
#if multipleLexicalStates
# A mapping from lexical state to NFA functions for that state.
[#-- We only need the mapping if there is more than one lexical state.--]
function_table_map = {}
/#if

# The nitty-gritty of the NFA code follows

#list lexerData.lexicalStates as lexicalState
[@GenerateStateCode lexicalState/]
/#list

# Just use binary search to check whether the char is in one of the
# intervals
def check_intervals(ranges, ch):
    index = bisect.bisect_left(ranges, ch)
    n = len(ranges)
    if index < n:
        if index % 2 == 0:
            if index < (n - 1):
                return ranges[index] <= ch <= ranges[index + 1]
        elif index > 0:
            return ranges[index - 1] <= ch <= ranges[index]
    return False

[#--
  Generate all the NFA transition code
  for the given lexical state
--]
#macro GenerateStateCode lexicalState
#list lexicalState.canonicalSets as state
  #if state_index = 0
[@GenerateInitialComposite state/]
  #elseif state.numStates = 1
[@SimpleNfaMethod state.singleState /]
  #else
[@CompositeNfaMethod state /]
  /#if
/#list

#list lexicalState.allNfaStates as nfaState
  #if nfaState.moveRanges?size >= NFA_RANGE_THRESHOLD
[@GenerateMoveArray nfaState/]
  /#if
/#list

def NFA_FUNCTIONS_${lexicalState.name}_init():
    functions = [
  #list lexicalState.canonicalSets as state
        ${state.methodName}[#if state_has_next],[/#if]
  /#list
    ]
  #if multipleLexicalStates
    function_table_map[LexicalState.${lexicalState.name}] = functions
  #else
    return functions
  /#if

  #if multipleLexicalStates
NFA_FUNCTIONS_${lexicalState.name}_init()
  #else
nfa_functions = NFA_FUNCTIONS_${lexicalState.name}_init()
  /#if

/#macro

[#--
   Generate the array representing the characters
   that this NfaState "accepts".
   This corresponds to the moveRanges field in
   org.congocc.core.NfaState
--]
#macro GenerateMoveArray nfaState
  #var moveRanges = nfaState.moveRanges
  #var arrayName = nfaState.movesArrayName
${arrayName} = [
  #list nfaState.moveRanges as char
    ${globals::displayChar(char)}[#if char_has_next],[/#if]
  /#list
]
/#macro

#macro GenerateInitialComposite nfaState
def ${nfaState.methodName}(ch, next_states, valid_types, already_matched_types):
    type = None
    [#var states = nfaState.orderedStates, lastBlockStartIndex=0]
    [#list states as state]
      [#if state_index ==0 || state.moveRanges != states[state_index-1].moveRanges]
          [#-- In this case we need a new if or possibly else if --]
         [#var useElif = true]
         [#if state_index == 0 || state::overlaps(states::subList(lastBlockStartIndex, state_index))]
           [#-- If there is overlap between this state and any of the states
                 handled since the last lone if, we start a new if-else 
                 If not, we continue in the same if-else block as before. --]
           [#set lastBlockStartIndex = state_index, useElif=false]
         [/#if]    
    ${useElif ?: "elif" : "if"} [@NfaStateCondition state /]:
      [/#if]
        if valid_types is None or ${state.type.label} in valid_types:
      [#if state.nextStateIndex >= 0]
            next_states.set(${state.nextStateIndex})
      [/#if]
      [#if !state_has_next || state.moveRanges != states[state_index+1].moveRanges]
        [#-- We've reached the end of the block. --]
          [#if state.nextState.final]
            [#--if (validTypes == null || validTypes.contains(${state.type.label}))--]
            type = ${state.type.label}
          [/#if]
      [/#if]
    [/#list]
    return type

/#macro

[#--
   Generate the method that represents the transitions
   that correspond to an instanceof org.congocc.core.CompositeStateSet
--]
#macro CompositeNfaMethod nfaState
def ${nfaState.methodName}(ch, next_states, valid_types, already_matched_types):
#if lexerData::isLazy(nfaState.type)
    if ${nfaState.type.label} in already_matched_types:
        return None
/#if
#if nfaState.hasFinalState
    type = None
/#if
#var states = nfaState.orderedStates, lastBlockStartIndex = 0
#list states as state
  [#if state_index ==0 || state.moveRanges != states[state_index-1].moveRanges]
        [#-- In this case we need a new if or possibly else if --]
        #var useElif = true
         [#if state_index == 0 || state::overlaps(states::subList(lastBlockStartIndex, state_index))]
        [#-- If there is overlap between this state and any of the states
                handled since the last lone if, we start a new if-else 
                If not, we continue in the same if-else block as before. --]
          #set lastBlockStartIndex = state_index, useElif = false
        /#if
    ${useElif ?: "elif" : "if"} [@NfaStateCondition state /]:
  /#if
  #if state.nextStateIndex >= 0
        next_states.set(${state.nextStateIndex})
  /#if
  #if !state_has_next || state.moveRanges != states[state_index+1].moveRanges
    [#-- We've reached the end of the block. --]
    #if state.nextState.final
        type = ${state.type.label}
    /#if
  /#if
/#list
#if nfaState.hasFinalState
    return type
#else
    # return None
/#if

/#macro

[#-- 
   Generate a method for a single, i.e. non-composite NFA state 
--]
#macro SimpleNfaMethod state
def ${state.methodName}(ch, next_states, valid_yypes, already_matched_types):
#if lexerData::isLazy(state.type)
    if ${state.type.label} in already_matched_types:
        return None
/#if
    if [@NfaStateCondition state /]:
#if state.nextStateIndex >= 0
        next_states.set(${state.nextStateIndex})
/#if
#if state.nextState.final
        return ${state.type.label}
/#if
    # return None

/#macro

[#--
Generate the condition part of the NFA state transition
If the size of the moveRanges vector is greater than NFA_RANGE_THRESHOLD
it uses the canned binary search routine. For the smaller moveRanges
it just generates the inline conditional expression
--]
#macro NfaStateCondition nfaState
    #if nfaState.moveRanges?size < NFA_RANGE_THRESHOLD
      [@RangesCondition nfaState.moveRanges /][#t]
    #elseif nfaState.hasAsciiMoves && nfaState.hasNonAsciiMoves
      ([@RangesCondition nfaState.asciiMoveRanges/]) or (ch >= chr(128) and check_intervals(${nfaState.movesArrayName}, ch))[#t]
    #else
      check_intervals(${nfaState.movesArrayName}, ch)[#t]
    /#if
/#macro

[#--
This is a recursive macro that generates the code corresponding
to the accepting condition for an NFA state. It is used
if NFA state's moveRanges array is smaller than NFA_RANGE_THRESHOLD
(which is set to 16 for now)
--]
#macro RangesCondition moveRanges
    #var left = moveRanges[0], right = moveRanges[1]
    #var displayLeft = globals::displayChar(left), displayRight = globals::displayChar(right)
    #var singleChar = left == right
    #if moveRanges?size==2
       #if singleChar
          ch == ${displayLeft}[#t]
       #elseif left +1 == right
          ch == ${displayLeft} or ch == ${displayRight}[#t]
       #elseif left > 0
          ch >= ${displayLeft}[#t]
          #if right < 1114111
 and ch <= ${displayRight}[#rt]
          /#if
       #else
           ch <= ${displayRight}[#t]
       /#if
    #else
       ([@RangesCondition moveRanges[0..1]/]) or ([@RangesCondition moveRanges[2..moveRanges?size-1]/])[#t]
    /#if
/#macro

# Compute the maximum size of state bitsets

    #if !multipleLexicalStates
MAX_STATES = ${lexerData.lexicalStates[0].allNfaStates?size}
    #else
MAX_STATES = max(
      #list lexerData.lexicalStates as state
    ${state.allNfaStates?size}[#if state_has_next],[/#if]
      /#list
)
    /#if

# Lexer code and data

#macro EnumSet varName tokenNames indent=0
    #var is = ""?right_pad(indent)
    #if tokenNames?size=0
${is}self.${varName} = EMPTY_SET
    #else
${is}self.${varName} = {
   #list tokenNames as type
${is}    TokenType.${type}[#if type_has_next],[/#if]
   /#list
${is}}
    /#if
/#macro

    #if multipleLexicalStates
# A mapping for lexical state transitions triggered by a certain token type (token type -> lexical state)
token_type_to_lexical_state_map = {}
    /#if

def get_function_table_map(lexical_state):
    #if multipleLexicalStates
    return function_table_map[lexical_state]
    #else
    # We only have one lexical state in this case, so we return that!
    return nfa_functions
    /#if

[#var PRESERVE_LINE_ENDINGS=settings.preserveLineEndings?string("True", "False")
      JAVA_UNICODE_ESCAPE= settings.javaUnicodeEscape?string("True", "False")
      ENSURE_FINAL_EOL = settings.ensureFinalEOL?string("True", "False")
      TERMINATING_STRING = "\"" + settings.terminatingString?j_string + "\""
      PRESERVE_TABS = settings.preserveTabs?string("True", "False")
]

CODING_PATTERN = re.compile(rb'^[ \t\f]*#.*coding[:=][ \t]*([-_.a-zA-Z0-9]+)')

def _input_text(input_source):
    # Check if it's an existing filename
    try:
        with open(input_source, 'rb') as f:
            text = f.read()
    except OSError:
        return input_source  # assume it's source rather than a path to source
    implicit = False
    if len(text) <= 3:
        encoding = 'utf-8'
        implicit = True
    elif text[:3] == b'\xEF\xBB\xBF':
        text = text[3:]
        encoding = 'utf-8'
    elif text[:2] == b'\xFF\xFE':
        text = text[2:]
        encoding = 'utf-16le'
    elif text[:2] == b'\xFE\xFF':
        text = text[2:]
        encoding = 'utf-16be'
    elif text[:4] == b'\xFF\xFE\x00\x00':
        text = text[4:]
        encoding = 'utf-32le'
    elif text[:4] == b'\x00\x00\xFE\xFF':
        text = text[4:]
        encoding = 'utf-32be'
    else:
        # No encoding from BOM.
        encoding = 'utf-8'
        implicit = True
        if input_source.endswith(('.py', '.pyw')):
            # Look for coding in first two lines
            parts = text.split(b'\n', 2)
            m = CODING_PATTERN.match(parts[0])
            if not m and len(parts) > 1:
                m = CODING_PATTERN.match(parts[1])
            if m:
                encoding = m.groups()[0].decode('ascii')
    try:
        return text.decode(encoding, errors='replace')
    except UnicodeDecodeError:
        if not implicit:
            raise
        return text.decode('latin-1')

class TokenSource:

    __slots__ = (
        'input_source',
        'tab_size',
#if settings.usesPreprocessor
        '_ignored',
/#if
        '_skipped',
        '_token_offsets',
        '_token_location_table',
        '_line_offsets',
        '_need_to_calculate_columns',
        'content',
        'content_len',
        'starting_line',
        'starting_column',
    )

    def __init__(
        self, input_source, starting_line, starting_column,
        tab_size, preserve_tabs, preserve_line_endings,
        java_unicode_escape, terminating_string
    ):
        if not input_source:
            raise ValueError('input filename not specified')
        self.input_source = input_source
        text = _input_text(input_source)
        self.tab_size = tab_size
        self.content = self.munge_content(text, preserve_tabs, preserve_line_endings, java_unicode_escape, terminating_string)
        self.content_len = n = len(self.content)
        n += 1
        self._need_to_calculate_columns = BitSet(n)
        self._line_offsets = self.create_line_offsets_table(self.content)
        self._token_location_table = [None] * n
        self._token_offsets = BitSet(n)
#if settings.usesPreprocessor
        self._ignored = IgnoredToken(self, 0, 0)
        self._ignored.is_unparsed = True
/#if
        self._skipped = SkippedToken(self, 0, 0)
        self._skipped.is_unparsed = True

    def __len__(self):
        return self.content_len

    def __getitem__(self, i):
        return self.content[i]

    def munge_content(self, content, preserve_tabs, preserve_lines,
                      java_unicode_escape, terminating_string):
        if preserve_tabs and preserve_lines and not java_unicode_escape:
            if terminating_string :
                if content[-len(terminating_string):] != terminating_string :
                    return content
        tab_size=self.tab_size
        buf = []
        index = 0
        # This is just to handle tabs to spaces. If you don't have that setting set, it
        # is really unused.
        col = 0
        # Don't know if this is really needed for Python ...
        code_points = list(content)
        cplen = len(code_points)
        while index < cplen:
            ch = code_points[index]
            index += 1
            if ch == '\n':
                buf.append(ch)
                col = 0
            elif java_unicode_escape and ch == '\\' and index < cplen and code_points[index] == 'u':
                num_preceding_slashes = 0
                i = index - 1
                while i >= 0:
                    if code_points[i] == '\\':
                        num_preceding_slashes += 1
                    else:
                        break
                    i -= 1
                if num_preceding_slashes % 2 == 0:
                    buf.append('\\')
                    col += 1
                    continue
                num_consecutive_us = 0
                i  = index
                while i < cplen:
                    if code_points[i] == 'u':
                        num_consecutive_us += 1
                    else:
                        break
                    i += 1
                four_hex_digits = ''.join(code_points[index + num_consecutive_us:index + num_consecutive_us + 4])
                buf.append(chr(int(four_hex_digits, 16)))
                index += num_consecutive_us + 4
                col += 1
            elif not preserve_lines and ch == '\r':
                buf.append('\n')
                col = 0
                if index < cplen and code_points[index] == '\n':
                    index += 1
            elif ch == '\t' and not preserve_tabs:
                spaces_to_add = tab_size - col % tab_size
                for i in range(spaces_to_add):
                    buf.append(' ')
                    col += 1
            else:
                buf.append(ch)
                col += 1
        if terminating_string :
            if content[-len(terminating_string):] != terminating_string :
                buf.append(terminating_string)
        return ''.join(buf)

    def skip_tokens(self, begin, end):
        tlt = self._token_location_table
        for i in range(begin, end):
[#if settings.usesPreprocessor]
            if tlt[i] is not self._ignored:
                tlt[i] = self._skipped
[#else]
            tlt[i] = self._skipped
[/#if]

[#if settings.usesPreprocessor]
    def next_unignored_offset(self, offset):
        tlt = self._token_location_table
        limit = len(tlt) - 1
        while (offset < limit) and tlt[offset] is self._ignored:
            offset += 1
        return offset

    def set_ignored_range(self, start, end):
        tlt = self._token_location_table
        for offset in range(start, end):
            tlt[offset] = self._ignored
        self._token_offsets.clear(start, end)

    def spans_PP_instruction(self, start, end):
        tlt = self._token_location_table
        for i in range(start, end):
            if tlt[i] is self._ignored:
                return True
        return False

    def get_length(self, start, end):
        result = 0
        tlt = self._token_location_table
        for i in range(start, end):
            if tlt[i] is not self._ignored:
                result += 1
        return result

    def set_line_skipped(self, tok):
        lineno = tok.begin_line
        soff = self.get_line_start_offset(lineno)
        eoff = self.get_line_start_offset(lineno + 1)
        self.set_ignored_range(soff, eoff)
        tok.begin_offset = soff
        tok.end_offset = eoff

[/#if]
[#if settings.cppContinuationLine]
    def handle_c_continuation_lines(self):
        content = self.content
        offset = content.find('\\')
        while offset >= 0:
            nl_index = content.find('\n', offset)
            if nl_index < 0:
                break
            if not content[offset + 1:nl_index].strip():
                self.set_ignored_range(offset, nl_index + 1)
            offset = content.find('\\', offset + 1)

[/#if]
    def cache_token(self, tok):
        begin_offset = tok.begin_offset
        end_offset = tok.end_offset
        toff = self._token_offsets
        toff.set(begin_offset)
        if end_offset > begin_offset + 1:
            # This handles some weird usage cases where token locations
            # have been adjusted.
            toff.clear(begin_offset + 1, end_offset)
        self._token_location_table[begin_offset] = tok

    def uncache_tokens(self, last_token):
        end_offset = last_token.end_offset
        toff = self._token_offsets
        if end_offset < toff.bits:
            toff.clear(last_token.end_offset, toff.bits)

    def next_cached_token(self, offset):
        next_offset = self._token_offsets.next_set_bit(offset)
        return self._token_location_table[next_offset] if next_offset >= 0 else None

    def previous_cached_token(self, offset):
        prev_offset = self._token_offsets.previous_set_bit(offset - 1)
        return self._token_location_table[prev_offset] if prev_offset >= 0 else None

[#if settings.usesPreprocessor]
    #
    # This is used in conjunction with having a preprocessor.
    # We set which lines are actually parsed lines and the
    # unset ones are ignored.
    # line_set is a bitset that holds which lines
    # are parsed (i.e. not ignored)
    #
    def _set_parsed_lines(self, line_set, reversed):
        for i in range(line_set.size):
            turn_off_line = line_set.get(i + 1)
            if reversed:
                turn_off_line = not turn_off_line
            if turn_off_line:
                loff = self._line_offsets
                line_offset = loff[i]
                next_line_offset = loff[i + 1] if i < (loff.size - 1) else self.content_len
                self.set_ignored_range(line_offset, next_line_offset)

    #
    # This is used in conjunction with having a preprocessor.
    # We set which lines are actually parsed lines and the
    # unset ones are ignored.
    # line_set is a bitset that holds which lines
    # are parsed (i.e. not ignored)
    #
    def set_parsed_lines(line_set):
        self._set_parsed_lines(line_set, False)

    def set_unparsed_lines(line_set):
        self._set_parsed_lines(line_set, True)

[/#if]
    def get_line_start_offset(self, lineno):
        rln = lineno - self.starting_line
        if rln <= 0:
            return 0
        if rln >= len(self._line_offsets):
            return self.content_len
        return self._line_offsets[rln]

    def get_line_end_offset(self, lineno):
        rln = lineno - self.starting_line
        if rln < 0:
            return 0
        if rln >= len(self._line_offsets):
            return self.content_len
        if rln == len(self._line_offsets) - 1:
            return self.content_len - 1
        return self._line_offsets[rln + 1] - 1

    def get_line_from_offset(self, pos):
        if pos >= self.content_len:
            result = len(self._line_offsets)
            if self.content[-1] != '\n':
                result -= 1
        else:
            sr = bisect.bisect_right(self._line_offsets, pos) - 1
            if sr >= 0:
                result = sr
            else:
                result = sr + 1
        return self.starting_line + result

    def create_line_offsets_table(self, content):
        if not content:
            return [0]
        length = len(content)
        line_count = 0
        length = len(content)
        for i in range(length):
            ch = content[i]
            if ch == '\t':
                self._need_to_calculate_columns.set(line_count)
            if ch == '\n':
                line_count += 1
        if content[-1] != '\n':
            line_count += 1
        result = [0]
        for i in range(length):
            ch = content[i]
            if ch == '\n':
                if (i + 1) == length:
                    break
                result.append(i + 1)
        return result

    def get_codepoint_column_from_offset(self, pos):
        if pos >= self.content_len:
            return 1
        if pos == 0:
            return self.starting_column
        line = self.get_line_from_offset(pos) - self.starting_line
        line_start = self._line_offsets[line]
        start_col_adjustment = 1 if line > 0 else self.starting_column
        unadjusted_col = pos - line_start + start_col_adjustment
        if not self._need_to_calculate_columns[line]:
            return unadjusted_col
        result = start_col_adjustment
        i = line_start
        while i < pos:
            ch = self.content[i]
            if ch == '\t':
                result += self.tab_size - (result - 1) % self.tab_size
            else:
                result += 1
            i += 1
        return result

    def get_line_length(self, lineno):
        soff = self.get_line_start_offset(lineno)
        eoff = self.get_line_end_offset(lineno)
        return eoff - soff + 1

    def get_text(self, start_offset, end_offset):
#if !settings.usesPreprocessor
        return self.content[start_offset:end_offset]
#else
        chars = []
        tlt = self._token_location_table
        content = self.content
        for offset in range(start_offset, end_offset):
            if tlt[offset] is not self._ignored:
                chars.append(content[offset])
        return ''.join(chars)
/#if

#
# We use a 2-element tuple (matched_type, match_len) instead of the
# MatchInfo class used in the Java code.
#

def _get_match_info(source, pos, active_token_types, nfa_functions,
                    current_states, next_states, match_info):
    source_len = len(source)
    if pos >= source_len:
        return (EOF, 0)
    start = pos
    match_length = 0
    matched_type = INVALID
    already_matched_types = set()
    if current_states is None:
        current_states = BitSet(MAX_STATES)
    else:
        current_states.clear()
    if next_states is None:
        next_states = BitSet(MAX_STATES)
    else:
        next_states.clear()
    # the core NFA loop
    while True:
        # Holder for the new type (if any) matched on this iteration
        if pos <= start:
            current_states.set(0)
        else:
            # What was next_states on the last iteration
            # is now the current_states!
            temp = current_states
            current_states = next_states
            next_states = temp
            next_states.clear()
    [#if settings.usesPreprocessor]
            if isinstance(source, TokenSource):
                pos = source.next_unignored_offset(pos)
    [/#if]
        if pos >= source_len:
            break
        cur_char = source[pos]
        pos += 1
        next_active = current_states.next_set_bit(0)
        while next_active != -1:
            returned_type = nfa_functions[next_active](cur_char, next_states, active_token_types, already_matched_types)
            # logger.debug('%5d %s %s %s %s', pos, cur_char, returned_type, current_states, next_states)
            if returned_type and (((pos - start) > match_length) or returned_type.value < matched_type.value):
                matched_type = returned_type
                match_length = pos - start
                already_matched_types.add(returned_type)
            next_active = current_states.next_set_bit(next_active + 1)
        if pos >= source_len:
            break
        if next_states.is_empty:
            break
    return (matched_type, match_length)

#var lexerClassName = "Lexer"
class ${lexerClassName}(TokenSource):

    __slots__ = TokenSource.__slots__ + (
#if settings.lexerUsesParser
        'parser',
/#if
        'next_states',
        'current_states',
        'active_token_types',
        'regular_tokens',
        'unparsed_tokens',
        'skipped_tokens',
        'more_tokens',
        'lexical_state',
[#--        '_matcher_hook', --]
#var injectedFields = globals::injectedLexerFieldNames()
#if injectedFields?size > 0
        # injected fields
  #list injectedFields as fieldName
        '${fieldName}',
  /#list
/#if
    )

    def __init__(self, input_source, lex_state=LexicalState.${lexerData.lexicalStates[0].name}, line=1, column=1):
${globals::translateLexerInjections(true)}
        super().__init__(
            input_source, line, column, DEFAULT_TAB_SIZE,
            ${PRESERVE_TABS}, ${PRESERVE_LINE_ENDINGS}, ${JAVA_UNICODE_ESCAPE}, ${TERMINATING_STRING}
        )
#if settings.lexerUsesParser
        self.parser = None
/#if
[#--        self._matcher_hook = None --]
        # The following two BitSets are used to store the current active
        # NFA states in the core tokenization loop
        self.next_states = BitSet(MAX_STATES)
        self.current_states = BitSet(MAX_STATES)

        self.active_token_types = set(TokenType)
#list settings.deactivatedTokens as token
        self.active_token_types.remove(TokenType.${token})
/#list

        # Just used to "bookmark" the starting location for a token
        # for when we put in the location info at the end.
        self.starting_line = line
        self.starting_column = column

        # Token types that are "regular" tokens that participate in parsing,
        # i.e. declared as TOKEN
        [@EnumSet "regular_tokens" lexerData.regularTokens.tokenNames 8 /]

  #list settings.extraTokenNames as tokenName
        self.regular_tokens.add(${settings.extraTokens[tokenName]})
  /#list
        # Token types that do not participate in parsing
        # i.e. declared as UNPARSED (or SPECIAL_TOKEN)
        [@EnumSet "unparsed_tokens" lexerData.unparsedTokens.tokenNames 8 /]
        [#-- Tokens that are skipped, i.e. SKIP --]
        [@EnumSet "skipped_tokens" lexerData.skippedTokens.tokenNames 8 /]
        # Tokens that correspond to a MORE, i.e. that are pending
        # additional input
        [@EnumSet "more_tokens" lexerData.moreTokens.tokenNames 8 /]
        self.lexical_state = lex_state
        if lex_state is not None:
            self.switch_to(lex_state)
#if settings.cppContinuationLine
        self.handle_c_continuation_lines()
/#if

    #
    # The public method for getting the next token.
    # It checks if we have already cached the token after this one.
    # If not, it goes to the NFA machinery
    #

    def get_next_token(self, tok, active_token_types=None):
        if active_token_types is None:
            active_token_types = self.active_token_types
        if tok is None:
            tok = self._tokenize_at(0, None, active_token_types)
            self.cache_token(tok)
            return tok
        cached_token = tok.next_cached_token
        # If not currently active, discard it and go back to the lexer
        if (cached_token and
            active_token_types is not None and
            cached_token.type not in active_token_types):
            self.reset(tok)
            cached_token = None
        if cached_token:
            return cached_token
        tok = self._tokenize_at(tok.end_offset, None, active_token_types)
        self.cache_token(tok)
        return tok

    def _tokenize_at(self, pos, lex_state, active_token_types):
        if lex_state is None:
            lex_state = self.lexical_state
        token_begin_offset = pos
        in_more = False
        invalid_chars = []
        matched_token = None
        matched_type = None
        match_info = (None, 0)
        current_states = BitSet(MAX_STATES)
        next_states = BitSet(MAX_STATES)
        # The core tokenization loop
        while matched_token is None:
#if multipleLexicalStates
            # Get the NFA function table current lexical state.
            # If we are in a MORE, there is some possibility that there 
            # was a lexical state change since the last iteration of this loop!
            # if there aren't multiple lexical states, there should be a
            # module-level nfa_functions list.
            nfa_functions = get_function_table_map(lex_state)
/#if
#if settings.usesPreprocessor
            pos = self.next_unignored_offset(pos)
/#if
            if not in_more:
                token_begin_offset = pos
[#--                
            if self._matcher_hook:
                match_info = self._matcher_hook(self, pos, active_token_types, nfa_functions, current_states, next_states, match_info)
                if match_info is None:
                    match_info = _get_match_info(self, pos, active_token_types, nfa_functions, current_states, next_states, match_info)
            else:
                match_info = _get_match_info(self, pos, active_token_types, nfa_functions, current_states, next_states, match_info)
--]
            match_info = _get_match_info(self, pos, active_token_types, nfa_functions, current_states, next_states, match_info)
            matched_type = match_info[0]
            in_more = matched_type in self.more_tokens
            pos += match_info[1]
#if lexerData.hasLexicalStateTransitions
            new_state = token_type_to_lexical_state_map.get(matched_type)
            if new_state:
                lex_state = self.lexical_state = new_state
/#if
            if matched_type == INVALID:
                cp = self[token_begin_offset]
                invalid_chars.append(cp)
                pos += 1
                continue
            if invalid_chars:
                return InvalidToken(self, token_begin_offset - len(invalid_chars), token_begin_offset)
            if matched_type in self.skipped_tokens:
                self.skip_tokens(token_begin_offset, pos)
            elif matched_type in self.regular_tokens or matched_type in self.unparsed_tokens:
                matched_token = new_token(matched_type, self, token_begin_offset, pos)
                matched_token.is_unparsed = matched_type not in self.regular_tokens
#if lexerData.hasLexicalStateTransitions
        self.do_lexical_state_switch(matched_token.type)
/#if
#if lexerData.hasTokenActions
        matched_token = self.token_lexical_actions(matched_token, matched_type)
/#if
#list grammar.lexerTokenHooks as tokenHookMethodName
  #if tokenHookMethodName = "CommonTokenAction"
        self.${tokenHookMethodName}(matched_token)
  #else
        matched_token = self.${tokenHookMethodName}(matched_token)
  /#if
/#list
        return matched_token

    def do_lexical_state_switch(self, token_type):
        new_state = token_type_to_lexical_state_map.get(token_type)
        if new_state is None:
            return False
        return self.switch_to(new_state)

    #
    # Switch to specified lexical state.
    #
    def switch_to(self, lex_state):
        if self.lexical_state != lex_state:
            self.lexical_state = lex_state
            return True
        return False

    # Reset the token source input
    # to just after the Token passed in.
    def reset(self, t, lex_state=None):
#list grammar.resetTokenHooks as resetTokenHookMethodName
        self.${globals::translateIdentifier(resetTokenHookMethodName)}(t)
/#list
        self.uncache_tokens(t)
        if lex_state:
            self.switch_to(lex_state)
#if lexerData.hasLexicalStateTransitions
        else:
            self.do_lexical_state_switch(t.type)
/#if

#if lexerData.hasTokenActions
    def token_lexical_actions(self, matched_token, matched_type):
  #var idx = 0
  #list lexerData.regularExpressions as regexp
    #if regexp.codeSnippet?has_content
        [#if idx > 0]el[/#if]if matched_type == TokenType.${regexp.label}:
${globals::translateCodeBlock(regexp.codeSnippet.javaCode, 12)}
      #set idx = idx + 1
    /#if
  /#list
        return matched_token
/#if

#if settings.tokenChaining
    def cache_token(self, tok):
        if tok.is_inserted:
            next = tok.next_cached_token
            if next:
                self.cache_token(next)
            return
        super().cache_token(tok)

    def uncache_tokens(self, last_token):
        super().uncache_tokens(last_token)
        last_token.unset_appended_token()

/#if
    def at_line_start(self, tok):
        offset = tok.begin_offset
        while offset > 0:
            offset -= 1
            c = self.content[offset]
            if not c.isspace():
                return False
            if c == '\n':
                break
        return True

    def get_line(self, tok):
        lineno = tok.begin_line
        soff = self.get_line_start_offset(lineno)
        eoff = self.get_line_end_offset(lineno)
        return self.get_text(soff, eoff + 1)

${globals::translateLexerInjections(false)}

#if lexerData.hasLexicalStateTransitions
# Generate the map for lexical state transitions from the various token types (if necessary)
  #list grammar.lexerData.regularExpressions as regexp
    #if !regexp.newLexicalState?is_null
token_type_to_lexical_state_map[TokenType.${regexp.label}] = LexicalState.${regexp.newLexicalState.name}
    /#if
  /#list
/#if
