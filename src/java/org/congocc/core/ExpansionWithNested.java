package org.congocc.core;

import java.util.Set;

/**
 * A convenience base class for defining expansions with an inner
 * expansion
 */
abstract public class ExpansionWithNested extends Expansion {

    public Expansion getNestedExpansion() {
        return firstChildOfType(Expansion.class);
    }
    
    @Override
    public Grammar getGrammar() {
        return getNestedExpansion().getGrammar();
    }

    @Override
    protected int getMinimumSize(Set<String> visitedNonTerminals, int minLeft) {
        return getNestedExpansion().getMinimumSize(visitedNonTerminals, minLeft);
    }

    @Override
    protected int getMaximumSize(Set<String> visitedNonTerminals) {
        return getNestedExpansion().getMaximumSize(visitedNonTerminals);
    }

    @Override
    public TokenSet getFirstSet() {
        return getNestedExpansion().getFirstSet();
    }

    @Override
    public TokenSet getFinalSet() {
        return getNestedExpansion().getFinalSet();
    }

    @Override
    public boolean potentiallyStartsWith(String productionName, java.util.Set<String> alreadyVisited) {
        return getNestedExpansion().potentiallyStartsWith(productionName, alreadyVisited);
    }

    @Override
    public boolean startsWithLexicalChange(boolean stopAtScanLimit) {
        return getNestedExpansion().startsWithLexicalChange(stopAtScanLimit);
    }

    @Override
    public boolean startsWithGlobalCodeAction(boolean stopAtScanLimit) {
        return getNestedExpansion().startsWithGlobalCodeAction(stopAtScanLimit);
    }
}