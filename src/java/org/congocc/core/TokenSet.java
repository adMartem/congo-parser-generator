package org.congocc.core;

import java.util.*;

import org.congocc.Grammar;

/**
 * A class to represent a set of Token types.
 * Will probably eventually move this into the Token.java.ftl as 
 * something available to all generated parsers.
 */
public class TokenSet extends BitSet {
	
	private static final long serialVersionUID = 1L;
	
	private Grammar grammar;

	private boolean incomplete;

	public TokenSet(Grammar grammar) {
		this.grammar = grammar;
	}

	public TokenSet(Grammar grammar, boolean incomplete) {
		this.grammar=grammar;
		this.incomplete = incomplete;
	}

	public boolean isIncomplete() {
		return incomplete;
	}

	public void setIncomplete(boolean incomplete) {
		this.incomplete = incomplete;
	}
	
	public List<String> getTokenNames() {
		List<String> names = new ArrayList<>();
		int tokCount = grammar.getLexerData().getTokenCount();
		for (int i = 0; i<tokCount; i++) {
			if (get(i)) {
				names.add(grammar.getLexerData().getTokenName(i));
			}
		}
		return names;
	}

    public List<String> getTokenSetNames() {
        int tokenCount = grammar.getLexerData().getTokenCount();
        List<String> result = new ArrayList<>(tokenCount);
        for (int i=0; i<tokenCount; i++) {
            if (get(i)) {
                result.add(grammar.getLexerData().getTokenName(i));
            }
        }
        return result;
    }
}
