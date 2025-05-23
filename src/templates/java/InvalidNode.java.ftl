 /* Generated by: ${generated_by}. ${filename} ${settings.copyrightBlurb} */
package ${settings.nodePackage};

import ${settings.parserPackage}.*;

/**
 * A node subtype that explicitly represents a "dirty" region of
 * an input file, that we could not parse.
 */
public class InvalidNode extends ${settings.baseNodeClassName} implements ${settings.parserPackage}.ParsingProblem {

    private ParseException cause;
    private String errorMessage;

    public InvalidNode() {} // [JB] REVIST: for compatibility with ~FAULT_TOLERANT mode user code

    public InvalidNode(ParseException pe) {
        this.cause = pe;
    }

    public ParseException getCause() {
        return cause;
    }

    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }

    public String getErrorMessage() {
        if (errorMessage != null) return errorMessage;
        if (cause != null) return cause.getMessage();
        return "error"; // REVISIT
    }

    public boolean isDirty() {
        return true;
    }
}