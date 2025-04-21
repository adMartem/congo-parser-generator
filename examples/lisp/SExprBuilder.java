import org.parsers.lisp.*;
import org.parsers.lisp.ast.*;

public class SExprBuilder extends Node.Visitor {
    
    public SExpr result;

    public void visit(Sexpression n) {
        if (n.size() == 1) {
            // Either an ATOMIC_SYMBOL or a List
            visit(n.get(0));
        } else if (n.size() == 3 && ".".equals(n.get(1).getImage())) {
            // Dotted pair: (a . b)
            visit(n.get(0));
            SExpr car = result;
            visit(n.get(2));
            SExpr cdr = result;
            result = new Cons(car, cdr);
        } else {
            throw new RuntimeException("Malformed S-expression: " + n);
        }
    }

    public void visit(_List n) {
        result = buildList(n);
    }

    public void visit(ATOMIC_SYMBOL n) {
        result = new Atom(n.getImage());
    }

    private SExpr buildList(_List listNode) {
        if (listNode.isEmpty()) return null;

        SExpr head = null;
        SExpr tail = null;

        for (int i = 0; i < listNode.size(); i++) {
            visit(listNode.get(i));
            SExpr next = result;
            if (head == null) {
                head = tail = new Cons(next, null);
            } else {
                Cons newTail = new Cons(next, null);
                ((Cons) tail).cdr = newTail;
                tail = newTail;
            }
        }
        return head;
    }

    // Utility to build and return an SExpr from any node
    public static SExpr build(Node node) {
        SExprBuilder builder = new SExprBuilder();
        builder.visit(node);
        return builder.result;
    }
}