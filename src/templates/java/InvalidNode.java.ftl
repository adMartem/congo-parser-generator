 /* Generated by: ${generated_by}. ${filename} ${settings.copyrightBlurb} */
package ${settings.nodePackage};

/**
 * A node subtype that explicitly represents a "dirty" region of
 * an input file, that we could not parse.
 */
public class InvalidNode extends ${settings.baseNodeClassName} implements ${settings.parserPackage}.ParsingProblem {

    private ParseException cause;
    private String errorMessage;

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

    void setCause(ParseException cause) {
        this.cause = cause;
    }

    public boolean isDirty() {
        return true;
    }
}