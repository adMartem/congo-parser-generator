[#var classname = filename[0..(filename?length -6)]]
/* Generated by: ${generated_by}. Do not edit. ${settings.copyrightBlurb}
  * Generated Code for ${classname} ${settings.baseTokenClassName} subclass
  * by the ASTToken.java.ftl template
  */

package ${settings.nodePackage};

import ${settings.parserPackage}.*;

import static ${settings.parserPackage}.${settings.baseTokenClassName}.TokenType.*;

public 
[#if isAbstract]abstract[/#if]
[#if isFinal]final[/#if]
[#if isSealed]sealed[/#if]
[#if isNonSealed]non-sealed[/#if]
class ${classname} extends ${superclass} 
   [#list permitsList as item]
     [#if item_index==0]permits[/#if]
     ${item}[#if item_has_next],[/#if]
   [/#list]
{
    public ${classname}(TokenType type, ${settings.lexerClassName} tokenSource, int beginOffset, int endOffset) {
        super(type, tokenSource, beginOffset, endOffset);
    }
}