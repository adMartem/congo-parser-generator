 /* Generated by: ${generated_by}. ${filename} ${settings.copyrightBlurb} */
 
 [#--
    This template generates the XXXLexer.java class.
    The details of generating the code for the NFA state machine
    are in the imported template NfaCode.java.ftl
 --]

 [#var TOKEN = settings.baseTokenClassName]
 
package ${settings.parserPackage};

import ${settings.parserPackage}.${TOKEN}.TokenType;
import static ${settings.parserPackage}.${TOKEN}.TokenType.*;
[#if settings.rootAPIPackage?has_content]
   import ${settings.rootAPIPackage}.Node;
   import ${settings.rootAPIPackage}.TokenSource;
[/#if]

[#import "NfaCode.java.ftl" as NFA]

[#var lexerData=grammar.lexerData]

[#var PRESERVE_LINE_ENDINGS=settings.preserveLineEndings?string("true", "false")
      JAVA_UNICODE_ESCAPE= settings.javaUnicodeEscape?string("true", "false")
      PRESERVE_TABS = settings.preserveTabs?string("true", "false")
      TERMINATING_STRING = "\"" + settings.terminatingString?j_string + "\""
]      
[#var BaseToken = settings.treeBuildingEnabled?string("Node.TerminalNode", "${TOKEN}")]

[#macro EnumSet varName tokenNames]
   [#if tokenNames?size=0]
       static private final EnumSet<TokenType> ${varName} = EnumSet.noneOf(TokenType.class);
   [#else]
       static final EnumSet<TokenType> ${varName} = EnumSet.of(
       [#list tokenNames as type]
          [#if type_index > 0],[/#if]
          ${type} 
       [/#list]
     ); 
   [/#if]
[/#macro]

import java.io.IOException;
import java.util.Arrays;
import java.util.BitSet;
import java.util.EnumMap;
import java.util.EnumSet;

[#if settings.rootAPIPackage?has_content]
import ${settings.rootAPIPackage}.TokenSource;
[/#if]

public class ${settings.lexerClassName} extends TokenSource
{

 public enum LexicalState {
  [#list lexerData.lexicalStates as lexicalState]
     ${lexicalState.name}
     [#if lexicalState_has_next],[/#if]
  [/#list]
 }  
   LexicalState lexicalState = LexicalState.values()[0];
 [#if settings.lexerUsesParser]
  public ${settings.parserClassName} parser;
 [/#if]

  [#if settings.deactivatedTokens?size>0]
    EnumSet<TokenType> activeTokenTypes = EnumSet.allOf(TokenType.class);
  [#else]
    EnumSet<TokenType> activeTokenTypes = null;
  [/#if]
  [#if settings.deactivatedTokens?size>0 || settings.extraTokens?size >0]
     {
       [#list settings.deactivatedTokens as token]
          activeTokenTypes.remove(${token});
       [/#list]
       [#list settings.extraTokenNames as token]
          regularTokens.add(${token});
       [/#list]
     }
  [/#if]

  // A lookup for lexical state transitions triggered by a certain token type
  private static EnumMap<TokenType, LexicalState> tokenTypeToLexicalStateMap = new EnumMap<>(TokenType.class);
  // ${TOKEN} types that are "regular" tokens that participate in parsing,
  // i.e. declared as TOKEN
  [@EnumSet "regularTokens" lexerData.regularTokens.tokenNames /]
  // ${TOKEN} types that do not participate in parsing
  // i.e. declared as UNPARSED (or SPECIAL_TOKEN)
  [@EnumSet "unparsedTokens" lexerData.unparsedTokens.tokenNames /]
  // Tokens that are skipped, i.e. SKIP 
  [@EnumSet "skippedTokens" lexerData.skippedTokens.tokenNames /]
  // Tokens that correspond to a MORE, i.e. that are pending 
  // additional input
  [@EnumSet "moreTokens" lexerData.moreTokens.tokenNames /]
   
    public ${settings.lexerClassName}(CharSequence input) {
        this("input", input);
    }

    /**
     * @param inputSource just the name of the input source (typically the filename)
     * that will be used in error messages and so on.
     * @param input the input
     */
    public ${settings.lexerClassName}(String inputSource, CharSequence input) {
        this(inputSource, input, LexicalState.${lexerData.lexicalStates[0].name}, 1, 1);
    }

     /**
      * @param inputSource just the name of the input source (typically the filename) that 
      * will be used in error messages and so on.
      * @param input the input
      * @param lexicalState The starting lexical state, may be null to indicate the default
      * starting state
      * @param line The line number at which we are starting for the purposes of location/error messages. In most 
      * normal usage, this is 1.
      * @param column number at which we are starting for the purposes of location/error messages. In most normal
      * usages this is 1.
      */
     public ${settings.lexerClassName}(String inputSource, CharSequence input, LexicalState lexState, int startingLine, int startingColumn) {
        super(inputSource, input, startingLine, startingColumn,
                        ${settings.tabSize}, ${PRESERVE_TABS}, 
                        ${PRESERVE_LINE_ENDINGS}, 
                        ${JAVA_UNICODE_ESCAPE}, 
                        ${TERMINATING_STRING});
        if (lexicalState != null) switchTo(lexState);
     [#if settings.cppContinuationLine]
        handleCContinuationLines();
     [/#if]
     }

  /**
   * The public method for getting the next token.
   * It checks whether we have already cached
   * the token after this one. If not, it finally goes 
   * to the NFA machinery
   */ 
    public ${TOKEN} getNextToken(${TOKEN} tok) {
       if (tok == null) {
          tok = tokenizeAt(0);
          cacheToken(tok);
          return tok;
       }
       ${TOKEN} cachedToken = tok.nextCachedToken();
    // If the cached next token is not currently active, we
    // throw it away and go back to the XXXLexer
       if (cachedToken != null && activeTokenTypes != null && !activeTokenTypes.contains(cachedToken.getType())) {
           reset(tok);
           cachedToken = null;
       }
       if (cachedToken == null) {
           ${TOKEN} token = tokenizeAt(tok.getEndOffset());
           cacheToken(token);
           return token;
       }
       return cachedToken;
    }

  static class MatchInfo {
      TokenType matchedType;
      int matchLength;

      MatchInfo(TokenType matchedType, int matchLength) {
          this.matchedType = matchedType;
          this.matchLength = matchLength;
      }
  }

  /**
   * Core tokenization method. Note that this can be called from a static context.
   * Hence the extra parameters that need to be passed in.
   */
  static MatchInfo getMatchInfo(CharSequence input, int position, EnumSet<TokenType> activeTokenTypes, NfaFunction[] nfaFunctions) {
       if (position >= input.length()) {
          return new MatchInfo(EOF, 0);
       }
       int start = position, matchLength = 0;
       TokenType matchedType = null;
       BitSet currentStates = new BitSet(${lexerData.maxNfaStates}),
              nextStates=new BitSet(${lexerData.maxNfaStates});
        // the core NFA loop
        do {
            // Holder for the new type (if any) matched on this iteration
            if (position > start) {
                // What was nextStates on the last iteration 
                // is now the currentStates!
                BitSet temp = currentStates;
                currentStates = nextStates;
                nextStates = temp;
                nextStates.clear();
    [#if settings.usesPreprocessor]
                if (input instanceof TokenSource) {
                    position = ((TokenSource) input).nextUnignoredOffset(position);
                }
    [/#if]                
            } else {
                currentStates.set(0);
            }
            if (position >= input.length()) {
                break;
            }
            int curChar = Character.codePointAt(input, position++);
            if (curChar > 0xFFFF) position++;
            int nextActive = currentStates.nextSetBit(0);
            while(nextActive != -1) {
                TokenType returnedType = nfaFunctions[nextActive].apply(curChar, nextStates, activeTokenTypes);
                if (returnedType != null && (position - start > matchLength || returnedType.ordinal() < matchedType.ordinal())) {
                    matchedType = returnedType;
                    matchLength = position - start;
                }
                nextActive = currentStates.nextSetBit(nextActive+1);
            }
            if (position >= input.length()) break;
       } while (!nextStates.isEmpty());
       return new MatchInfo(matchedType, matchLength);
  }

  /**
   * @param position The position at which to tokenize.
   * @return the Token at position
   */
  final ${TOKEN} tokenizeAt(int position) {
      int tokenBeginOffset = position;
      boolean inMore = false;
      StringBuilder invalidChars = null;
      ${TOKEN} matchedToken = null;
      TokenType matchedType = null;
      // The core tokenization loop
      while (matchedToken == null) {
      [#if NFA.multipleLexicalStates]
       // Get the NFA function table for the current lexical state.
       // If we are in a MORE, there is some possibility that there 
       // was a lexical state change since the last iteration of this loop!
        NfaFunction[] nfaFunctions = functionTableMap.get(lexicalState);
      [/#if]
[#if settings.usesPreprocessor]      
        position = nextUnignoredOffset(position);
[/#if]        
        if (!inMore) tokenBeginOffset = position;
        MatchInfo matchInfo = getMatchInfo(this, position, activeTokenTypes, nfaFunctions);
        matchedType = matchInfo.matchedType;
        inMore = moreTokens.contains(matchedType);
        position += matchInfo.matchLength;
     [#if lexerData.hasLexicalStateTransitions]
        LexicalState newState = tokenTypeToLexicalStateMap.get(matchedType);
        if (newState !=null) {
            this.lexicalState = newState;
        }
     [/#if]
        if (matchedType == null) {
            if (invalidChars==null) {
                invalidChars=new StringBuilder();
            } 
            int cp  = Character.codePointAt(this, tokenBeginOffset);
            invalidChars.appendCodePoint(cp);
            ++position;
            if (cp >0xFFFF) ++position;
            continue;
        }
        if (invalidChars !=null) {
            position = tokenBeginOffset;
            return new InvalidToken(this, tokenBeginOffset - invalidChars.length(), tokenBeginOffset);
        }
        if (skippedTokens.contains(matchedType)) {
            skipTokens(tokenBeginOffset, position);
        }
        else if (regularTokens.contains(matchedType) || unparsedTokens.contains(matchedType)) {
            matchedToken = ${TOKEN}.newToken(matchedType, 
                                        this, 
                                        tokenBeginOffset,
                                        position);
            matchedToken.setUnparsed(!regularTokens.contains(matchedType));
        }
      }
[#if lexerData.hasLexicalStateTransitions]
      doLexicalStateSwitch(matchedToken.getType());
 [/#if]
 [#if lexerData.hasTokenActions]
      matchedToken = tokenLexicalActions(matchedToken, matchedType);
 [/#if]
 [#list grammar.lexerTokenHooks as tokenHookMethodName]
    [#if tokenHookMethodName = "CommonTokenAction"]
           ${tokenHookMethodName}(matchedToken);
    [#else]
            matchedToken = ${tokenHookMethodName}(matchedToken);
    [/#if]
 [/#list]
       return matchedToken;
   }


[#if lexerData.hasLexicalStateTransitions]
  // Generate the map for lexical state transitions from the various token types
  static {
    [#list grammar.lexerData.regularExpressions as regexp]
      [#if !regexp.newLexicalState?is_null]
          tokenTypeToLexicalStateMap.put(${regexp.label}, LexicalState.${regexp.newLexicalState.name});
      [/#if]
    [/#list]
  }

  boolean doLexicalStateSwitch(TokenType tokenType) {
       LexicalState newState = tokenTypeToLexicalStateMap.get(tokenType);
       if (newState == null) return false;
       return switchTo(newState);
  }
[/#if]
  
    /** 
     * Switch to specified lexical state. 
     * @param lexState the lexical state to switch to
     * @return whether we switched (i.e. we weren't already in the desired lexical state)
     */
    public boolean switchTo(LexicalState lexState) {
        if (this.lexicalState != lexState) {
           this.lexicalState = lexState;
           return true;
        }
        return false;
    }

    // Reset the token source input
    // to just after the ${TOKEN} passed in.
    void reset(${TOKEN} t, LexicalState state) {
[#list grammar.resetTokenHooks as resetTokenHookMethodName]
      ${resetTokenHookMethodName}(t);
[/#list]
      uncacheTokens(t);
      if (state != null) {
          switchTo(state);
      }
[#if lexerData.hasLexicalStateTransitions] 
      else {
          doLexicalStateSwitch(t.getType());
      }
[/#if]        
    }

  void reset(${TOKEN} t) {
      reset(t, null);
  }
    
 [#if lexerData.hasTokenActions]
  private ${TOKEN} tokenLexicalActions(${TOKEN} matchedToken, TokenType matchedType) {
    switch(matchedType) {
   [#list lexerData.regularExpressions as regexp]
        [#if regexp.codeSnippet?has_content]
      case ${regexp.label} :
          ${regexp.codeSnippet.javaCode}
           break;
        [/#if]
   [/#list]
      default : break;
    }
    return matchedToken;
  }
 [/#if]

    void cacheToken(${TOKEN} tok) {
[#if settings.tokenChaining]        
        if (tok.isInserted()) {
            ${TOKEN} next = tok.nextCachedToken();
            if (next != null) cacheToken(next);
            return;
        }
[/#if]        
        cacheTokenAt(tok, tok.getBeginOffset());
    }

[#if settings.tokenChaining]
    @Override
    protected void uncacheTokens(${BaseToken} lastToken) {
        super.uncacheTokens(lastToken);
        ((${TOKEN})lastToken).unsetAppendedToken();
    }
[/#if]    

 

  // Utility methods. Having them here makes it easier to handle things
  // more uniformly in other generation languages.

   private void setRegionIgnore(int start, int end) {
     setIgnoredRange(start, end);
   }

   private boolean atLineStart(${TOKEN} tok) {
      int offset = tok.getBeginOffset();
      while (offset > 0) {
        --offset;
        char c = charAt(offset);
        if (!Character.isWhitespace(c)) return false;
        if (c=='\n') break;
      }
      return true;
   }

   private String getLine(${TOKEN} tok) {
       int lineNum = tok.getBeginLine();
       return getText(getLineStartOffset(lineNum), getLineEndOffset(lineNum)+1);
   }

  
  // NFA related code follows.

  // The functional interface that represents 
  // the acceptance method of an NFA state
  static interface NfaFunction {
      TokenType apply(int ch, BitSet bs, EnumSet<TokenType> validTypes);
  }

 [#if NFA.multipleLexicalStates]
  // A lookup of the NFA function tables for the respective lexical states.
  private static final EnumMap<LexicalState,NfaFunction[]> functionTableMap = new EnumMap<>(LexicalState.class);
 [#else]
  [#-- We don't need the above lookup if there is only one lexical state.--]
   static private NfaFunction[] nfaFunctions;
 [/#if]
 
  // Initialize the various NFA method tables
  static {
    [#list grammar.lexerData.lexicalStates as lexicalState]
      ${lexicalState.name}.NFA_FUNCTIONS_init();
    [/#list]
  }

 //The Nitty-gritty of the NFA code follows.
 [#list lexerData.lexicalStates as lexicalState]
 /**
  * Holder class for NFA code related to ${lexicalState.name} lexical state
  */
  private static class ${lexicalState.name} {
   [@NFA.GenerateStateCode lexicalState/]
  }
 [/#list]  
}
