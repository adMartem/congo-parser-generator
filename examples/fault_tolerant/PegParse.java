import java.io.*;
import java.util.*;

import org.parsers.peg.Node;
import org.parsers.peg.PegParser;
import org.parsers.peg.*;
import org.parsers.peg.ast.*;

/**
 * A test harness for parsing Cics source code
  */
public class PegParse {

    static public ArrayList<Node> roots= new ArrayList<>();

   static public void main(String args[]) {
      List<File> failures = new ArrayList<File>();
      List<File> successes = new ArrayList<File>();
      if (args.length == 0) {
        usage();
      }
      List<File> files = new ArrayList<File>();
      for (String arg : args) {
          File file = new File(arg);
          if (!file.exists()) {
              System.err.println("File " + file + " does not exist.");
              continue;
          }
	   addFilesRecursively(files, file);
      }
      PegParse pp = new PegParse();
      long startTime = System.nanoTime();
      long parseStart, parseTime;
      for (File file : files) {
          try {
             // A bit screwball, we'll dump the tree if there is only one arg. :-)
              parseStart = System.nanoTime();
              BaseNode root = pp.parseFile(file, files.size() == 1);
              pp.convert(root);
          }
          catch (Exception e) {
              System.err.println("Error processing file: " + file);
              e.printStackTrace();
	          failures.add(file);
              continue;
          }
          parseTime = System.nanoTime() - parseStart;
          String parseTimeString = "" + parseTime/1000000.0;
          parseTimeString = parseTimeString.substring(0, parseTimeString.indexOf('.')+2);
          System.out.println("Parsed " + file + " in " + parseTimeString + " milliseconds.");
          successes.add(file);
       }
       System.out.println();
       for (File file : failures) {
           System.out.println("Parse failed on: " + file);
       }
       if (files.size() > 1) {
           System.out.println("\nParsed " + successes.size() + " files successfully");
           System.out.println("Failed on " + failures.size() + " files.");
       }
       String duration = "" + (System.nanoTime()-startTime)/1E9;
       duration = duration.substring(0, duration.indexOf('.') + 2);
       System.out.println("\nDuration: " + duration + " seconds");
       if (!failures.isEmpty()) System.exit(-1);
    }

   public BaseNode parseFile(File file, boolean dumpTree) throws IOException {
       PegParser parser = new PegParser(file.toPath());
       BaseNode root=parser.Grammar();
       if (dumpTree) {
           root.dump("");
       }
       return root;
   }

   static public void addFilesRecursively(List<File> files, File file) {
       if (file.isDirectory()) {
           for (File f : file.listFiles()) {
	         addFilesRecursively(files, f);
	   }
       }
       else if (file.getName().endsWith(".peg")) {
           files.add(file);
       }
   }

   static public void usage() {
       System.out.println("Usage: java PegParse <sourcefiles or directories>");
       System.out.println("If you just pass it one source file, it dumps the AST");
       System.exit(-1);
   }
   
   public void convert(BaseNode n) {
       PegVisitor visitor = new PegVisitor(new IndentingPrintStream(System.out));
       visitor.visit(n);
   }
   
   public class IndentingPrintStream extends PrintStream {
       int indentation = 0;
       int indent = 2;
       boolean isNL = true;
       public IndentingPrintStream(OutputStream out) {
           super(out);
       }
       public IndentingPrintStream indent() {
           indentation += indent;
           return this;
       }
       public IndentingPrintStream outdent() {
           indentation -= indent;
           return this;
       }
       public IndentingPrintStream nl() {
           super.println();
           super.append(" ".repeat(indent*indentation));
           return this;
       }
       public IndentingPrintStream colon() {
           super.print(" : ");
           return this;
       }
       public IndentingPrintStream semi() {
           super.print("; ");
           return this;
       }
       public IndentingPrintStream append(String s) {
           super.append(s);
           return this;
       }
   }
   
   public class PegVisitor extends Node.Visitor {
       
       IndentingPrintStream ps = null;
       Map<String,String> tokenDefinitions = new LinkedHashMap<>();
       int tokenId = -1;
       
       private String resolveToken(String tokenDef) {
           String tokenName;
           if (!tokenDefinitions.containsKey(tokenDef)) {
               tokenName = "CLASS_" + ++tokenId;
               tokenDefinitions.put(tokenDef, tokenName);
           } else {
               tokenName = tokenDefinitions.get(tokenDef);
           }
           return "<" + tokenName + ">";
       }
       
       private void printTokenDefinitions(IndentingPrintStream ps) {
           ps.append("<ANY> TOKEN : <ANY_CHAR: ~[] >;").nl();
           ps.append("<PEG> ").append("TOKEN :").indent().nl();
           boolean isFirst = true;
           Iterator<Map.Entry<String,String>> i = tokenDefinitions.entrySet().iterator();
           while (i.hasNext()) {
               Map.Entry<String,String> e = i.next();
               String tokenName = e.getValue();
               String tokenDefinition = e.getKey();
               if (!isFirst) {
                   ps.append("|").nl();
               } else {
                   isFirst = false;
               }
               ps.append("<").append(tokenName).append(":").append(" ").append(tokenDefinition).append(" >").nl();
           }
           ps.outdent().append(";").nl();
       }
       
       public PegVisitor(IndentingPrintStream ps) {
           this.ps = ps;
       }
       
       void visit(Grammar n) {
           recurse(n);
           printTokenDefinitions(ps);
       }
       
       void visit(Definition n) {
           ps.nl().append(n.getProductionName()).colon().indent().nl();
           recurse(n);
           ps.outdent().nl().semi().nl();
       }
       
       void visit(Predicate n) {
           ps.append("ENSURE ");
           visit(n.firstChildOfType(Token.class));
           ps.append("( ");
           visit(n.firstChildOfType(Suffix.class));
           ps.append(") ");
       }
       
       void visit(Suffix n) {
           // if */?/+, wrap the Primary in parentheses
           if (n.size() > 1) {
               ps.append("( ");
           }
           visit(n.get(0));
           if (n.size() > 1) {
               ps.append(")");
               visit(n.get(1));
           }
       }
       
       void visit(NonTerminalReference n) {
           ps.append(n.toString()).append(' ');
       }
       
       void visit(_LITERAL n) {
           // "..." | '...' with C escaping
           // form the Java string, use it in situ
           String literal = n.toString();
           if (literal.startsWith("'")) {
               literal = literal.translateEscapes().replaceAll("'", "\"");
           }
           ps.append(literal).append(' ');
       }
       
       void visit(Clazz n) {
           // [...] with \] and \\ escaped
           StringBuilder sb = new StringBuilder();
           List<Range> ranges = n.childrenOfType(Range.class);
           sb.append('[');
           if (ranges.size() > 0) {
               for (Range r : ranges) {
                   List<Char> chars = r.childrenOfType(Char.class);
                   String char1 = chars.get(0).toString();
                   sb.append('\"').append(char1.replaceAll("[\"]", "\\\"")).append('\"');
                   if (!r.isLoneChar()) {
                       String char2 = chars.get(1).toString();
                       sb.append('-').append('\"').append(char2.replaceAll("[\"]", "\\\"")).append('\"');
                   }
                   sb.append(',');
               }
               sb.deleteCharAt(sb.length() - 1);
           }
           sb.append(']');
           ps.append(resolveToken(sb.toString())).append(" ");
       }
       
       void visit(QUESTION n) {
           ps.append("? ");
       }
       
       void visit(STAR n) {           
           ps.append("* ");
       }
       
       void visit(PLUS n) {
           ps.append("+ ");
       }
       
       void visit(ENTAILS n) {
           ps.append("=>|| ");
       }
       
       void visit(SLASH n) {
           ps.append("| ");
       }
       
       void visit(NOT n) {
           ps.append('~');
       }
       
       void visit(OPEN n) {
           ps.append("( ");
       }
       
       void visit(CLOSE n) {
           ps.append(") ");
       }
       
       void visit(_DOT n) {
           ps.append("LEXICAL_STATE ANY (<ANY_CHAR>) ");
       }
   }
}
