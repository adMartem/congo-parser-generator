[#if settings.treeBuildingDefault]
    private boolean buildTree = true;
[#else]
    private boolean buildTree = false;
[/#if]    
[#if settings.tokensAreNodes]
    private boolean tokensAreNodes = true;
[#else]
    private boolean tokensAreNodes = false;
[/#if]
[#if settings.unparsedTokensAreNodes]
    private boolean unparsedTokensAreNodes = true;
[#else]
    private boolean unparsedTokensAreNodes = false;
[/#if]

    public boolean isTreeBuildingEnabled() {
        return buildTree;
    }

    public void setUnparsedTokensAreNodes(boolean unparsedTokensAreNodes) {
        this.unparsedTokensAreNodes = unparsedTokensAreNodes;
    }
    
    public void setTokensAreNodes(boolean tokensAreNodes) {
        this.tokensAreNodes = tokensAreNodes;
    }

    NodeScope currentNodeScope = new NodeScope();
    

	/** 
	 * @return the root node of the AST. It only makes sense to call
	 * this after a successful parse. 
	 */ 
    public Node rootNode() {
        return currentNodeScope.rootNode();
    }
    
    /**
     * push a node onto the top of the node stack
     * @param n the node to push
     */
    public void pushNode(Node n) {
        currentNodeScope.add(n);
    }

    /** 
     * @return the node on the top of the stack, and remove it from the
     * stack.  
     */ 
    public Node popNode() {
       return currentNodeScope.pop();
    }

    /** 
     * @return the node currently on the top of the tree-building stack. 
     */ 
    public Node peekNode() {
        return currentNodeScope.peek();
    }

    /**
     * Puts the node on the top of the stack. However, unlike pushNode()
     * it replaces the node that is currently on the top of the stack.
     * This is effectively equivalent to popNode() followed by pushNode(n)
     * @param n the node to poke
     */
    public void pokeNode(Node n) {
      	currentNodeScope.poke(n);
    }


	/** 
     * @return the number of Nodes on the tree-building stack in the current node
	 * scope. 
	 */
    public int nodeArity() {
        return currentNodeScope.size();
    }


    private void clearNodeScope() {
        currentNodeScope.clear();
    }
    
    private void openNodeScope(Node n) {
        new NodeScope();
        if (n!=null) {
            ${settings.baseTokenClassName} next = nextToken(lastConsumedToken);
            n.setTokenSource(lastConsumedToken.getTokenSource());
            n.setBeginOffset(next.getBeginOffset());
            n.open();
  [#list grammar.openNodeScopeHooks as hook]
            ${hook}(n);
  [/#list]
        }
    }

	/* A definite node is constructed from a specified number of
	 * children.  That number of nodes are popped from the stack and
	 * made the children of the definite node.  Then the definite node
	 * is pushed on to the stack.
	 */
    private boolean closeNodeScope(Node n, int num) {
        n.setEndOffset(lastConsumedToken.getEndOffset());
        currentNodeScope.close();
        ArrayList<Node> nodes = new ArrayList<Node>();
        for (int i=0;i<num;i++) {
           nodes.add(popNode());
        }
        if (!nodes.isEmpty()) {
            n.setEndOffset(nodes.get(0).getEndOffset());
        }
        Collections.reverse(nodes);
        if (!nodes.isEmpty()) {
            n.setBeginOffset(nodes.get(0).getBeginOffset());
        }
        for (Node child : nodes) {
            // FIXME deal with the UNPARSED_TOKENS_ARE_NODES case
            n.addChild(child);
        }
        n.close();
        pushNode(n);
 [#list grammar.closeNodeScopeHooks as hook]
       ${hook}(n);
[/#list]
       return true;
    }

	/**
	 * A conditional node is constructed if the condition is true.  All
	 * the nodes that have been pushed since the node was opened are
	 * made children of the conditional node, which is then pushed
	 * on to the stack.  If the condition is false the node is not
	 * constructed and they are left on the stack. 
	 */
    private boolean closeNodeScope(Node n, boolean condition) {
        if (n==null || !condition) {
            currentNodeScope.close();
            return false;
        }
        else {
            n.setEndOffset(lastConsumedToken.getEndOffset());
            int a = nodeArity();
            currentNodeScope.close();
            ArrayList<Node> nodes = new ArrayList<Node>();
            while (a-- > 0) {
                nodes.add(popNode());
            }
            Collections.reverse(nodes);
            for (Node child : nodes) {
                if (unparsedTokensAreNodes && child instanceof ${settings.baseTokenClassName}) {
                    ${settings.baseTokenClassName} tok = (${settings.baseTokenClassName}) child;
                    while (tok.previousCachedToken() != null && tok.previousCachedToken().isUnparsed()) {
                        tok = tok.previousCachedToken();
                    }
                    while (tok.isUnparsed()) {
                        n.addChild(tok);
                        tok = tok.nextCachedToken();
                    }
                }
                n.addChild(child);
            }
            n.close();
            pushNode(n);
[#list grammar.closeNodeScopeHooks as hook]
           ${hook}(n);
[/#list]
        }
        return true; 
    }
    
    
    public boolean getBuildTree() {
    	return buildTree;
    }
    
    public void setBuildTree(boolean buildTree) {
        this.buildTree = buildTree;
    }

    @SuppressWarnings("serial")
    class NodeScope extends ArrayList<Node> {
        NodeScope parentScope;
        NodeScope() {
            this.parentScope = ${settings.parserClassName}.this.currentNodeScope;
            ${settings.parserClassName}.this.currentNodeScope = this;
        }

        boolean isRootScope() {
            return parentScope == null;
        }

        Node rootNode() {
            NodeScope ns = this;
            while (ns.parentScope != null) {
                ns = ns. parentScope;
            }
            return ns.isEmpty() ? null : ns.get(0);
        }

        Node peek() {
            if (isEmpty()) {
                return parentScope == null ? null : parentScope.peek();

            }
            return get(size()-1);
        }

        Node pop() {
            return isEmpty() ? parentScope.pop() : remove(size()-1);
        }

        void poke(Node n) {
            if (isEmpty()) {
                parentScope.poke(n);
            } else {
                set(size()-1, n);
            }
        }

        void close() {
            parentScope.addAll(this);
            ${settings.parserClassName}.this.currentNodeScope = parentScope;
        }
        
        int nestingLevel() {
            int result = 0;
            NodeScope parent = this;
            while (parent.parentScope != null) {
               result++;
               parent = parent.parentScope;
            }
            return result;            
        }

        public NodeScope clone() {
            NodeScope clone = (NodeScope) super.clone();
            if (parentScope != null) {
                clone.parentScope = parentScope.clone();
            }
            return clone;
        } 
    }

