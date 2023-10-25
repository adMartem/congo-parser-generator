/* 
 * Generated by: ${generated_by}. ${filename} ${settings.copyrightBlurb}
 */
package ${settings.parserPackage};

#var BaseToken = settings.baseTokenClassName
#if settings.treeBuildingEnabled || settings.rootAPIPackage?has_content
  [#set BaseToken = "Node.TerminalNode"]
/#if

import java.nio.charset.Charset;
import java.nio.Buffer;
import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.nio.charset.CharsetDecoder;
import java.nio.charset.CoderResult;
import java.nio.charset.CharacterCodingException;
import static java.nio.charset.StandardCharsets.*;
import java.util.Arrays;
import java.util.BitSet;


abstract public class TokenSource implements CharSequence
{
   private int tabSize = 1;

   public void setTabSize(int tabSize) {this.tabSize = tabSize;}

    // Typically a filename, I suppose.
    private String inputSource = "input";

   protected int getTabSize() {return tabSize;}

#if settings.usesPreprocessor
   // Just a dummy token value that we put in the tokenLocationTable
   // to indicate that this location in the file is ignored.
    private static final ${BaseToken} IGNORED = new ${settings.baseTokenClassName}();
/#if
    // A dummy token value that we use to indicate that a token location is skipped.    
    private static final ${BaseToken} SKIPPED=new ${settings.baseTokenClassName}();

// Just a very simple, bloody minded approach, just store the
// token objects in a table where the offsets are the code unit 
// positions in the content buffer. If the token at a given offset is
// the dummy or marker type IGNORED, then the location is skipped via
// whatever preprocessor logic.    
    private ${BaseToken}[] tokenLocationTable;
// A BitSet that stores where the tokens are located.
// This is not strictly necessary, I suppose...
   private BitSet tokenOffsets;

//  A Bitset that stores the line numbers that
// contain either hard tabs or extended (beyond 0xFFFF) unicode
// characters.
   private BitSet needToCalculateColumns=new BitSet();

// A list of offsets of the beginning of lines
   private int[] lineOffsets;
   // Munged content, possibly replace unicode escapes, tabs, or CRLF with LF.
   private CharSequence content;

    // The starting line and column, usually 1,1
    // that is used to report a file position 
    // in 1-based line/column terms
    private int startingLine;
    private int startingColumn;

    /**
     * Set the starting line/column for location reporting.
     * By default, this is 1,1.
     */
    public void setStartingPos(int startingLine, int startingColumn) {
      this.startingLine = startingLine;
      this.startingColumn = startingColumn;
    }

    protected TokenSource(String inputSource, 
                         CharSequence input, 
                         int startingLine, 
                         int startingColumn, 
                         int tabSize,
                         boolean preserveTabs, 
                         boolean preserveLineEndings, 
                         boolean javaUnicodeEscape,
                         String terminatingString) {
        this.inputSource = inputSource;
        this.tabSize = tabSize;
        this.startingLine = startingLine;
        this.startingColumn = startingColumn;
        this.content = mungeContent(input, preserveTabs, tabSize, preserveLineEndings, javaUnicodeEscape, terminatingString);
        createLineOffsetsTable();
        createTokenLocationTable();        
     }


// Icky method to handle annoying stuff. Might make this public later if it is
// needed elsewhere
   static protected String mungeContent(CharSequence content, boolean preserveTabs, int tabSize, boolean preserveLines,
        boolean javaUnicodeEscape, String terminatingString) {
    if (preserveTabs && preserveLines && !javaUnicodeEscape) {
        if (!terminatingString.isEmpty()) {
            if (content.length() == 0) {
                content = terminatingString;
            } else {
                int lastChar = content.charAt(content.length()-1);
                if (lastChar != '\n' && lastChar != '\r') {
                    if (content instanceof StringBuilder) {
                        ((StringBuilder) content).append((char) '\n');
                    } else {
                        StringBuilder buf = new StringBuilder(content);
                        buf.append(terminatingString);
                        content = buf.toString();
                    }
                }
            }
        }
        return content.toString();
    }
    StringBuilder buf = new StringBuilder();
    // This is just to handle tabs to spaces. If you don't have that setting set, it
    // is really unused.
    int col = 0;
    int index = 0, contentLength = content.length();
    while (index < contentLength) {
        char ch = content.charAt(index++);
        if (ch == '\n') {
            buf.append(ch);
            col = 0;
        }
        else if (javaUnicodeEscape && ch == '\\' && index < contentLength && content.charAt(index)=='u') {
            int numPrecedingSlashes = 0;
            for (int i = index-1; i>=0; i--) {
                if (content.charAt(i) == '\\') 
                    numPrecedingSlashes++;
                else break;
            }
            if (numPrecedingSlashes % 2 == 0) {
                buf.append('\\');
                ++col;
                continue;
            }
            int numConsecutiveUs = 0;
            for (int i = index; i < contentLength; i++) {
                if (content.charAt(i) == 'u') numConsecutiveUs++;
                else break;
            }
            String fourHexDigits = content.subSequence(index+numConsecutiveUs, index+numConsecutiveUs+4).toString();
            buf.append((char) Integer.parseInt(fourHexDigits, 16));
            index+=(numConsecutiveUs +4);
            ++col;
        }
        else if (!preserveLines && ch == '\r') {
            buf.append('\n');
            col = 0;
            if (index < contentLength && content.charAt(index) == '\n') {
                ++index;
            }
        } else if (ch == '\t' && !preserveTabs) {
            int spacesToAdd = tabSize - col % tabSize;
            for (int i = 0; i < spacesToAdd; i++) {
                buf.append(' ');
                col++;
            }
        } else {
            buf.append(ch);
            if (!Character.isLowSurrogate(ch)) col++;
        }
    }
    if (!terminatingString.isEmpty()) {
        if (buf.length() ==0) {
            return terminatingString;
        }
        if (buf.length() < terminatingString.length()) {
            buf.append(terminatingString);
        } else if (!buf.substring(buf.length()-terminatingString.length()).equals(terminatingString)) {
            buf.append(terminatingString);
        }
    }
    return buf.toString();
   }

   private final void createTokenLocationTable() {
      int size = content.length() +1;
      tokenLocationTable = new ${BaseToken}[size];
      tokenOffsets = new BitSet(size);
   }

    protected final void skipTokens(int begin, int end) {
      for (int i=begin; i< end; i++) {
#if settings.usesPreprocessor        
          if (tokenLocationTable[i] != IGNORED) tokenLocationTable[i] = SKIPPED;
#else          
          tokenLocationTable[i] = SKIPPED;
/#if 
      }
    }

    public final char charAt(int pos) {
        return content.charAt(pos);
    }

    public final int length() {
        return content.length();
    }

    public final CharSequence subSequence(int start, int end) {
        return content.subSequence(start, end);
    }

    public String toString() {
        return content.toString();
    }

#if settings.usesPreprocessor
    public final int nextUnignoredOffset(int offset) {
        while (offset<tokenLocationTable.length-1 && tokenLocationTable[offset] == IGNORED) {
            ++offset;
        } 
        return offset;         
    }

    protected final void setIgnoredRange(int begin, int end) {
        for (int offset = begin; offset < end; offset++) {
           tokenLocationTable[offset] = IGNORED;
           tokenOffsets.clear(begin, end);
        }
    }

    public final boolean isIgnored(int offset) {
        return tokenLocationTable[offset] == IGNORED;
    }

    public final boolean spansPPInstruction(int start, int end) {
        for (int i = start; i <end; i++) {
            if (isIgnored(i)) return true;
        }
        return false;
    }

    public final int length(int start, int end) {
        int result = 0;
        for (int i =start; i<end; i++) {
            if (!isIgnored(i)) ++result;
        }
        return result;
    }

    protected void setLineSkipped(${BaseToken} tok) {
       int lineNum = tok.getBeginLine();
       int start = getLineStartOffset(lineNum);
       int end = getLineStartOffset(lineNum+1);
       setIgnoredRange(start, end);
       tok.setBeginOffset(start);
       tok.setEndOffset(end);
    }

/#if

#if settings.cppContinuationLine
    protected void handleCContinuationLines() {
      String input = content.toString();
      for (int offset = input.indexOf('\\'); offset >=0; offset = input.indexOf('\\', offset+1)) {
          int nlIndex = input.indexOf('\n', offset);
          if (nlIndex < 0) break;
          if (input.substring(offset+1, nlIndex).trim().isEmpty()) {
              setIgnoredRange(offset, nlIndex+1);
          } 
      }
    }
/#if

    public void cacheToken(${BaseToken} tok) {
        int beginOffset=tok.getBeginOffset(), endOffset =tok.getEndOffset();
        tokenOffsets.set(beginOffset);
        if (endOffset>beginOffset+1) {
           // This handles some weird usage cases where token locations
           // have been adjusted.
           tokenOffsets.clear(beginOffset+1, endOffset);
           for (int i = beginOffset+1; i<endOffset; i++) {
              [#if settings.usesPreprocessor]
              if (tokenLocationTable[i] != IGNORED)
              [/#if]
                 tokenLocationTable[i] = null;
           }
        }
        tokenLocationTable[beginOffset] = tok;
    }

    public void uncacheTokens(${BaseToken} lastToken) {
        int endOffset = lastToken.getEndOffset();
        if (endOffset < tokenOffsets.length()) {
            tokenOffsets.clear(lastToken.getEndOffset(), tokenOffsets.length());
        }
    }

    public ${BaseToken} nextCachedToken(int offset) {
        int nextOffset = tokenOffsets.nextSetBit(offset);
        return nextOffset != -1 ? tokenLocationTable[nextOffset] : null;
    } 

    public ${BaseToken} previousCachedToken(int offset) {
        int prevOffset = tokenOffsets.previousSetBit(offset-1);
        return prevOffset == -1 ? null : tokenLocationTable[prevOffset];
    }

#if settings.usesPreprocessor
    /**
     * This is used in conjunction with having a preprocessor.
     * We set which lines are actually parsed lines and the 
     * unset ones are ignored. 
     * @param parsedLines a #java.util.BitSet that holds which lines
     * are parsed (i.e. not ignored)
     */
    private void setParsedLines(BitSet parsedLines, boolean reversed) {
        for (int i=0; i < lineOffsets.length; i++) {
            boolean turnOffLine = !parsedLines.get(i+1);
            if (reversed) turnOffLine = !turnOffLine;
            if (turnOffLine) {
                int lineOffset = lineOffsets[i];
                int nextLineOffset = i < lineOffsets.length -1 ? lineOffsets[i+1] : content.length();
                setIgnoredRange(lineOffset, nextLineOffset);
            }
        }
    }

    /**
     * This is used in conjunction with having a preprocessor.
     * We set which lines are actually parsed lines and the 
     * unset ones are ignored. 
     * @param parsedLines a #java.util.BitSet that holds which lines
     * are parsed (i.e. not ignored)
     */
    public void setParsedLines(BitSet parsedLines) {setParsedLines(parsedLines, false);}

    public void setUnparsedLines(BitSet unparsedLines) {setParsedLines(unparsedLines, true);}
/#if

    // Just use the canned binary search to check whether the char
    // is in one of the intervals
    static protected boolean checkIntervals(int[] ranges, int ch) {
      int result = Arrays.binarySearch(ranges, ch);
      return result >=0 || result%2 == 0;
    }



    /**
     * The offset of the start of the given line. This is in code units
     */
    public int getLineStartOffset(int lineNumber) {
        int realLineNumber = lineNumber - startingLine;
        if (realLineNumber <=0) {
            return 0;
        }
        if (realLineNumber >= lineOffsets.length) {
            return content.length();
        }
        return lineOffsets[realLineNumber];
    }

    /**
     * The offset of the end of the given line. This is in code units.
     */
    public int getLineEndOffset(int lineNumber) {
        int realLineNumber = lineNumber - startingLine;
        if (realLineNumber <0) {
            return 0;
        }
        if (realLineNumber >= lineOffsets.length) {
            return content.length();
        }
        if (realLineNumber == lineOffsets.length -1) {
            return content.length() -1;
        }
        return lineOffsets[realLineNumber+1] -1;
    }

    public int getLineFromOffset(int pos) {
        if (pos >= content.length()) {
            if (content.charAt(content.length()-1) == '\n') {
                return startingLine + lineOffsets.length;
            }
            return startingLine + lineOffsets.length-1;
        }
        int bsearchResult = Arrays.binarySearch(lineOffsets, pos);
        if (bsearchResult>=0) {
        [#-- REVISIT --]
            return Math.max(startingLine, startingLine + bsearchResult);
        }
        [#-- REVISIT --]
        return Math.max(startingLine, startingLine -(bsearchResult + 2));
    }

    private void createLineOffsetsTable() {
        if (content.length() == 0) {
            this.lineOffsets = new int[0];
            return;
        }
        int lineCount = 0;
        int length = content.length();
        for (int i = 0; i < length; i++) {
            char ch = content.charAt(i);
            if (ch == '\t' || Character.isHighSurrogate(ch)) {
                needToCalculateColumns.set(lineCount);
            }
            if (ch == '\n') {
                lineCount++;
            }
        }
        if (content.charAt(length - 1) != '\n') {
            lineCount++;
        }
        int[] lineOffsets = new int[lineCount];
        lineOffsets[0] = 0;
        int index = 1;
        for (int i = 0; i < length; i++) {
            char ch = content.charAt(i);
            if (ch == '\n') {
                if (i + 1 == length)
                    break;
                lineOffsets[index++] = i + 1;
            }
        }
        this.lineOffsets = lineOffsets;
    }


    /**
     * @return the column (1-based and in code points)
     * from the absolute offset passed in as a parameter
     */
    public int getCodePointColumnFromOffset(int pos) {
        if (pos >= content.length()) return 1;
        if (pos == 0) return startingColumn;
        final int line = getLineFromOffset(pos)-startingLine;
        final int lineStart = lineOffsets[line];
        int startColumnAdjustment = line > 0 ? 1 : startingColumn;
        int unadjustedColumn = pos - lineStart + startColumnAdjustment;
        if (!needToCalculateColumns.get(line)) {
            return unadjustedColumn;
        }
        if (Character.isLowSurrogate(content.charAt(pos))) --pos;
        int result = startColumnAdjustment;
        for (int i = lineStart; i < pos; i++) {
            char ch = content.charAt(i);
            if (ch == '\t') {
                result += tabSize - (result - 1) % tabSize;
            } 
            else if (Character.isHighSurrogate(ch)) {
                ++result;
                ++i;
            } 
            else {
                ++result;
            }
        }
        return result;
    }

    /**
     * @return the line length in code _units_
     */ 
    int getLineLength(int lineNumber) {
        int startOffset = getLineStartOffset(lineNumber);
        int endOffset = getLineEndOffset(lineNumber);
        return 1+endOffset - startOffset;
    }

    /**
     * @return the text between startOffset (inclusive)
     * and endOffset(exclusive)
     */
    public String getText(int startOffset, int endOffset) {
#if !settings.usesPreprocessor
        return subSequence(startOffset, endOffset).toString();
#else
        StringBuilder buf = new StringBuilder();
        for (int offset = startOffset; offset < endOffset; offset++) {
            if (!isIgnored(offset)) {
                buf.append(content.charAt(offset));
            }
        }
        return buf.toString();
/#if
    }

  // The source of the raw characters that we are scanning  

    public String getInputSource() {
        return inputSource;
    }
  
    public void setInputSource(String inputSource) {
        this.inputSource = inputSource;
    }

   /**
    * @param bytes the raw byte array 
    * @param charset The encoding to use to decode the bytes. If this is null, we check for the
    * initial byte order mark (used by Microsoft a lot seemingly)
    * See: https://docs.microsoft.com/es-es/globalization/encoding/byte-order-markc
    * @return A String taking into account the encoding passed in or in the byte order mark (if it was present). 
    * And if no encoding was passed in and no byte-order mark was present, we assume the raw input
    * is in UTF-8.
    */
  public static String stringFromBytes(byte[] bytes, Charset charset) throws CharacterCodingException {
    int arrayLength = bytes.length;
    if (charset == null) {
      int firstByte = arrayLength>0 ? Byte.toUnsignedInt(bytes[0]) : 1;
      int secondByte = arrayLength>1 ? Byte.toUnsignedInt(bytes[1]) : 1;
      int thirdByte = arrayLength >2 ? Byte.toUnsignedInt(bytes[2]) : 1;
      int fourthByte = arrayLength > 3 ? Byte.toUnsignedInt(bytes[3]) : 1;
      if (firstByte == 0xEF && secondByte == 0xBB && thirdByte == 0xBF) {
         return new String(bytes, 3, bytes.length-3, UTF_8);
      }
      if (firstByte == 0 && secondByte==0 && thirdByte == 0xFE && fourthByte == 0xFF) {
         return new String(bytes, 4, bytes.length-4, Charset.forName("UTF-32BE"));
      }
      if (firstByte == 0xFF && secondByte == 0xFE && thirdByte == 0 && fourthByte == 0) {
         return new String(bytes, 4, bytes.length-4, Charset.forName("UTF-32LE"));
      }
      if (firstByte == 0xFE && secondByte == 0xFF) {
         return new String(bytes, 2, bytes.length-2, UTF_16BE);
      }
      if (firstByte == 0xFF && secondByte == 0xFE) {
         return new String(bytes, 2, bytes.length-2, UTF_16LE);
      }
      charset = UTF_8;
    }
    CharsetDecoder decoder = charset.newDecoder();
    ByteBuffer b = ByteBuffer.wrap(bytes);
    CharBuffer c = CharBuffer.allocate(bytes.length);
    while (true) {
        CoderResult r = decoder.decode(b, c, false);
        if (!r.isError()) {
            break;
        }
        if (!r.isMalformed()) {
            r.throwException();
        }
        int n = r.length();
        b.position(b.position() + n);
        for (int i = 0; i < n; i++) {
            c.put((char) 0xFFFD);
        }
    }
    ((Buffer) c).limit(c.position());
    ((Buffer) c).rewind();
    return c.toString();
    // return new String(bytes, charset);
  }

  public static String stringFromBytes(byte[] bytes) throws CharacterCodingException {
     return stringFromBytes(bytes, null);
  }
}