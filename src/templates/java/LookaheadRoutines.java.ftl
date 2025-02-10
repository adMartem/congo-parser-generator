#-- This template generates the various lookahead/predicate routines

#macro Generate
    ${firstSetVars()}
#if settings.faultTolerant
    ${followSetVars()}
#endif
    #if grammar.choicePointExpansions
       ${BuildLookaheads()}
    #endif
#endmacro

#macro firstSetVars
    //=================================
     // EnumSets that represent the various expansions' first set (i.e. the set of tokens with which the expansion can begin)
     //=================================
    #list grammar.expansionsForFirstSet as expansion
          ${CU.firstSetVar(expansion)} 
    #endlist
#endmacro

#macro finalSetVars
    //=================================
     // EnumSets that represent the various expansions' final set (i.e. the set of tokens with which the expansion can end)
     //=================================
    #list grammar.expansionsForFinalSet as expansion
          ${finalSetVar(expansion)}
    #endlist
#endmacro


#macro followSetVars
    //=================================
     // EnumSets that represent the various expansions' follow set (i.e. the set of tokens that can immediately follow this)
     //=================================
    #list grammar.expansionsForFollowSet as expansion
          ${CU.followSetVar(expansion)}
    #endlist
#endmacro


#macro BuildLookaheads
  private boolean scanToken(TokenType expectedType, TokenType... additionalTypes) {
     ${settings.baseTokenClassName} peekedToken = nextToken(currentLookaheadToken);
     TokenType type = peekedToken.getType();
     if (type != expectedType) {
       boolean matched = false;
       for (TokenType tt : additionalTypes) {
         if (type == tt) {
            matched = true;
            break;
         }
       }
       if (!matched) return false;
     }
     --remainingLookahead;
     currentLookaheadToken = peekedToken;
     return true;
  }

  private boolean scanToken(EnumSet<TokenType> types) {
     ${settings.baseTokenClassName} peekedToken = nextToken(currentLookaheadToken);
     TokenType type = peekedToken.getType();
     if (!types.contains(type)) return false;
     --remainingLookahead;
     currentLookaheadToken = peekedToken;
     return true;
  }

//====================================
 // Lookahead Routines
 //====================================
   #list grammar.choicePointExpansions as expansion
      #if expansion.parent.class.simpleName != "BNFProduction"
        ${BuildScanRoutine(expansion)}
      #endif
   #endlist
   #list grammar.assertionExpansions as expansion
      ${BuildAssertionRoutine(expansion)}
   #endlist
   #list grammar.expansionsNeedingPredicate as expansion
       ${BuildPredicateRoutine(expansion)}
   #endlist
   #list grammar.allLookaheads as lookahead
      #if lookahead.nestedExpansion??
       ${BuildLookaheadRoutine(lookahead)}
      #endif
   #endlist
   #list grammar.allLookBehinds as lookBehind
      ${BuildLookBehindRoutine(lookBehind)}
   #endlist
   #list grammar.parserProductions as production
      ${BuildProductionLookaheadMethod(production)}
   #endlist
#endmacro

#macro BuildPredicateRoutine expansion
  #var lookaheadAmount = expansion.lookaheadAmount == 2147483647 ?: "UNLIMITED" : expansion.lookaheadAmount
  #set CU.newVarIndex = 0
  // BuildPredicateRoutine: expansion at ${expansion.location}
   private boolean ${expansion.predicateMethodName}() {
     #if expansion.checkingCardinality
       ChoiceCardinality choiceCardinalities;
     #endif
     remainingLookahead = ${lookaheadAmount};
     currentLookaheadToken = lastConsumedToken;
     final boolean scanToEnd = false;
     try {
      ${BuildPredicateCode(expansion)}
      #if !expansion.hasSeparateSyntacticLookahead && expansion.lookaheadAmount > 0
        ${BuildScanCode(expansion)}
      #endif
         return true;
      }
      finally {
         lookaheadRoutineNesting = 0;
         currentLookaheadToken = null;
         hitFailure = false;
     }
   }
#endmacro

#macro BuildScanRoutine expansion
 #-- // DBG > createNode --
 #if !expansion.singleTokenLookahead
  // scanahead routine for expansion at:
  // ${expansion.location}
  // BuildScanRoutine macro
  #set newVarIndex = 0 in CU
  private boolean ${expansion.scanRoutineName}(boolean scanToEnd) {
    #if expansion.checkingCardinality
       ChoiceCardinality choiceCardinalities = new ChoiceCardinality();
       if (cardinalityConstraints.length == 1) {
         choiceCardinalities = cardinalityConstraints;
       }
    #endif
    #if expansion.hasScanLimit
       int prevPassedPredicateThreshold = this.passedPredicateThreshold;
       this.passedPredicateThreshold = -1;
    #else
       boolean reachedScanCode = false;
       int passedPredicateThreshold = remainingLookahead - ${expansion.lookaheadAmount};
    /#if
    try {
       lookaheadRoutineNesting++;
       ${BuildPredicateCode(expansion)}
      #if !expansion.hasScanLimit
       reachedScanCode = true;
      #endif
       ${BuildScanCode(expansion)}
    }
    finally {
       lookaheadRoutineNesting--;
   #if expansion.hasScanLimit
       if (remainingLookahead <= this.passedPredicateThreshold) {
         passedPredicate = true;
         this.passedPredicateThreshold = prevPassedPredicateThreshold;
       }
   #else
       if (reachedScanCode && remainingLookahead <= passedPredicateThreshold) {
         passedPredicate = true;
       }
   #endif
    }
    passedPredicate = false;
    return true;
  }
 #endif
#endmacro

#macro BuildAssertionRoutine expansion cardinalityVar
  // scanahead routine for assertion at:
  // ${expansion.parent.location}
  // BuildAssertionRoutine macro
  #var choiceCardinalityVar = cardinalityVar!null
  #var storeCurrentLookaheadVar = CU.newVarName("currentLookahead"),
        storeRemainingLookahead = CU.newVarName("remainingLookahead")
  #set newVarIndex = 0 in CU
    private boolean ${expansion.scanRoutineName}([#if !choiceCardinalityVar?is_null]ChoiceCardinality ${choiceCardinalityVar}[/#if]) {
       #if expansion.checkingCardinality
          ChoiceCardinality choiceCardinalities;
       #endif
       final boolean scanToEnd = true;
       int ${storeRemainingLookahead} = remainingLookahead;
       remainingLookahead = UNLIMITED;
       ${settings.baseTokenClassName} ${storeCurrentLookaheadVar} = currentLookaheadToken;
       boolean prevHitFailure = hitFailure;
       if (currentLookaheadToken == null) {
          currentLookaheadToken = lastConsumedToken;
       }
       try {
          lookaheadRoutineNesting++;
          ${BuildScanCode(expansion choiceCardinalityVar!null)}
          return true;
       }
       finally {
          lookaheadRoutineNesting--;
          currentLookaheadToken = ${storeCurrentLookaheadVar};
          remainingLookahead = ${storeRemainingLookahead};
          hitFailure = prevHitFailure;
       }
    }
#endmacro

[#-- Build the code for checking semantic lookahead, lookbehind, and/or syntactic lookahead --]
#macro BuildPredicateCode expansion
    // BuildPredicateCode macro
  #if expansion.hasSemanticLookahead && (expansion.lookahead.semanticLookaheadNested || expansion.containingProduction.onlyForLookahead)
       if (!(${expansion.semanticLookahead})) return false;
  #endif
  #if expansion.hasLookBehind
       if (
         ${!expansion.lookBehind.negated ?: "!"}
         ${expansion.lookBehind.routineName}()
       ) return false;
  #endif
  #if expansion.hasSeparateSyntacticLookahead
       if (remainingLookahead <= 0) {
        passedPredicate = true;
        return !hitFailure;
       }
       if (
         ${!expansion.lookahead.negated ?: "!"}
         ${expansion.lookaheadExpansion.scanRoutineName}(true/*, cardinalityConstraints*/)
       ) return false;
  #endif
  #if expansion.lookaheadAmount == 0
       passedPredicate = true;
  #endif
    // End BuildPredicateCode macro
#endmacro


[#--
   Generates the routine for an explicit lookahead
   that is used in a nested lookahead.
 --]
#macro BuildLookaheadRoutine lookahead
     // lookahead routine for lookahead at:
     // ${lookahead.location}
  #set newVarIndex = 0 in CU
     private boolean ${lookahead.nestedExpansion.scanRoutineName}(boolean scanToEnd/*, cardinalityConstraints*/) {
        int prevRemainingLookahead = remainingLookahead;
        boolean prevHitFailure = hitFailure;
        ${settings.baseTokenClassName} prevScanAheadToken = currentLookaheadToken;
        try {
          lookaheadRoutineNesting++;
          ${BuildScanCode(lookahead.nestedExpansion)}
          return !hitFailure;
        }
        finally {
           lookaheadRoutineNesting--;
           currentLookaheadToken = prevScanAheadToken;
           remainingLookahead = prevRemainingLookahead;
           hitFailure = prevHitFailure;
        }
     }
#endmacro

#macro BuildLookBehindRoutine lookBehind
  #set newVarIndex = 0 in CU
    private boolean ${lookBehind.routineName}() {
       ListIterator<NonTerminalCall> stackIterator = ${lookBehind.backward?string("stackIteratorBackward", "stackIteratorForward")}();
       NonTerminalCall ntc = null;
       #list lookBehind.path as element
          #var elementNegated = (element[0] == "~")
          [#if elementNegated][#set element = element?substring(1)][/#if]
          #if element = "."
              if (!stackIterator.hasNext()) {
                 return false;
              }
              stackIterator.next();
          #elif element = "..."
             #if element_index = lookBehind.path?size - 1
                 #if lookBehind.hasEndingSlash
                      return !stackIterator.hasNext();
                 #else
                      return true;
                 #endif
             #else
                 #var nextElement = lookBehind.path[element_index + 1]
                 #var nextElementNegated = (nextElement[0] == "~")
                 [#if nextElementNegated][#set nextElement = nextElement?substring(1)][/#if]
                 while (stackIterator.hasNext()) {
                    ntc = stackIterator.next();
                    #var equalityOp = nextElementNegated?string("!=", "==")
                    if (ntc.productionName ${equalityOp} "${nextElement}") {
                       stackIterator.previous();
                       break;
                    }
                    if (!stackIterator.hasNext()) return false;
                 }
             #endif
          #else
             if (!stackIterator.hasNext()) return false;
             ntc = stackIterator.next();
             #var equalityOp = elementNegated?string("==", "!=")
               if (ntc.productionName ${equalityOp} "${element}") return false;
          #endif
       #endlist
       #if lookBehind.hasEndingSlash
           return !stackIterator.hasNext();
       #else
           return true;
       #endif
    }
#endmacro

#macro BuildProductionLookaheadMethod production
   // BuildProductionLookaheadMethod macro
  #set CU.newVarIndex = 0 
   private boolean ${production.lookaheadMethodName}(boolean scanToEnd) {
      #if production.javaCode?? && (production.javaCode.appliesInLookahead || production.onlyForLookahead)
         ${production.javaCode}
      #endif
      #if production.checkingCardinality
         ChoiceCardinality choiceCardinalities;
      #endif
      ${BuildScanCode(production.expansion)}
      return true;
   }
#endmacro

[#--
   Macro to build the lookahead code for an expansion.
   This macro just delegates to the various sub-macros
   based on the Expansion's class name.
--]
#macro BuildScanCode expansion cardinalitiesVar
  #var classname = expansion.simpleName
  #var skipCheck = classname == "ExpansionSequence" || 
                  #-- We can skip the check if this is a semantically meaningless
                  #-- parentheses, only there for grouping or readability
                   classname == "ExpansionWithParentheses" && !expansion::startsWithLexicalChange()
  #if !skipCheck
      if (hitFailure) return false;
      if (remainingLookahead <= 0 ) return true;
    // Lookahead Code for ${classname} specified at ${expansion.location}
  #else
    // skipping check
  #endif
  [@CU.HandleLexicalStateChange expansion true cardinalitiesVar!null ]
   // Building scan code for: ${classname}
   // at: ${expansion.location}
   #if classname = "ExpansionWithParentheses"
      ${BuildScanCode(expansion.nestedExpansion)}
   #elif expansion.singleTokenLookahead
      ${ScanSingleToken(expansion)}
   #elif expansion.terminal
      [#-- This is actually dead code since this is
      caught by the previous case. I have it here because
      sometimes I like to comment out the previous condition
      for testing purposes.--]
      ${ScanSingleToken(expansion)}
   #elif classname = "Assertion" 
      #if expansion.appliesInLookahead
         ${ScanCodeAssertion(expansion cardinalitiesVar!null)}
      #else
         // No code generated since this assertion does not apply in lookahead
      #endif
   #elif classname = "Failure"
         ${ScanCodeError(expansion)}
   #elif classname = "UncacheTokens"
         uncacheTokens();
   #elif classname = "ExpansionSequence"
      ${ScanCodeSequence(expansion cardinalitiesVar!null)}
   #elif classname = "ZeroOrOne"
      ${ScanCodeZeroOrOne(expansion)}
   #elif classname = "ZeroOrMore"
      ${ScanCodeZeroOrMore(expansion)}
   #elif classname = "OneOrMore"
      ${ScanCodeOneOrMore(expansion)}
   #elif classname = "NonTerminal"
      ${ScanCodeNonTerminal(expansion)}
   #elif classname = "TryBlock" || classname = "AttemptBlock"
      ${BuildScanCode(expansion.nestedExpansion)}
   #elif classname = "ExpansionChoice"
      ${ScanCodeChoice(expansion cardinalitiesVar!null)}
   #elif classname = "CodeBlock"
      #if expansion.appliesInLookahead || expansion.insideLookahead || expansion.containingProduction.onlyForLookahead
         ${expansion}
      #endif
   #endif
  [/@CU.HandleLexicalStateChange]
#endmacro

[#--
   Generates the lookahead code for an ExpansionSequence.
   In legacy JavaCC there was some quite complicated logic so as
   not to generate unnecessary code. They actually had a longstanding bug
   there, which was the topic of this blog post: https://congocc.com/2020/10/28/a-bugs-life/
   I very much doubt that this kind of space optimization is worth
   the candle nowadays and it just really complicated the code. Also, the ability
   to scan to the end of an expansion strike me as quite useful in general,
   particularly for fault-tolerant.
--]
#macro ScanCodeSequence sequence cardinalitiesVar
   #list sequence.units as sub
       ${BuildScanCode(sub cardinalitiesVar)}
       #if sub.scanLimit
         if (!scanToEnd && lookaheadStack.size() <= 1) {
            if (lookaheadRoutineNesting == 0) {
              remainingLookahead = ${sub.scanLimitPlus};
            }
            else if (lookaheadStack.size() == 1) {
               passedPredicateThreshold = remainingLookahead[#if sub.scanLimitPlus > 0] - ${sub.scanLimitPlus}[/#if];
            }
         }
       #endif
   #endlist
#endmacro

[#--
  Generates the lookahead code for a non-terminal.
  It (trivially) just delegates to the code for
  checking the production's nested expansion
--]
#macro ScanCodeNonTerminal nt
      // NonTerminal ${nt.name} at ${nt.location}
      pushOntoLookaheadStack("${nt.containingProduction.name}", "${nt.inputSource?j_string}", ${nt.beginLine}, ${nt.beginColumn});
      currentLookaheadProduction = "${nt.production.name}";
      try {
          if (!${nt.production.lookaheadMethodName}(${CU.bool(nt.scanToEnd)})) return false;
      }
      finally {
          popLookaheadStack();
      }
#endmacro

#macro ScanSingleToken expansion
    #var firstSet = expansion.firstSet.tokenNames
    #if firstSet?size < CU.USE_FIRST_SET_THRESHOLD
      if (!scanToken(
        #list expansion.firstSet.tokenNames as name
          ${name}
          [#if name_has_next],[/#if]
        #endlist
      )) return false;
    #else
      if (!scanToken(${expansion.firstSetVarName})) return false;
    #endif
#endmacro

#macro ScanCodeAssertion assertion cardinalitiesVar cardinalityIndex
   #if assertion.assertionExpression??
      if (!(${assertion.assertionExpression})) {
         hitFailure = true;
         return false;
      }
   #endif
   #if assertion.expansion??
      if (
         ${!assertion.expansionNegated ?: "!"}
         ${assertion.expansion.scanRoutineName}(/*cardinalityConstraints*/)
      ) {
        hitFailure = true;
        return false;
      }
   #endif
   #if assertion.cardinalityConstrained
     #if !(cardinalitiesVar!null)?is_null
      if (!${cardinalitiesVar}.choose(${cardinalityIndex})) {
         hitFailure = true;
         return false;
      }
     #else
      // choose should be here!!!
     #endif
   #endif
#endmacro

#macro ScanCodeError expansion
    if (true) {
      hitFailure = true;
      return false;
    }
#endmacro

#macro ScanCodeChoice choice [#-- choices --] cardinalitiesVar
   ${CU.newVar(settings.baseTokenClassName, "currentLookaheadToken")}
   int remainingLookahead${CU.newVarIndex} = remainingLookahead;
   boolean hitFailure${CU.newVarIndex} = hitFailure;
   boolean passedPredicate${CU.newVarIndex} = passedPredicate;
   try {
  #list choice.choices as subseq
     passedPredicate = false;
     if (!${CheckExpansion(subseq cardinalitiesVar!null subseq.index)}) {
     currentLookaheadToken = ${settings.baseTokenClassName?lower_case}${CU.newVarIndex};
     remainingLookahead = remainingLookahead${CU.newVarIndex};
     hitFailure = hitFailure${CU.newVarIndex};
     #if !subseq_has_next
        return false;
     #else
        if (passedPredicate && !legacyGlitchyLookahead) return false;
     #endif
  #endlist
  [#list choice.choices as chosen] }
     #if !(cardinalitiesVar!null)?is_null
       ${cardinalitiesVar}.choose(chosen?index); //!!!
     #endif
  [/#list]
   } finally {
      passedPredicate = passedPredicate${CU.newVarIndex};
   }
   #if !(cardinalitiesVar!null)?is_null
     if(!${cardinalitiesVar}.checkCardinality()) return false; //!!!
   #endif
#endmacro

#macro ScanCodeZeroOrOne zoo
   ${CU.newVar(settings.baseTokenClassName"currentLookaheadToken")}
   boolean passedPredicate${CU.newVarIndex} = passedPredicate;
   passedPredicate = false;
   try {
      if (!${CheckExpansion(zoo.nestedExpansion)}) {
         if (passedPredicate && !legacyGlitchyLookahead) return false;
         currentLookaheadToken = ${settings.baseTokenClassName?lower_case}${CU.newVarIndex};
         hitFailure = false;
      }
   } finally {passedPredicate = passedPredicate${CU.newVarIndex};}
#endmacro

[#--
  Generates lookahead code for a ZeroOrMore construct]
--]
#macro ScanCodeZeroOrMore zom cardinalitiesVar
   #var prevPassPredicateVarName = "passedPredicate" + CU.newID()
    #var zomCardinalitiesVar = cardinalitiesVar!null
    #if zom.cardinalityConstrained & zomCardinalitiesVar?is_null
      #set zomCardinalitiesVar = CU.newVarName("cardinality")
      // instantiating the OneOrMore choice cardinality container for its ExpansionChoices 
      ChoiceCardinality ${zomCardinalitiesVar} = new ChoiceCardinality(/*FIXME: preset cardinalities here!*/); //!!! 
    #endif
    boolean ${prevPassPredicateVarName} = passedPredicate;
    try {
      while (remainingLookahead > 0 && !hitFailure) {
      ${CU.newVar(type = settings.baseTokenClassName init = "currentLookaheadToken")}
        passedPredicate = false;
        if (!${CheckExpansion(zom.nestedExpansion zomCardinalitiesVar)}) {
            if (passedPredicate && !legacyGlitchyLookahead) return false;
            currentLookaheadToken = ${settings.baseTokenClassName?lower_case}${CU.newVarIndex};
            break;
        }
      }
    } finally {passedPredicate = ${prevPassPredicateVarName};}
    hitFailure = false;
#endmacro

[#--
   Generates lookahead code for a OneOrMore construct
   It generates the code for checking a single occurrence
   and then the same code as a ZeroOrMore
--]
#macro ScanCodeOneOrMore oom
    #var oomCardinalitiesVar = null
    #if oom.cardinalityConstrained
      #set oomCardinalitiesVar = CU.newVarName("cardinality")
      // instantiating the OneOrMore choice cardinality container for its ExpansionChoices 
      ChoiceCardinality ${oomCardinalitiesVar} = new ChoiceCardinality(/*FIXME: preset cardinalities here!*/); //!!! 
    #endif
   ${BuildScanCode(oom.nestedExpansion oomCardinalitiesVar)}
   ${ScanCodeZeroOrMore(oom oomCardinalitiesVar)}
#endmacro


#macro CheckExpansion expansion cardinalityConstraintsVar cardinalityIndex
   #var constraintsVar = cardinalityConstraintsVar!null
   #var indexVar = cardinalityIndex!null
   #if expansion.singleTokenLookahead
     #if expansion.firstSet.tokenNames?size < CU.USE_FIRST_SET_THRESHOLD
      scanToken(
        #list expansion.firstSet.tokenNames as name
          ${name}
          [#if name_has_next],[/#if]
        #endlist
      )
     #else
      scanToken(${expansion.firstSetVarName})
     #endif
   #else
     #if constraintsVar?is_null
      ${expansion.scanRoutineName}(false)
     #elseif indexVar?is_null
      ${expansion.scanRoutineName}(false,${constraintsVar})
     #else
      ${expansion.scanRoutineName}(false,${constraintsVar},${cardinalityIndex})
     #endif
   #endif
#endmacro
