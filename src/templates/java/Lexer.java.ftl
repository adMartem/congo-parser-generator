 /* Generated by: ${generated_by}. ${filename} ${grammar.copyrightBlurb} */
 
 [#--
    This template generates the XXXLexer.java class.
    The details of generating the code for the NFA state machine
    are in the imported template NfaCode.java.ftl
 --]
 
package ${grammar.parserPackage};

import ${grammar.parserPackage}.Token.TokenType;
import static ${grammar.parserPackage}.Token.TokenType.*;
[#if grammar.rootAPIPackage?has_content]
   import ${grammar.rootAPIPackage}.Node;
   import ${grammar.rootAPIPackage}.TokenSource;
[/#if]


[#import "NfaCode.java.ftl" as NFA]

[#var lexerData=grammar.lexerData]


[#var PRESERVE_LINE_ENDINGS=grammar.preserveLineEndings?string("true", "false")
      JAVA_UNICODE_ESCAPE= grammar.javaUnicodeEscape?string("true", "false")
      ENSURE_FINAL_EOL = grammar.ensureFinalEOL?string("true", "false")
      PRESERVE_TABS = grammar.preserveTabs?string("true", "false")
]      
[#var BaseToken = grammar.treeBuildingEnabled?string("Node.TerminalNode", "Token")]

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

[#if grammar.rootAPIPackage?has_content]
import ${grammar.rootAPIPackage}.TokenSource;
[/#if]

public class ${grammar.lexerClassName} extends TokenSource
{

 public enum LexicalState {
  [#list grammar.lexerData.lexicalStates as lexicalState]
     ${lexicalState.name}
     [#if lexicalState_has_next],[/#if]
  [/#list]
 }  
 [#if grammar.lexerUsesParser]
  public ${grammar.parserClassName} parser;
 [/#if]
  // The following two BitSets are used to store 
  // the current active NFA states in the core tokenization loop
  private BitSet nextStates=new BitSet(${lexerData.maxNfaStates}), currentStates = new BitSet(${lexerData.maxNfaStates});

  EnumSet<TokenType> activeTokenTypes = EnumSet.allOf(TokenType.class);
  [#if grammar.deactivatedTokens?size>0 || grammar.extraTokens?size >0]
     {
       [#list grammar.deactivatedTokens as token]
          activeTokenTypes.remove(${token});
       [/#list]
       [#list grammar.extraTokenNames as token]
          regularTokens.add(${token});
       [/#list]
     }
  [/#if]

  // A lookup for lexical state transitions triggered by a certain token type
  private static EnumMap<TokenType, LexicalState> tokenTypeToLexicalStateMap = new EnumMap<>(TokenType.class);
  // Token types that are "regular" tokens that participate in parsing,
  // i.e. declared as TOKEN
  [@EnumSet "regularTokens" lexerData.regularTokens.tokenNames /]
  // Token types that do not participate in parsing
  // i.e. declared as UNPARSED (or SPECIAL_TOKEN)
  [@EnumSet "unparsedTokens" lexerData.unparsedTokens.tokenNames /]
  // Tokens that are skipped, i.e. SKIP 
  [@EnumSet "skippedTokens" lexerData.skippedTokens.tokenNames /]
  // Tokens that correspond to a MORE, i.e. that are pending 
  // additional input
  [@EnumSet "moreTokens" lexerData.moreTokens.tokenNames /]

   
  public ${grammar.lexerClassName}(CharSequence input) {
    this("input", input);
  }


     /**
      * @param inputSource just the naem of the input source (typically the filename)
      * that will be used in error messages and so on.
      * @param input the input
      */
     public ${grammar.lexerClassName}(String inputSource, CharSequence input) {
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
     public ${grammar.lexerClassName}(String inputSource, CharSequence input, LexicalState lexState, int startingLine, int startingColumn) {
        super(inputSource, input, startingLine, startingColumn,
                        ${grammar.tabSize}, ${PRESERVE_TABS}, 
                        ${PRESERVE_LINE_ENDINGS}, 
                        ${JAVA_UNICODE_ESCAPE}, 
                        ${ENSURE_FINAL_EOL});
        if (lexicalState != null) switchTo(lexState);
     [#if grammar.cppContinuationLine]
        handleCContinuationLines();
     [/#if]
     }

    private Token getNextToken() {
      InvalidToken invalidToken = null;
      Token token = nextToken();
      while (token instanceof InvalidToken) {
          if (invalidToken == null) {
              invalidToken = (InvalidToken) token;
          } else {
              invalidToken.setEndOffset(token.getEndOffset());
          }
          token = nextToken();
      }
      if (invalidToken != null) cacheToken(invalidToken);
      cacheToken(token);
      if (invalidToken != null) {
        goTo(invalidToken.getEndOffset());
        return invalidToken;
      }
      return token;
    }

  /**
   * The public method for getting the next token.
   * If the tok parameter is null, it just tokenizes 
   * starting at the internal bufferPosition
   * Otherwise, it checks whether we have already cached
   * the token after this one. If not, it finally goes 
   * to the NFA machinery
   */ 
    public Token getNextToken(Token tok) {
       if(tok == null) {
           return getNextToken();
       }
       Token cachedToken = tok.nextCachedToken();
    // If the cached next token is not currently active, we
    // throw it away and go back to the XXXLexer
       if (cachedToken != null && !activeTokenTypes.contains(cachedToken.getType())) {
           reset(tok);
           cachedToken = null;
       }
       return cachedToken != null ? cachedToken : getNextToken(tok.getEndOffset());
    }

    /**
     * A lower level method to tokenize, that takes the absolute
     * offset into the content buffer as a parameter
     * @param offset where to start
     * @return the token that results from scanning from the given starting point 
     */
    public Token getNextToken(int offset) {
        goTo(offset);
        return getNextToken();
    }

// The main method to invoke the NFA machinery
 private final Token nextToken() {
      Token matchedToken = null;
      boolean inMore = false;
      int tokenBeginOffset = getBufferPosition(), firstChar =0;
      // The core tokenization loop
      while (matchedToken == null) {
        int curChar, codePointsRead=0, matchedPos=0;
        TokenType matchedType = null;
        boolean reachedEnd = false;
        if (inMore) {
            curChar = readChar();
            if (curChar == -1) reachedEnd = true;
        }
        else {
            tokenBeginOffset = getBufferPosition();
            firstChar = curChar = readChar();
            if (curChar == -1) {
              matchedType = EOF;
              reachedEnd = true;
            }
        } 
      [#if NFA.multipleLexicalStates]
       // Get the NFA function table current lexical state
       // There is some possibility that there was a lexical state change
       // since the last iteration of this loop!
        NfaFunction[] nfaFunctions = functionTableMap.get(lexicalState);
      [/#if]
        // the core NFA loop
        if (!reachedEnd) do {
            // Holder for the new type (if any) matched on this iteration
            TokenType newType = null;
            if (codePointsRead > 0) {
                // What was nextStates on the last iteration 
                // is now the currentStates!
                BitSet temp = currentStates;
                currentStates = nextStates;
                nextStates = temp;
                int retval = readChar();
                if (retval >=0) {
                    curChar = retval;
                }
                else {
                    reachedEnd = true;
                    break;
                }
            }
            nextStates.clear();
            int nextActive = codePointsRead == 0 ? 0 : currentStates.nextSetBit(0);
            do {
                TokenType returnedType = nfaFunctions[nextActive].apply(curChar, nextStates, activeTokenTypes);
                if (returnedType != null && (newType == null || returnedType.ordinal() < newType.ordinal())) {
                    newType = returnedType;
                }
                nextActive = codePointsRead == 0 ? -1 : currentStates.nextSetBit(nextActive+1);
            } while (nextActive != -1);
            ++codePointsRead;
            if (newType != null) {
                matchedType = newType;
                inMore = moreTokens.contains(matchedType);
                matchedPos= codePointsRead;
            }
        } while (!nextStates.isEmpty());
        if (matchedType == null) {
            setBufferPosition(tokenBeginOffset);
            forward(1);
            return new InvalidToken(this, tokenBeginOffset, getBufferPosition());
        } 
        backup(codePointsRead - matchedPos);
        if (skippedTokens.contains(matchedType)) {
            skipTokens(tokenBeginOffset, getBufferPosition());
        }
        else if (regularTokens.contains(matchedType) || unparsedTokens.contains(matchedType)) {
            matchedToken = Token.newToken(matchedType, 
                                        this, 
                                        tokenBeginOffset,
                                        getBufferPosition());
            matchedToken.setUnparsed(!regularTokens.contains(matchedType));
        }
     [#if lexerData.hasLexicalStateTransitions]
        doLexicalStateSwitch(matchedType);
     [/#if]
     [#if lexerData.hasTokenActions]
        matchedToken = tokenLexicalActions(matchedToken, matchedType);
     [/#if]
      }
 [#list grammar.lexerTokenHooks as tokenHookMethodName]
    [#if tokenHookMethodName = "CommonTokenAction"]
           ${tokenHookMethodName}(matchedToken);
    [#else]
            matchedToken = ${tokenHookMethodName}(matchedToken);
    [/#if]
 [/#list]
      return matchedToken;
   }

   LexicalState lexicalState = LexicalState.values()[0];

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
    // to just after the Token passed in.
    void reset(Token t, LexicalState state) {
[#list grammar.resetTokenHooks as resetTokenHookMethodName]
      ${resetTokenHookMethodName}(t);
[/#list]
      goTo(t.getEndOffset());
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

  void reset(Token t) {
      reset(t, null);
  }
    
 [#if lexerData.hasTokenActions]
  private Token tokenLexicalActions(Token matchedToken, TokenType matchedType) {
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

    void cacheToken(Token tok) {
[#if grammar.tokenChaining]        
        if (tok.isInserted()) {
            Token next = tok.nextCachedToken();
            if (next != null) cacheToken(next);
            return;
        }
[/#if]        
        cacheTokenAt(tok, tok.getBeginOffset());
    }

[#if grammar.tokenChaining]
    @Override
    protected void uncacheTokens(${BaseToken} lastToken) {
        super.uncacheTokens(lastToken);
        ((Token)lastToken).unsetAppendedToken();
    }
[/#if]    

 

  // Utility methods. Having them here makes it easier to handle things
  // more uniformly in other generation languages.

   private void setRegionIgnore(int start, int end) {
     setIgnoredRange(start, end);
   }

   private boolean atLineStart(Token tok) {
      int offset = tok.getBeginOffset();
      while (offset > 0) {
        --offset;
        char c = charAt(offset);
        if (!Character.isWhitespace(c)) return false;
        if (c=='\n') break;
      }
      return true;
   }

   private String getLine(Token tok) {
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
