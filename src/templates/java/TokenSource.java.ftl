[#ftl strict_vars=true]
 /* Generated by: ${generated_by}. ${filename} */
[#var parserPackageWithDot = ""]
[#if grammar.parserPackage?has_content]
package ${grammar.parserPackage};
[/#if]

abstract public class TokenSource
[#if grammar.treeBuildingEnabled]<T extends Node.TerminalNode>
[#else]<T extends Token>[/#if]
{
    /**
     * @return the input source (usually a filename) 
     */
    abstract public String getInputSource();

    /**
     * @return the text between startOffset (inclusive)
     * and endOffset(exclusive)
     */
    abstract public String getText(int startOffset, int endOffset);

    /**
     * @return the line number from the absolute offset passed in as a parameter
     */
    abstract public int getLineFromOffset(int pos);

    /**
     * @return the column (1-based and in code points)
     * from the absolute offset passed in as a parameter
     */
    abstract public int getCodePointColumnFromOffset(int pos);

    abstract void cacheToken(Token token);

  [#if grammar.treeBuildingEnabled]
    abstract T previousCachedToken(int offset);
    abstract T nextCachedToken(int pos);
  [#else]
    abstract Token previousCachedToken(int pos);
    abstract Token nextCachedToken(int pos);
  [/#if]
}