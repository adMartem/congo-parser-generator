import org.parsers.toml.*;
import org.parsers.toml.ast.*;
import java.nio.file.*;
import java.util.*;
import java.util.stream.*;

public class TomlParse {
    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            System.err.println("Usage: java TomlParse <file.or.dir>...");
            System.exit(2);
        }
        List<Path> files = new ArrayList<>();
        for (String a : args) {
            Path p = Paths.get(a);
            if (Files.isDirectory(p)) {
                try (Stream<Path> s = Files.walk(p)) {
                    s.filter(x -> x.toString().endsWith(".toml")).forEach(files::add);
                }
            } else {
                files.add(p);
            }
        }
        int failures = 0;
        for (Path f : files) {
            try {
                TomlParser parser = new TomlParser(f);
                Node root = parser.Root();
                System.out.println("OK  " + f);
            } catch (Exception e) {
                failures++;
                System.err.println("FAIL " + f + ": " + e);
                e.printStackTrace(System.err);
            }
        }
        System.out.println("Parsed " + (files.size() - failures) + "/" + files.size());
        if (failures != 0) System.exit(1);
    }
}
