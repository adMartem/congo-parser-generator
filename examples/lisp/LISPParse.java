import java.io.*;
import org.parsers.lisp.*;

public class LISPParse {
    static public void parseFile(File file, boolean dumpTree) throws IOException, ParseException {
        LISPParser parser = new LISPParser(file.toPath());
        parser.Root();
        System.out.println("\n\nDumping the syntax tree for " + file.getName());
        Node root=parser.rootNode();
        if (dumpTree) {
            root.dump();
        }
        System.out.println("\n");
    }

    static public void main(String[] args) throws Exception {
      if (args.length == 0) {
        usage();
      }
      else {
        for (String arg :args) {
          File f = new File(arg);
          try {
            parseFile(f, true);
          }
          catch (Exception e) {
            System.err.println("Error parsing file: " + f);
            e.printStackTrace();
          }
        }
      }
    }

    static public void usage() {
      System.out.println("Little test harness for LISP Parser");
      System.out.println("java LISPParse <filename>");
    }
}
