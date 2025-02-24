/* Generated by: ${generated_by}. ${filename} ${settings.copyrightBlurb} */

#var tokenCount = lexerData.tokenCount

package ${settings.parserPackage};

import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.charset.Charset;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.BitSet;
import java.util.Collections;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.Iterator;
import java.util.ListIterator;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.CancellationException;
import ${settings.parserPackage}.${settings.lexerClassName}.LexicalState;
import ${settings.parserPackage}.${settings.baseTokenClassName}.TokenType;
import static ${settings.parserPackage}.${settings.baseTokenClassName}.TokenType.*;
#if settings.rootAPIPackage
   import ${settings.rootAPIPackage}.ParseException;
   import ${settings.rootAPIPackage}.TokenSource;
   import ${settings.rootAPIPackage}.NonTerminalCall;
   import ${settings.rootAPIPackage}.Node;
#endif
#if settings.faultTolerant
  #if settings.rootAPIPackage
     import ${settings.rootAPIPackage}.InvalidNode;
     import ${settings.rootAPIPackage}.ParsingProblem;
  #else
     import ${settings.nodePackage}.InvalidNode;
  #endif
#endif

#if settings.treeBuildingEnabled
  #list grammar.nodeNames as node
    #if node?index_of('.') > 0
      import ${node};
    #else
      import ${settings.nodePackage}.${grammar.nodePrefix}${node};
    #endif
  #endlist
#endif

public
[#if isFinal]final[/#if]
class ${settings.parserClassName} {   

#-- TODO: suppress this if no set expansions used.
static final class ChoiceCardinality {
    final int[][] choiceCardinalities;
    int[] choiceChosen;
    ChoiceCardinality() {
      this.choiceCardinalities = new int[0][0];
      this.choiceChosen = new int[0];
    }
    ChoiceCardinality(int[][] choiceCardinalities) {
      this.choiceCardinalities = choiceCardinalities;
      this.choiceChosen = new int[choiceCardinalities[0].length];
    }
    public boolean choose(int choiceNo, boolean isPredicate) {
      if (choiceNo < choiceChosen.length) {
        if (choiceChosen[choiceNo] == choiceCardinalities[choiceNo][1]) return false;
        if (!isPredicate) {
          ++choiceChosen[choiceNo];
        }
      }
      return true;
    }
    public boolean checkCardinality() {
      for (int i=0; i<choiceChosen.length; i++) {
          if(choiceChosen[i] < choiceCardinalities[i][0]) return false;
      }
      return true;
    }
    public void reset() {
      choiceChosen = new int[choiceCardinalities[0].length];
    }
}

static final int UNLIMITED = Integer.MAX_VALUE;
// The last token successfully "consumed"
${settings.baseTokenClassName} lastConsumedToken;
private TokenType nextTokenType;
// Normally null when parsing, populated when doing lookahead
private ${settings.baseTokenClassName} currentLookaheadToken;
private int remainingLookahead;
private boolean hitFailure;
private boolean passedPredicate;
private int passedPredicateThreshold = -1;
private String currentlyParsedProduction;
private String currentLookaheadProduction;
private int lookaheadRoutineNesting;
#if settings.faultTolerant
private EnumSet<TokenType> outerFollowSet;
#endif
#if settings.legacyGlitchyLookahead
   private final boolean legacyGlitchyLookahead = true;
#else
   private final boolean legacyGlitchyLookahead = false;
#endif

private final ${settings.baseTokenClassName} DUMMY_START_TOKEN = new ${settings.baseTokenClassName}();
private boolean cancelled;
public void cancel() {cancelled = true;}
public boolean isCancelled() {return cancelled;}
  /** Generated Lexer. */
  private ${settings.lexerClassName} token_source;

  public void setInputSource(String inputSource) {
      token_source.setInputSource(inputSource);
  }

  String getInputSource() {
      return token_source.getInputSource();
  }

 //=================================
 // Generated constructors
 //=================================

   public ${settings.parserClassName}(String inputSource, CharSequence content) {
       this(new ${settings.lexerClassName}(inputSource, content));
      #if settings.lexerUsesParser
      token_source.setParser(this);
      #endif
   }

  public ${settings.parserClassName}(CharSequence content) {
    this("input", content);
  }

  /**
   * @param inputSource just the name of the input source (typically the filename) that
   * will be used in error messages and so on.
   * @param path The location (typically the filename) from which to get the input to parse
   */
  public ${settings.parserClassName}(String inputSource, Path path) throws IOException {
    this(inputSource, TokenSource.stringFromBytes(Files.readAllBytes(path)));
  }

  public ${settings.parserClassName}(String inputSource, Path path, Charset charset) throws IOException {
    this(inputSource, TokenSource.stringFromBytes(Files.readAllBytes(path), charset));
  }

  /**
   * @param path The location (typically the filename) from which to get the input to parse
   */
  public ${settings.parserClassName}(Path path) throws IOException {
    this(path.toString(), path);
  }

  /** Constructor with user supplied Lexer. */
  public ${settings.parserClassName}(${settings.lexerClassName} lexer) {
    token_source = lexer;
      #if settings.lexerUsesParser
      token_source.setParser(this);
      #endif
      lastConsumedToken = DUMMY_START_TOKEN;
      lastConsumedToken.setTokenSource(lexer);
  }

    /**
     * Set the starting line/column for location reporting.
     * By default, this is 1,1.
     */
    public void setStartingPos(int startingLine, int startingColumn) {
        token_source.setStartingPos(startingLine, startingColumn);
    }

    // this method is for testing only.
    public boolean getLegacyGlitchyLookahead() {
        return legacyGlitchyLookahead;
    }

  // If the next token is cached, it returns that
  // Otherwise, it goes to the token_source, i.e. the Lexer.
  private ${settings.baseTokenClassName} nextToken(final ${settings.baseTokenClassName} tok) {
    ${settings.baseTokenClassName} result = token_source.getNextToken(tok);
    while (result.isUnparsed()) {
     #list grammar.parserTokenHooks as methodName
      result = ${methodName}(result);
     #endlist
      result = token_source.getNextToken(result);
     #if settings.faultTolerant
      if (result.isInvalid()) {
        if (isParserTolerant()) {
          result.setUnparsed(true);
        }
      }
     #endif
    }
#list grammar.parserTokenHooks as methodName
    result = ${methodName}(result);
#endlist
    nextTokenType = null;
    return result;
  }

  /**
   * @return the next ${settings.baseTokenClassName} off the stream. This is the same as #getToken(1)
   */
  public final ${settings.baseTokenClassName} getNextToken() {
    return getToken(1);
  }

/**
 * @param index how many tokens to look ahead
 * @return the specific regular (i.e. parsed) ${settings.baseTokenClassName} index ahead/behind in the stream.
 * If we are in a lookahead, it looks ahead from the currentLookaheadToken
 * Otherwise, it is the lastConsumedToken. If you pass in a negative
 * number it goes backward.
 */
  public final ${settings.baseTokenClassName} getToken(final int index) {
    ${settings.baseTokenClassName} t = currentLookaheadToken == null ? lastConsumedToken : currentLookaheadToken;
    for (int i = 0; i < index; i++) {
      t = nextToken(t);
    }
    for (int i = 0; i > index; i--) {
      t = t.getPrevious();
      if (t == null) break;
    }
    return t;
  }

  private String tokenImage(int n) {
    ${settings.baseTokenClassName} t = getToken(n);
    return t == null ? null : t.toString();
  }

  private String getTokenImage(int n) {
    ${settings.baseTokenClassName} t = getToken(n);
    return t == null ? null : t.toString();
  }

  private TokenType getTokenType(int n) {
     ${settings.baseTokenClassName} t = getToken(n);
     return t == null ? null : t.getType();
  }

  private boolean checkNextTokenImage(String img, String... additionalImages) {
      String nextImage = getToken(1).toString();
      if (nextImage.equals(img)) return true;
      for (String image : additionalImages) {
         if (nextImage.equals(image)) return true;
      }
      return false;
  }

  private boolean checkNextTokenType(TokenType type, TokenType... additionalTypes) {
    TokenType nextType = getToken(1).getType();
    if (nextType == type) return true;
    for (TokenType t : additionalTypes) {
      if (nextType == t) return true;
    }
    return false;
  }

  private TokenType nextTokenType() {
    if (nextTokenType == null) {
       nextTokenType = nextToken(lastConsumedToken).getType();
    }
    return nextTokenType;
  }

  boolean activateTokenTypes(TokenType... types) {
    if (token_source.activeTokenTypes == null) return false;
    boolean result = false;
    for (TokenType tt : types) {
      result |= token_source.activeTokenTypes.add(tt);
    }
    if (result) {
      token_source.reset(getToken(0));
      nextTokenType = null;
    }
    return result;
  }


  private void uncacheTokens() {
      token_source.reset(getToken(0));
  }

  private void resetTo(LexicalState state) {
    token_source.reset(getToken(0), state);
  }

  private void resetTo(${settings.baseTokenClassName} tok, LexicalState state) {
    token_source.reset(tok, state);
  }

  boolean deactivateTokenTypes(TokenType... types) {
    boolean result = false;
    if (token_source.activeTokenTypes == null) {
      token_source.activeTokenTypes = EnumSet.allOf(TokenType.class);
    }
    for (TokenType tt : types) {
      result |= token_source.activeTokenTypes.remove(tt);
    }
    if (result) {
        token_source.reset(getToken(0));
        nextTokenType = null;
    }
    return result;
  }

  /*
   * This method generalizes the failure of an assertion, i.e. the routine
   * works both when in lookahead and in parsing. If the current lookahead
   * token is null, then we are not in a lookahead, i.e. we are parsing, so
   * it just throws the exception. If we are in a lookahead routine, we set
   * the hitFailure flag to true, so that the lookahead routine we're in will
   * fail at the first opportunity.
   */
  private void fail(String message, ${settings.baseTokenClassName} token) [#if settings.useCheckedException] throws ParseException [/#if]
  {
    if (currentLookaheadToken == null) {
      throw new ParseException(message, token, parsingStack);
    }
    hitFailure = true;
  }

  private static final HashMap<TokenType[], EnumSet<TokenType>> enumSetCache = new HashMap<>();

  private static EnumSet<TokenType> tokenTypeSet(TokenType first, TokenType... rest) {
    TokenType[] key = new TokenType[1 + rest.length];

    key[0] = first;
    if (rest.length > 0) {
      System.arraycopy(rest, 0, key, 1, rest.length);
    }
    Arrays.sort(key);
    if (enumSetCache.containsKey(key)) {
      return enumSetCache.get(key);
    }
    EnumSet<TokenType> result = (rest.length == 0) ? EnumSet.of(first) : EnumSet.of(first, rest);
    enumSetCache.put(key, result);
    return result;
  }

  /**
   * Are we in the production of the given name, either scanning ahead or parsing?
   */
  private boolean isInProduction(String productionName, String... prods) {
    if (currentlyParsedProduction != null) {
      if (currentlyParsedProduction.equals(productionName)) return true;
      for (String name : prods) {
        if (currentlyParsedProduction.equals(name)) return true;
      }
    }
    if (currentLookaheadProduction != null ) {
      if (currentLookaheadProduction.equals(productionName)) return true;
      for (String name : prods) {
        if (currentLookaheadProduction.equals(name)) return true;
      }
    }
    Iterator<NonTerminalCall> it = stackIteratorBackward();
    while (it.hasNext()) {
      NonTerminalCall ntc = it.next();
      if (ntc.productionName.equals(productionName)) {
        return true;
      }
      for (String name : prods) {
        if (ntc.productionName.equals(name)) {
          return true;
        }
      }
    }
    return false;
  }


#import "ParserProductions.java.ftl" as ParserCode
${ParserCode.Productions()}
#import "LookaheadRoutines.java.ftl" as LookaheadCode
${LookaheadCode.Generate()}

#embed "ErrorHandling.java.ftl"

#if settings.treeBuildingEnabled
   #embed "TreeBuildingCode.java.ftl"
#else
  public boolean isTreeBuildingEnabled() {
    return false;
  }
#endif
}

