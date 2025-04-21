import java.util.*;

abstract class SExpr {}

class Atom extends SExpr {
    public final String name;
    public Atom(String name) { this.name = name; }
    public String toString() { return name; }
}

class Cons extends SExpr {
    public SExpr car;
    public SExpr cdr;
    public Cons(SExpr car, SExpr cdr) {
        this.car = car;
        this.cdr = cdr;
    }
    public String toString() {
        return "(" + stringify(this) + ")";
    }
    private static String stringify(SExpr expr) {
        if (expr == null) return "";
        if (expr instanceof Cons) {
            Cons cons = (Cons) expr;
            return cons.car + (cons.cdr != null ? " " + stringify(cons.cdr) : "");
        } else {
            return ". " + expr;
        }
    }
}

class Alist {
    private final Map<String, SExpr> bindings = new HashMap<>();
    private final Alist parent;

    public Alist(Alist parent) {
        this.parent = parent;
    }

    public void bind(String name, SExpr value) {
        bindings.put(name, value);
    }

    public SExpr lookup(String name) {
        if (bindings.containsKey(name)) return bindings.get(name);
        if (parent != null) return parent.lookup(name);
        return null;
    }

    public Alist extend(List<String> params, List<SExpr> args) {
        Alist child = new Alist(this);
        for (int i = 0; i < params.size(); i++) {
            child.bind(params.get(i), args.get(i));
        }
        return child;
    }
}


