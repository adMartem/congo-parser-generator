package org.congocc.codegen.python;

import org.congocc.parser.*;
import org.congocc.parser.python.PythonToken;
import org.congocc.parser.python.ast.*;

public class PyFormatter extends Node.Visitor {
   {this.visitUnparsedTokens = true;}
    private StringBuilder buffer = new StringBuilder();
    private int currentIndentation;
    private final int indentAmount = 4;
    private int bracketNesting, parenthesesNesting, braceNesting;
    private final String eol = "\n";
    private boolean altFormat;

    public String format(Node node, boolean altFormat) {
        this.altFormat = altFormat;
        if (altFormat) {
            buffer.append("# explicitdedent:on\n");
        }
        visit(node);
        return getText();
    }

    public String getText() {
        if (buffer.charAt(buffer.length()-1) != '\n') buffer.append('\n');
        if (altFormat) buffer.append("\n# explicitdedent:restore\n");
        return buffer.toString();
    }

    private boolean lineJoining() {
        assert bracketNesting >=0;
        assert parenthesesNesting >=0;
        assert braceNesting >=0;
        return bracketNesting>0 || parenthesesNesting>0 || braceNesting>0;
    }

    void visit(PythonToken tok) {
        switch (tok.getType()) {
            case LBRACKET -> ++bracketNesting;
            case RBRACKET -> --bracketNesting;
            case LPAREN -> ++parenthesesNesting;
            case RPAREN -> --parenthesesNesting;
            case LBRACE -> ++braceNesting;
            case RBRACE -> --braceNesting;
            default -> {}
        }
        if (!lineJoining() && tok.startsLine()) {
            indentLine();
        }
        buffer.append(tok);
        char ch = followingChar(tok);
        if (ch == ' ') buffer.append(ch);
    }

    void visit(Comment tok) {
        if (tok.toString()
           .substring(1)
           .trim()
           .toLowerCase().startsWith("explicitdedent:")) {
            return;
        }
        if (tok.startsLine()) {
            indentLine();
        }
        buffer.append(tok);
        buffer.append(eol);
    }

    void visit(IndentToken tok) {
        currentIndentation += indentAmount;
        assert currentIndentation >=0;
    }

    void visit(DedentToken tok) {
        currentIndentation -= indentAmount;
        assert currentIndentation >=0;
        if (altFormat) {
            buffer.append(eol);
            indentLine();
            buffer.append("<-");
        }
    }

    void visit(Newline tok) {
        if (lineJoining() || !tok.isUnparsed()) {
            buffer.append(eol);
        }
    }

    void visit(ClassDefinition cd) {
        buffer.append(eol);
        recurse(cd);
    }

    void visit(FunctionDefinition fd) {
        recurse(fd);
        buffer.append(eol);
    }

    private void indentLine() {
        for (int i = 0; i < currentIndentation; i++) {
            buffer.append((char) ' ');
        }
    }

    private char followingChar(PythonToken tok) {
        try {
           return tok.getTokenSource().charAt(tok.getEndOffset());
        }
        catch (Exception e) {
            return 0xFFFF;
        }
    }
}
