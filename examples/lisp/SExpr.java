import java.util.*;

abstract class SExpr {
    public abstract String print();
}

class Atom extends SExpr {
    public final String name;
    public Atom(String name) { this.name = name; }
    public String toString() { return name; }
    public String print() { return name; }
}

class Cons extends SExpr {
    public SExpr car;
    public SExpr cdr;
    public Cons(SExpr car, SExpr cdr) {
        this.car = car;
        this.cdr = cdr;
    }
    public String toString() {
        return print();
    }
    public String print() {
        StringBuilder sb = new StringBuilder("(");
        SExpr current = this;
        while (current instanceof Cons) {
            Cons cons = (Cons) current;
            sb.append(cons.car.print());
            current = cons.cdr;
            if (current instanceof Cons) {
                sb.append(" ");
            }
        }
        if (!(current == null || (current instanceof Atom && ((Atom) current).name.equalsIgnoreCase("NIL")))) {
            sb.append(" . ").append(current.print());
        }
        sb.append(")");
        return sb.toString();
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