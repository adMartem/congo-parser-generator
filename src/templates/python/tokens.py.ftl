# Parser tokens package. Generated by ${generated_by}. Do not edit.

from enum import Enum, auto, unique

from .utils import _GenWrapper, _List

__all__ = [
    '${settings.baseNodeClassName}',
    'TokenType',
    'Token',
[#var tokenSubClassInfo = globals::tokenSubClassInfo()]
[#list tokenSubClassInfo.sortedNames as name]
    '${name}',
[/#list]
    'new_token',
    'InvalidToken',
    'IgnoredToken',
    'SkippedToken',
    'LexicalState'
]

@unique
class TokenType(Enum):
 [#list lexerData.regularExpressions as regexp]
    ${regexp.label} = auto()
 [/#list]
 [#list settings.extraTokenNames as t]
    ${t} = auto()
 [/#list]
    INVALID = auto()

@unique
class LexicalState(Enum):
  [#list lexerData.lexicalStates as lexicalState]
    ${lexicalState.name} = auto()
  [/#list]

class ${settings.baseNodeClassName}:

    __slots__ = (
[#if settings.nodeUsesParser]
        'parser',
[/#if]
        '_token_source',
        'parent',
        'children',
        'is_unparsed',
        'begin_offset',
        'end_offset',
[#if settings.faultTolerant]
        'dirty',
[/#if]
        'named_child_map',
        'named_child_list_map',
    )

    def __init__(self, token_source, begin_offset=0, end_offset=0):
        self._token_source = token_source
        self.parent = None
        self.children = []
        self.begin_offset = begin_offset
        self.end_offset = end_offset
        self.named_child_map = {}
        self.named_child_list_map = {}
        # self.attributes = {}

    @property
    def begin_line(self):
        ts = self.token_source
        return 0 if not ts else ts.get_line_from_offset(self.begin_offset)

    @property
    def begin_column(self):
        ts = self.token_source
        return 0 if not ts else ts.get_codepoint_column_from_offset(self.begin_offset)

    @property
    def end_line(self):
        ts = self.token_source
        return 0 if not ts else ts.get_line_from_offset(self.end_offset - 1)

    @property
    def end_column(self):
        ts = self.token_source
        return 0 if not ts else ts.get_codepoint_column_from_offset(self.end_offset - 1)

    @property
    def token_source(self):
        result = self._token_source
#if settings.tokenChaining
        if not result:
            if self.prepended_token:
                result = self.prepended_token.token_source
            if not result and self.appended_token:
                result = self.appended_token.token_source
        self._token_source = result
/#if
        return result

    @token_source.setter
    def token_source(self, value):
        self._token_source = value

    @property
    def input_source(self):
        ts = self.token_source
        return "input" if not ts else ts.input_source

    def add(self, node, index=-1):
        if index < 0:
            self.children.append(node)
        else:
            self.children.insert(index, node)
        node.parent = self

    def remove(self, index):
        assert index >= 0
        self.children.pop(index)

    def __delitem__(self, index):
        n = len(self.children)
        if index < 0:
            index = n - index
        assert 0 <= index < n
        self.remove(index)

    def truncate(self, amount):
        new_end_offset = max(self.begin_offset, self.end_offset - amount)
        self.end_offset = new_end_offset

    def set_child(self, node, index):
        self.children[index] = node
        node.parent = self

    def __setitem__(self, index, node):
        n = len(self.children)
        if index < 0:
            index = n - index
        assert 0 <= index < n
        self.set_child(node, index)

    def clear_children(self):
        self.children.clear()

    @property
    def child_count(self):
        return len(self.children)

    def get_child(self, index):
        assert index >= 0
        return self.children[index]

    def __getitem__(self, index):
        n = len(self.children)
        if index < 0:
            index = n - index
        assert 0 <= index < n
        return self.get_child(index)

    @property
    def first_child(self):
        if self.children:
            return self.children[0]

    @property
    def last_child(self):
        if self.children:
            return self.children[-1]

    # Copy the location info from another node or start/end nodes
    def copy_location_info(self, start, end=None):
        self.token_source = start.token_source
        self.begin_offset = start.begin_offset
        if end is None:
            self.end_offset = start.end_offset
[#if settings.tokenChaining]
        self.prepended_token = start.prepended_token
        if end is None:
            self.appended_token = start.appended_token
[/#if]
        if end is not None:
            if self.token_source is None:
                self.token_source = end.token_source
            self.end_offset = end.end_offset
[#if settings.tokenChaining]
            self.appended_token = end.appended_token
[/#if]

    def open(self): pass

    def close(self): pass

    @property
    def token_type(self):
        if isinstance(self, Token):
            return self.type
        # return None

[#if settings.tokensAreNodes]
    #
    # Return the very first token that is part of this node.
    # It may be an unparsed (i.e. special) token.
    #
    @property
    def first_token(self):
        first = self.first_child
        if first is None:
            return None
        if isinstance(first, Token):
            tok = first
            while tok.previous_token is not None and tok.previous_token.is_unparsed:
                tok = tok.previous_token
            return tok
        return first.first_token

    @property
    def last_token(self):
        last = self.last_child
        if last is None:
            return None
        if isinstance(last, Token):
            return last
        return last.last_token


    def children_of_type(self, cls):
        return [child for child in self.children if isinstance(child, cls)]

    def first_child_of_type(self, type):
        for child in self.children:
            if isinstance(child, Token) and child.type == type:
                return child

    def first_descendant_of_type(self, type):
        for child in self.children:
            if isinstance(child, Token):
                if child.type == type:
                    return child
            else:
                child = child.first_descendant_of_type(type)
                if child:
                    return child

    def descendants(self, cls=None, predicate=None):
        if cls is None:
            cls = BaseNode
        result = []
        for child in self.children:
            if isinstance(child, cls):
                if not predicate or predicate(child):
                    result.append(child)
        return result

    @property
    def real_tokens(self):
        return self.descendants(Token, lambda t: not t.is_unparsed)

[/#if]

    def get_named_child(self, name):
        return self.named_child_map.get(name)

    def set_named_child(self, name, child):
        if name in self.named_child_map:
            raise ValueError('Duplicate named child not allowed: %s' % name)
        self.named_child_map[name] = child

    def get_named_child_list(self, name):
        return self.named_child_list_map.get(name)

    def add_to_named_child_list(self, name, child):
        existing = self.named_child_list_map.setdefault(name, [])
        existing.append(child)

    def __repr__(self):
        return '<%s (%d, %d)-(%d, %d)>' % (type(self).__name__,
                                           self.begin_line,
                                           self.begin_column,
                                           self.end_line,
                                           self.end_column)

class Token[#if settings.treeBuildingEnabled](${settings.baseNodeClassName})[/#if]:

    __slots__ = (
        'type',
#if settings.tokenChaining || settings.faultTolerant
        '_image',
/#if
#if settings.tokenChaining
        'prepended_token',
        'appended_token',
        'is_inserted',
/#if
        'previous_token',
        'next_token',
#var injectedFields = globals::injectedTokenFieldNames()
#if injectedFields?size > 0
        # injected fields
#list injectedFields as fieldName
        '${fieldName}',
/#list
/#if
#if settings.faultTolerant
        '_is_skipped',
        '_is_virtual',
        'dirty',
/#if
#if !settings.treeBuildingEnabled
        'begin_offset',
        'end_offset',
        'is_unparsed',
        'token_source',
/#if
    )

    def __init__(self, type, token_source, begin_offset, end_offset):
#if settings.treeBuildingEnabled
        super().__init__(token_source, begin_offset, end_offset)
#else
        self.begin_offset = begin_offset
        self.end_offset = end_offset
        self.token_source = token_source
/#if
${globals::translateTokenInjections(true)}
        self.type = type
        self.previous_token = None
        self.next_token = None
        self.is_unparsed = False
#if settings.faultTolerant
        self.dirty = False
        self._is_virtual = False
        self._is_skipped = False
/#if
#if settings.tokenChaining || settings.faultTolerant
        self._image = None
/#if
#if settings.tokenChaining
        self.prepended_token = None
        self.appended_token = None
        self.is_inserted = False

    def pre_insert(self, prepended_token):
        if prepended_token is self.prepended_token:
            return
        prepended_token.appended_token = self
        existing_previous_token = self.previous_cached_token
        if existing_previous_token:
            existing_previous_token.appended_token = prepended_token
            prepended_token.prepended_token = existing_previous_token
        prepended_token.is_inserted = True
        prepended_token.begin_offset = prepended_token.end_offset = self.begin_offset
        self.prepended_token = prepended_token

    def unset_appended_token(self):
        self.appended_token = None

/#if

    @property
    def image(self):
#if !settings.tokenChaining
        return self.source
#else
        return self._image if self._image else self.source
/#if

    @property
    def source(self):
        if self.type == TokenType.EOF:
            return ''
        ts = self.token_source
        return None if not ts else ts.get_text(self.begin_offset, self.end_offset)

#if settings.tokenChaining || settings.faultTolerant
    @image.setter
    def image(self, value):
        self._image = value

/#if

    def __str__(self):
        return self.image

    def _preceding_tokens(self):
        current = self
        t = current.previous_cached_token
        while t:
            current = t
            t = current.previous_cached_token
            yield current

    def preceding_tokens(self):
        return _GenWrapper(self._preceding_tokens())

    def _following_tokens(self):
        current = self
        t = current.next_cached_token
        while t:
            current = t
            t = current.next_cached_token
            yield current

    def following_tokens(self):
        return _GenWrapper(self._following_tokens())

    @property
    def is_virtual(self):
#if settings.faultTolerant
        return self._is_virtual or self.type == TokenType.EOF
#else
        return self.type == TokenType.EOF
/#if

#if settings.faultTolerant
    @is_virtual.setter
    def is_virtual(self, value):
        self._is_virtual = value

/#if
    @property
    def is_skipped(self):
#if settings.faultTolerant
        return self._is_skipped
#else
        return False
/#if

    def _get_next(self):
        return self.get_next_parsed_token()

    def _set_next(self, next):  # This is typically only used internally
        self.set_next_parsed_token(next)

    next = property(_get_next, _set_next)

    # return the next regular (i.e. parsed) token
    def get_next_parsed_token(self):
        result = self.next_cached_token
        while result and result.is_unparsed:
            result = result.next_cached_token
        return result

    @property
    def previous(self):
        result = self.previous_cached_token
        while result and result.is_unparsed:
            result = result.previous_cached_token
        return result

    @property
    def previous_cached_token(self):
#if settings.tokenChaining
        if self.prepended_token:
            return self.prepended_token
/#if
        ts = self.token_source
        if not ts:
            return None
        return ts.previous_cached_token(self.begin_offset)

    @property
    def next_cached_token(self):
#if settings.tokenChaining
        if self.appended_token:
            return self.appended_token
/#if
        ts = self.token_source
        if not ts:
            return None
        return ts.next_cached_token(self.end_offset)

    def __repr__(self):
        tn = self.type.name if self.type else None
        return '<%s %s %r (%d, %d)-(%d, %d)>' % (type(self).__name__,
                                                 tn,
                                                 self.image,
                                                 self.begin_line,
                                                 self.begin_column,
                                                 self.end_line,
                                                 self.end_column)

#if settings.treeBuildingEnabled && settings.tokenChaining
    # Copy the location info from another node or start/end nodes
    def copy_location_info(self, start, end=None):
        super().copy_location_info(start, end)
        if isinstance(start, Token):
            self.previous_token = start.previous_token
        if end is None:
            if isinstance(start, Token):
                self.appended_token = start.appended_token
                self.prepended_token = start.prepended_token
        else:
            if isinstance(start, Token):
                self.prepended_token = start.prepended_token
            if isinstance(end, Token):
                self.appended_token = end.appended_token
        self.token_source = start.token_source
#else
    # Copy the location info from another token or start/end tokens
    def copy_location_info(self, start, end=None):
        self.token_source = start.token_source
        self.begin_offset = start.begin_offset
        if end is None:
            self.end_offset = start.end_offset
  #if settings.tokenChaining
            self.prepended_token = start.prepended_token
            self.appended_token = start.appended_token
  /#if
        else:
            if self.token_source is None:
                self.token_source = end.token_source
            self.end_offset = end.end_offset
  #if settings.tokenChaining
            self.prepended_token = start.prepended_token
            self.appended_token = end.appended_token
  /#if
/#if

    @property
    def input_source(self):
        ts = self.token_source
        return 'input' if ts is None else ts.input_source

    @property
    def location(self):
        return '%s:%s:%s' % (self.input_source, self.begin_line,
                             self.begin_column)

#if !settings.treeBuildingEnabled
[#-- Not inherited from BaseNode --]
    @property
    def begin_line(self):
        ts = self.token_source
        return 0 if not ts else ts.get_line_from_offset(self.begin_offset)

    @property
    def begin_column(self):
        ts = self.token_source
        return 0 if not ts else ts.get_codepoint_column_from_offset(self.begin_offset)

    @property
    def end_line(self):
        ts = self.token_source
        return 0 if not ts else ts.get_line_from_offset(self.end_offset - 1)

    @property
    def end_column(self):
        ts = self.token_source
        return 0 if not ts else ts.get_codepoint_column_from_offset(self.end_offset - 1)

/#if

${globals::translateTokenInjections(false)}

class InvalidToken(Token):
    def __init__(self, token_source, begin_offset, end_offset):
        super().__init__(TokenType.INVALID, token_source, begin_offset, end_offset)
[#if settings.faultTolerant]
        self.is_unparsed = True
        self.dirty = True
[/#if]

class IgnoredToken(InvalidToken): pass
class SkippedToken(InvalidToken): pass

#
# Token subclasses
#
[#list tokenSubClassInfo.sortedNames as name]
class ${name}(${tokenSubClassInfo.tokenClassMap[name]}): pass

[/#list]
[#if settings.extraTokens?size > 0]
  [#list settings.extraTokenNames as name]
    [#var cn = settings.extraTokens[name]]
class ${cn}(Token):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
${globals::translateTokenSubclassInjections(cn, true)}
${globals::translateTokenSubclassInjections(cn, false)}
  [/#list]
[/#if]

def new_token(type, token_source, begin_offset, end_offset):
#if settings.treeBuildingEnabled
  #list lexerData.orderedNamedTokens as re
    #if re.generatedClassName != "Token" && !re.private
    if type == TokenType.${re.label}:
        return ${re.generatedClassName}(type, token_source, begin_offset, end_offset)
    /#if
  /#list
/#if
    return Token(type, token_source, begin_offset, end_offset)
