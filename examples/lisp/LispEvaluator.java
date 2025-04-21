import java.util.ArrayList;
import java.util.List;

public class LispEvaluator {

    public static SExpr evalquote(SExpr expr, Alist env) {
        return eval(expr, env);
    }

    public static SExpr eval(SExpr expr, Alist env) {
        if (expr instanceof Atom) {
            return env != null ? env.lookup(((Atom) expr).name) : expr;
        } else if (expr instanceof Cons) {
            Cons list = (Cons) expr;
            SExpr op = list.car;
            if (op instanceof Atom) {
                String name = ((Atom) op).name.toUpperCase();
                switch (name) {
                    case "QUOTE": return cadr(list);
                    case "COND": return evalcond(list.cdr, env);
                    default:
                        SExpr fn = eval(op, env);
                        List<SExpr> args = evlist(list.cdr, env);
                        return apply(fn, args, env);
                }
            } else {
                SExpr fn = eval(op, env);
                List<SExpr> args = evlist(list.cdr, env);
                return apply(fn, args, env);
            }
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

//    private static SExpr apply(SExpr fn, List<SExpr> args, Alist env) {
//        if (fn instanceof Atom) {
//            return applyPrimitive(((Atom) fn).name.toUpperCase(), args);
//        } else if (fn instanceof Cons && ((Cons) fn).car instanceof Atom) {
//            Atom head = (Atom) ((Cons) fn).car;
//            if ("LAMBDA".equalsIgnoreCase(head.name)) {
//                List<String> params = collectParams(cadr(fn));
//                SExpr body = caddr(fn);
//                Alist newEnv = env.extend(params, args);
//                return eval(body, newEnv);
//            }
//        }
//        throw new RuntimeException("Unknown function: " + fn);
//    }
    
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
            // Add LABEL handling here soon...
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
            case "REPLACA":
                ((Cons) args.get(0)).car = args.get(1);
                return args.get(0);
            case "REPLACD":
                ((Cons) args.get(0)).cdr = args.get(1);
                return args.get(0);
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
}