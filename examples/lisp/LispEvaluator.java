import java.util.ArrayList;
import java.util.List;

public class LispEvaluator {

    public static SExpr evalquote(SExpr expr, Alist env) {
        return eval(expr, env != null ? env : globalEnv);
    }

    private static final Alist globalEnv = new Alist(null);

    public static SExpr eval(SExpr expr, Alist env) {
        if (expr instanceof Atom) {
            SExpr val = env != null ? env.lookup(((Atom) expr).name) : null;
            if (val == null) throw new RuntimeException("Unbound variable: " + ((Atom) expr).name);
            return val;
        } else if (expr instanceof Cons) {
            Cons list = (Cons) expr;
            SExpr op = list.car;
            String name = ((Atom) op).name.toUpperCase();
            switch (name) {
                case "QUOTE": return cadr(list);
                case "COND": return evalcond(list.cdr, env);
                case "LABEL": return eval(labelToLambda(list), env);
                case "DEFINE": return evalDefine(list, env);
            }
            SExpr fn = eval(op, env);
            List<SExpr> args = evlist(list.cdr, env);
            return apply(fn, args, env);
        }
        return null;
    }

    private static List<SExpr> evlist(SExpr expr, Alist env) {
        List<SExpr> result = new ArrayList<>();
        while (expr instanceof Cons) {
            Cons cons = (Cons) expr;
            result.add(eval(cons.car, env));
            expr = cons.cdr;
        }
        return result;
    }

    private static SExpr evalDefine(SExpr expr, Alist env) {
        SExpr defs = cdr(expr);

        // Case 1: grouped define
        if (car(defs) instanceof Cons) {
            SExpr current = defs;
            while (current instanceof Cons) {
                Cons defPair = (Cons) car(current);
                Atom name = (Atom) car(defPair);
                SExpr valueExpr = cadr(defPair);
                SExpr value = eval(valueExpr, env);
                globalEnv.bind(name.name, value);
                current = cdr(current);
            }
            return new Atom("T");
        }

        // Case 2: single define
        Atom name = (Atom) car(defs);
        SExpr valueExpr = car(cdr(defs));
        SExpr value = eval(valueExpr, env);
        globalEnv.bind(name.name, value);
        return name;
    }

    private static SExpr evalcond(SExpr clauses, Alist env) {
        while (clauses instanceof Cons) {
            Cons clause = (Cons) clauses;
            Cons pair = (Cons) clause.car;
            SExpr test = eval(pair.car, env);
            if (!isNil(test)) return eval(cadr(pair), env);
            clauses = clause.cdr;
        }
        return null;
    }

    private static SExpr apply(SExpr fn, List<SExpr> args, Alist env) {
        if (fn instanceof Atom) {
            return applyPrimitive(((Atom) fn).name.toUpperCase(), args);
        } else if (fn instanceof Cons) {
            SExpr op = ((Cons) fn).car;
            if (op instanceof Atom && "LAMBDA".equalsIgnoreCase(((Atom) op).name)) {
                List<String> params = collectParams(cadr(fn));
                SExpr body = caddr(fn);
                Alist newEnv = env.extend(params, args);
                return eval(body, newEnv);
            }
        }
        throw new RuntimeException("Unknown function: " + fn);
    }

    private static List<String> collectParams(SExpr paramList) {
        List<String> params = new ArrayList<>();
        while (paramList instanceof Cons) {
            Cons cons = (Cons) paramList;
            if (!(cons.car instanceof Atom)) throw new RuntimeException("Invalid param");
            params.add(((Atom) cons.car).name);
            paramList = cons.cdr;
        }
        return params;
    }

    private static SExpr applyPrimitive(String fn, List<SExpr> args) {
        switch (fn) {
            case "CAR": return ((Cons) args.get(0)).car;
            case "CDR": return ((Cons) args.get(0)).cdr;
            case "CONS": return new Cons(args.get(0), args.get(1));
            case "EQ": return eq(args.get(0), args.get(1)) ? new Atom("T") : new Atom("NIL");
            case "ATOM": return (args.get(0) instanceof Atom) ? new Atom("T") : new Atom("NIL");
            case "NULL": return isNil(args.get(0)) ? new Atom("T") : new Atom("NIL");
            case "REPLACA": ((Cons) args.get(0)).car = args.get(1); return args.get(0);
            case "REPLACD": ((Cons) args.get(0)).cdr = args.get(1); return args.get(0);
            default: throw new RuntimeException("Unknown primitive: " + fn);
        }
    }

    private static boolean eq(SExpr a, SExpr b) {
        return (a instanceof Atom && b instanceof Atom && ((Atom) a).name.equals(((Atom) b).name));
    }

    private static boolean isNil(SExpr expr) {
        return expr == null || (expr instanceof Atom && ((Atom) expr).name.equalsIgnoreCase("NIL"));
    }

    private static SExpr cadr(SExpr expr) {
        return car(cdr(expr));
    }

    private static SExpr caddr(SExpr expr) {
        return car(cdr(cdr(expr)));
    }

    private static SExpr car(SExpr expr) {
        return ((Cons) expr).car;
    }

    private static SExpr cdr(SExpr expr) {
        return ((Cons) expr).cdr;
    }

    private static SExpr labelToLambda(SExpr expr) {
        Cons top = (Cons) expr;
        Atom name = (Atom) car(cdr(top));
        SExpr lambda = car(cdr(cdr(top)));
        SExpr params = cadr(lambda);
        SExpr body = caddr(lambda);
        Alist dummy = new Alist(null);
        dummy.bind(name.name, expr); // emulate recursive binding
        return new Cons(new Atom("LAMBDA"), new Cons(params, new Cons(body, null)));
    }
} 
