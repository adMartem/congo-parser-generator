[#var classname = filename[0..(filename?length -6)]]
 /* Generated by: ${generated_by}. Do not edit. ${settings.copyrightBlurb}
  * Generated Code for ${classname} AST Node type
  * by the ASTNode.java.ftl template
  */

package ${settings.nodePackage};

import ${settings.parserPackage}.*;

[#if settings.rootAPIPackage?has_content]
import ${settings.rootAPIPackage}.Node;
[/#if]

[#if isInterface]
public
[#if isAbstract]abstract[/#if]
[#if isSealed]sealed[/#if]
[#if isNonSealed]non-sealed[/#if]
interface ${classname} extends Node 
   [#list permitsList as item]
     [#if item_index==0]permits[/#if]
     ${item}[#if item_has_next],[/#if]
   [/#list]
{}

[#else]

import ${settings.parserPackage}.${settings.baseTokenClassName}.TokenType;
import static ${settings.parserPackage}.${settings.baseTokenClassName}.TokenType.*;

public 
[#if isAbstract]abstract[/#if]
[#if isFinal]final[/#if]
[#if isSealed]sealed[/#if]
[#if isNonSealed]non-sealed[/#if]
class ${classname} extends ${settings.baseNodeClassName} 
   [#list permitsList as item]
     [#if item_index==0]permits[/#if]
     ${item}[#if item_has_next],[/#if]
   [/#list]
{}
[/#if]
