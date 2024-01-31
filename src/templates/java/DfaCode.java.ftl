#macro SetMatcherHookToDfa
    static {
        MATCHER_HOOK = ${settings.lexerClassName}::dfaMatch; // initialize the matcher hook to first use this DFA implementation.
    }
/#macro

#macro GenerateDfaCode isMultipleLexicalStates

    private static final boolean TRACE_MATCH_FAIL = false;
    private static final boolean TRACE_GENERATION_RESULT = true;
    
    private static char MAX_DFA_CHAR = 0x7f;
    private static int MIN_NO_STATES_FOR_DFA = 65;

    /***
     * Constructs a state transition table for the Mealy machine simulating a DFA.
     *
     * The fancy name for the following is Rabin–Scott powerset construction. It can be applied
     * directly to the statically constructed CongoCC NFA for each lexical state in the described
     * lexer.  This is because the states of the CongoCC NFA are already epsilon closures of the
     * the NFA described by the regular expressions, i.e., every state consumes an input character.
     * In addition, applying the CongoCC NFA to any input sequence always results in an acceptance of some
     * all of the available input, so every NFA state reaches a final state and no NFA state is unreachable
     * from the initial state. Hence, the algorithm for constructing a DFA is dead-simple, and here it is.
     *
     * The final result of all this is a table that maps each DFA state to a single next state (possibly nil)
     * and a single output token (if the current state is final for a token in the lexical state).
     */
    private static char[][][] generateDfaStateMachine(LexicalState lexicalState) {
        #if isMultipleLexicalStates
            NfaFunction[] nfaFunctions = functionTableMap.get(lexicalState);
        /#if
        int noNfaStates = nfaFunctions.length;
        // An ordered set of the DFA states for lexer
        LinkedHashMap<DfaState, DfaState> dfaStates = new LinkedHashMap<>();
        // The DFA state derived from the NFA next state set resulting from a specified 
        // input symbol for a specific NFA state        
        DfaState nextDfaState = new DfaState();
        // Stack of NFA state subsets to process into a single DFA state
        LinkedHashMap<DfaState, DfaState> toDo = new LinkedHashMap<>();
        // start with the initial state for this lexical state; push it on the TODO stack
        toDo.put(nextDfaState, nextDfaState);
        DfaState dfaState;
        // follow all possible transitions from state 0 
        int i = 0;
        while (!toDo.isEmpty()) {
            // form the transitions on all expected chars and add them to this DFA state
            dfaState = toDo.entrySet().iterator().next().getValue();
            toDo.remove(dfaState);
            for (char a = 0; a <= MAX_DFA_CHAR; a++) {
                BitSet uStates = new BitSet();
                TokenType returnType = null;
                TokenType acceptedType = null;
                //boolean isFinal = false;
                for (Integer nfaState : dfaState) {
                    // mine the NFA state for next NFA states for this input
                    BitSet nextStates = new BitSet();
                    returnType = nfaFunctions[nfaState].apply(a, nextStates, null, null);
                    //assert (returnType == null || acceptedType == null || returnType == acceptedType);
                    if (returnType != null && (acceptedType == null || returnType.ordinal() < acceptedType.ordinal())) {
                        acceptedType = returnType;
                        // REVISIT: can more than one token be accepted by the unified states (I don't think so.)
                    }
                    if (!nextStates.isEmpty()) {
                        uStates.or(nextStates);
                    }
                }
                if (uStates.isEmpty()) {
                    nextDfaState = null;
                } else {
                    nextDfaState = new DfaState(uStates);
                    if (nextDfaState.equals(dfaState)) {
                        nextDfaState = dfaState;
                    } else if (toDo.containsKey(nextDfaState)) {
                        nextDfaState = toDo.get(nextDfaState);
                    } else if (dfaStates.containsKey(nextDfaState)) {
                        nextDfaState = dfaStates.get(nextDfaState);
                    } else {
                        // it is unique, set the index and add to the TODO list
                        nextDfaState.setIndex(++i);
                        assert (i != 0xFFFF) : "too many states for DFA transition table (>65,534)";
                        toDo.put(nextDfaState, nextDfaState);
                    }
                }
                // add the transition to the next DFA state                
                dfaState.addTransition(a, nextDfaState, acceptedType);
            }
            // add this DFA state (it's done now) 
            dfaStates.put(dfaState, dfaState);
        }
        // Now all of the new DFA states have been created, along with their transitions
        // Generate the state transition table for the DFA
        char[][][] stateTransitionTable = new char[dfaStates.size()][MAX_DFA_CHAR + 1][2];
        for (Entry<DfaState, DfaState> stateEntry : dfaStates.entrySet()) {
            int iState = stateEntry.getValue().getIndex();
            DfaTransition[] transitions = stateEntry.getValue().getTransitions();
            if (transitions != null) {
                for (i = 0; i <= MAX_DFA_CHAR; i++) {
                    char aChar = (char) i;
                    if (transitions[i] != null) {
                        DfaState toState = transitions[i].getNextState();
                        if (toState != null) {
                            stateTransitionTable[iState][aChar][0] = (char) toState.getIndex();
                        } else {
                            stateTransitionTable[iState][aChar][0] = 0xFFFF;
                        }
                        TokenType resultType = transitions[i].getAcceptedType();
                        if (resultType != null) {
                            stateTransitionTable[iState][aChar][1] = (char) resultType.ordinal();
                        } else {
                            stateTransitionTable[iState][aChar][1] = 0xFFFF;
                        }
                    } else {
                        stateTransitionTable[iState][aChar][0] = 0xFFFF;
                        stateTransitionTable[iState][aChar][1] = 0xFFFF;
                    }
                }
            }
        }
        if (TRACE_GENERATION_RESULT) System.out.println("DFA generated for " + lexicalState + ": " + stateTransitionTable.length + " states (" + noNfaStates + " NFA states)");
        return stateTransitionTable;
    }
    
    public static class DfaTransition {
        
        DfaState nextState;
        TokenType acceptedType;
        
        public DfaTransition(DfaState nextState, TokenType acceptedType) {
            this.nextState = nextState;
            this.acceptedType = acceptedType;
        }
        
        public boolean isFinal() {
            return nextState == null;
        }
        
        public DfaState getNextState() {
            return nextState;
        }
        
        public TokenType getAcceptedType() {
            return acceptedType;
        }
        
        public boolean isAccepted() {
            return acceptedType != null;
        }

        @Override
        public int hashCode() {
            return Objects.hash(acceptedType, nextState);
        }

        @Override
        public boolean equals(Object obj) {
            if (this == obj)
                return true;
            if (obj == null)
                return false;
            if (getClass() != obj.getClass())
                return false;
            DfaTransition other = (DfaTransition) obj;
            return acceptedType == other.acceptedType && 
                   Objects.equals(nextState, other.nextState);
        }
        
        @Override
        public String toString() {
            return "=> " + nextState + ((acceptedType != null) ? ":" + acceptedType : "");
        }
        
    }

    public static class DfaState implements Iterable<Integer> {
        
        private DfaTransition[] dTrans = null;
        private int index = 0;
        private BitSet nfaSubset;

        public DfaState() {
            nfaSubset = new BitSet();
            nfaSubset.set(0);
        }

        public DfaState(BitSet nfaSubset) {
            this.nfaSubset = new BitSet(nfaSubset.size());
            this.nfaSubset.or(nfaSubset);
        }

        public void setIndex(int index) {
            this.index = index;
        }
        
        public int getIndex() {
            return index;
        }

        @Override
        public Iterator<Integer> iterator() {
            return new Iterator<Integer>() {
                
                private int next = -1;

                @Override
                public boolean hasNext() {
                    return nfaSubset.nextSetBit(next + 1) >= 0;
                }

                @Override
                public Integer next() {
                    return next = nfaSubset.nextSetBit(next + 1);
                }

            };
        }
        
        public void addTransition(char a, DfaState dfaState, TokenType acceptedType) {
            if (dTrans == null) {
                dTrans = new DfaTransition[MAX_DFA_CHAR + 1];
            }
            dTrans[a] = new DfaTransition(dfaState, acceptedType);
        }
        
        public DfaTransition[] getTransitions() {
            return dTrans;
        }
        
        @Override
        public String toString() {
            return index + " => " + nfaSubset + " via [" + dTrans + "]";
        }

        @Override
        public int hashCode() {
            return Objects.hash(nfaSubset);
        }

        @Override
        public boolean equals(Object obj) {
            if (this == obj)
                return true;
            if (obj == null)
                return false;
            if (getClass() != obj.getClass())
                return false;
            DfaState other = (DfaState) obj;
            return Objects.equals(nfaSubset, other.nfaSubset);
        }
    }
    
    public static void generateAllDfaStateMachines() {
        for (LexicalState state : LexicalState.values()) {
            if (!dfaMap.containsKey(state)) {
                dfaMap.put(state, generateDfaStateMachine(state));
            }
        }
    }

    /***
     * The actual DFA implementation follows. Note that the generated DFAs are "backed up" by the
     * compiled NFA implementations, as the DFA only deals with the "normal" cases
     * such as ASCII characters, no lazy matching, and no deactivated tokens.  See below for more
     * detail.
     ***/

    /***
     * This is the map of DFA transition arrays, one for each lexical state that was generated.
     */
    private static Map<LexicalState, char[][][]> dfaMap = new HashMap<>(); 

    /***
     * Matches as much of the remaining input as possible to form a {@link Token}
     * in the specified {@link LexicalState}.
     * <p>
     * This method is the functional equivalent of the {@link #getMatchInfo} method, but
     * it uses a DFA simulation rather than a (mostly) NFA one. While it is generally faster
     * than the standard NFA, its speed comes at the expense of the table size used for the transitions.
     * For that reason and in order to handle all cases with the currently generated NFA, this method only handles
     * ASCII characters (character values 0 through 127) and does not handle characters comprising inactivated tokens and
     * lazy tokens. If at any time in a match it encounters one of these exceptions it immediately returns with a {@code null}
     * result.  In those cases, the standard NFA should subsequently be used.
     * </p>
     *
     * @param lexicalState is the current lexical state
     * @param input is the sequence of input character being lexed
     * @param position is the index of the first character to be consumed
     * @param activeTokenTypes is the set of tokens that may be matched; if null, all are active
     * @param nfaFunctions is an array of the NFA state transitions
     * @param currentStates is a set of current NFA states (not used)
     * @param nextStates is a set sized to contain the next NFA states (not used)
     * @param matchInfo is a record to contain the result of the match (not used)
     * @return a reference to a result tuple specifying the matched token and its length
     */
    private static MatchInfo dfaMatch(final LexicalState lexicalState, CharSequence input, int position, EnumSet<TokenType> activeTokenTypes, final NfaFunction[] nfaFunctions, BitSet currentStates, BitSet nextStates, MatchInfo matchInfo) {
        #if isMultipleLexicalStates
            if (functionTableMap.get(lexicalState).length < MIN_NO_STATES_FOR_DFA) {
        #else
            if (nfaFunctions.length < MIN_NO_STATES_FOR_DFA) {
        /#if
            return null;
        }
        int positionSave = position;
        char [][][] transitionTable;        
        synchronized (${settings.lexerClassName}.class) { // REVISIT: use a ThreadLocal here?
            if (!dfaMap.containsKey(lexicalState)) {
                dfaMap.put(lexicalState, generateDfaStateMachine(lexicalState));
            }   
            transitionTable = dfaMap.get(lexicalState);
        }
        // TODO: make a ThreadLocal copy of the input as a char[] for speed?
        if (transitionTable == null) {
            return null;
        }
        if (matchInfo == null) {
            matchInfo = new MatchInfo();
        } 
        if (position >= input.length()) {
            matchInfo.matchedType = EOF;
            matchInfo.matchLength = 0;
            return matchInfo;
        }
        int start = position;
        return matchToken(activeTokenTypes, transitionTable, input, start, positionSave, input.length());
    }
    
    /***
     * Core Finite State Machine (FSM) simulator for tokenizing. Strictly speaking, 
     * it is a Mealy machine with outputs only in selected states accepted by
     * a Deterministic Finite Automaton (DFA) defining the tokens of a grammar described by
     * regular expressions. 
     */
    private static MatchInfo matchToken(EnumSet<TokenType> activeTokenTypes, char[][][] transitions, CharSequence input, int start, int position, int limit) {
        int matchLength = 0, currentState = 0, nextState = 0;
        int typeOrdinal = -1;
        TokenType matchedType = TokenType.INVALID;
        do {
            if (position > start) {
                currentState = nextState;
            }
            int curChar = Character.codePointAt(input, position++);
            if (curChar > 0x7F) {
                if (TRACE_MATCH_FAIL) System.out.println("falling back on non-ASCII '" + String.valueOf(curChar) + "'");
                return null; // non-ASCII character encountered, abort the DFA
            }
            char[] transition = transitions[currentState][curChar];
            nextState = transition[0];
            typeOrdinal = transition[1];
            if (typeOrdinal != 0xFFFF) {
                TokenType tokenType = TokenType.values()[typeOrdinal];
                // FIXME: /* && !tokenType.isLazy()*/ below!
                if ((activeTokenTypes == null || activeTokenTypes.contains(tokenType))) {
                    matchedType = tokenType;
                    matchLength = position - start;
                } else {                
                    if (TRACE_MATCH_FAIL) System.out.println("falling back on deactivated or lazy token '" + tokenType + "' match");
                    return null; // this is non-intuitive, but necessary, otherwise the "true" match could be skipped
                }
            }
        } while (nextState != 0xFFFF && position < limit);
        MatchInfo info = new MatchInfo();
        info.matchedType = matchedType;
        info.matchLength = matchLength;
        return info;
    }
/#macro 