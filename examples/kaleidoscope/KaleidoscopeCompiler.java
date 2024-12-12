import java.io.*;
import org.parsers.kaleidoscope.*;
import org.parsers.kaleidoscope.ast.*;

public class KaleidoscopeCompiler extends Node.Visitor {
    static public void interpret(File file) throws IOException, ParseException {
        KaleidoscopeParser parser = new KaleidoscopeParser(file.toPath());
        parser.Root();
        Node root = parser.rootNode();
        KaleidoscopeCompiler interpreter = new KaleidoscopeCompiler();
        interpreter.evalQuote(root);
    }

    static public void main(String[] args) throws Exception {
      if (args.length == 0) {
        usage();
      }
      else {
        for (String arg :args) {
          File f = new File(arg);
          try {
            interpret(f);
          }
          catch (Exception e) {
            System.err.println("Error interpreting file: " + f);
            e.printStackTrace();
          }
        }
      }
    }

    static public void usage() {
      System.out.println("A basic LISP Interpreter");
      System.out.println("java LISPInterpreter <filename>...");
    }
    
    void evalQuote(Node root) {
    	System.out.println("EVALQUOTE has been entered...");
    	visit(root);
    	System.out.println("EVALQUOTE is finished.");
    }
}
