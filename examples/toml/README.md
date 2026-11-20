# TOML grammar (ABNF → PEG → CongoCC)

PEG conversion of the official TOML ABNF.

| File | Role |
|------|------|
| `TOML.peg` | PEG-alt source (hand-converted from ABNF) |
| `TOML.ccc` | CongoCC wrapper |
| `generated/toml.ccc` | CongoCC productions from Pongo (`sandbox/peg`) |
| `testfiles/` | Sample `.toml` inputs |

## Regenerate CongoCC from PEG

Uses the PEG tooling at git tag `PEG_TIP` (`sandbox/peg`):

```bash
# from repo root, with congocc.jar available as ../../congocc.jar from sandbox/peg
ant -f sandbox/peg/build.xml bootstrap-new-peg_alt-parser
cp examples/toml/TOML.peg sandbox/peg/testfiles/toml.peg
(cd sandbox/peg && java -cp . Pongo testfiles/toml.peg)
cp sandbox/peg/grammar/generated/toml.ccc examples/toml/generated/toml.ccc
```

## Build and test

```bash
ant -f examples/toml/build.xml test-java
# or:
java -jar congocc.jar -n examples/toml/TOML.ccc
(cd examples/toml && javac $(find org -name '*.java') TomlParse.java && java -cp . TomlParse testfiles)
```
